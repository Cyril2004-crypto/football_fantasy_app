-- Ingestion anomaly detection + alert dispatch scheduling.
-- Run after schedule_ingestion_healthchecks.sql.
-- This script creates alert state, anomaly checks, and cron jobs for evaluate + notify.

create extension if not exists pg_cron;
create extension if not exists pg_net;

create table if not exists public.ingestion_alert_events (
  id bigserial primary key,
  source text not null,
  alert_code text not null,
  severity text not null check (severity in ('warning', 'critical')),
  message text not null,
  context jsonb not null default '{}'::jsonb,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  occurrence_count integer not null default 1,
  is_active boolean not null default true,
  resolved_at timestamptz,
  last_notified_at timestamptz
);

create index if not exists idx_ingestion_alert_events_active_source
  on public.ingestion_alert_events (source, is_active, last_seen_at desc);

create unique index if not exists uq_ingestion_alert_events_active_code
  on public.ingestion_alert_events (source, alert_code)
  where is_active = true;

create or replace function public.upsert_ingestion_alert(
  p_source text,
  p_alert_code text,
  p_severity text,
  p_message text,
  p_context jsonb default '{}'::jsonb
)
returns boolean
language plpgsql
security definer
as $$
declare
  v_id bigint;
begin
  update public.ingestion_alert_events
  set
    severity = p_severity,
    message = p_message,
    context = p_context,
    last_seen_at = now(),
    occurrence_count = occurrence_count + 1
  where source = p_source
    and alert_code = p_alert_code
    and is_active = true
  returning id into v_id;

  if found then
    return false;
  end if;

  begin
    insert into public.ingestion_alert_events (
      source,
      alert_code,
      severity,
      message,
      context,
      first_seen_at,
      last_seen_at,
      occurrence_count,
      is_active
    )
    values (
      p_source,
      p_alert_code,
      p_severity,
      p_message,
      p_context,
      now(),
      now(),
      1,
      true
    );

    return true;
  exception
    when unique_violation then
      update public.ingestion_alert_events
      set
        severity = p_severity,
        message = p_message,
        context = p_context,
        last_seen_at = now(),
        occurrence_count = occurrence_count + 1
      where source = p_source
        and alert_code = p_alert_code
        and is_active = true;

      return false;
  end;
end;
$$;

create or replace function public.resolve_ingestion_alert(
  p_source text,
  p_alert_code text
)
returns void
language plpgsql
security definer
as $$
begin
  update public.ingestion_alert_events
  set
    is_active = false,
    resolved_at = now()
  where source = p_source
    and alert_code = p_alert_code
    and is_active = true;
end;
$$;

create or replace function public.evaluate_ingestion_health_alerts(
  p_source text default 'sportmonks-enrichment'
)
returns table (
  created_alerts integer,
  active_alerts integer
)
language plpgsql
security definer
as $$
declare
  v_latest public.ingestion_health_snapshots%rowtype;
  v_prev public.ingestion_health_snapshots%rowtype;
  v_created integer := 0;
  v_failed_recent integer := 0;
  v_recent_runs integer := 0;
  v_detail text;
begin
  select *
  into v_latest
  from public.ingestion_health_snapshots
  where source = p_source
  order by snapshot_at desc
  limit 1;

  if v_latest.id is null then
    if public.upsert_ingestion_alert(
      p_source,
      'missing_snapshot',
      'critical',
      format('No ingestion health snapshots found for source "%s".', p_source),
      jsonb_build_object('source', p_source)
    ) then
      v_created := v_created + 1;
    end if;

    return query
    select v_created, count(*)::integer
    from public.ingestion_alert_events
    where source = p_source
      and is_active = true;
    return;
  end if;

  if v_latest.snapshot_at < now() - interval '30 minutes' then
    if public.upsert_ingestion_alert(
      p_source,
      'stale_snapshot',
      'critical',
      format('Latest snapshot (%s) is older than 30 minutes.', v_latest.snapshot_at),
      jsonb_build_object('latest_snapshot_at', v_latest.snapshot_at)
    ) then
      v_created := v_created + 1;
    end if;
  else
    perform public.resolve_ingestion_alert(p_source, 'stale_snapshot');
    perform public.resolve_ingestion_alert(p_source, 'missing_snapshot');
  end if;

  select *
  into v_prev
  from public.ingestion_health_snapshots
  where source = p_source
    and id <> v_latest.id
  order by snapshot_at desc
  limit 1;

  if v_prev.id is not null then
    if v_prev.player_match_stats_count > 0
      and v_latest.player_match_stats_count < (v_prev.player_match_stats_count * 0.75)
      and (v_prev.player_match_stats_count - v_latest.player_match_stats_count) >= 25 then
      v_detail := format(
        'player_match_stats_count dropped from %s to %s.',
        v_prev.player_match_stats_count,
        v_latest.player_match_stats_count
      );
      if public.upsert_ingestion_alert(
        p_source,
        'drop_player_match_stats',
        'critical',
        v_detail,
        jsonb_build_object(
          'previous', v_prev.player_match_stats_count,
          'latest', v_latest.player_match_stats_count
        )
      ) then
        v_created := v_created + 1;
      end if;
    else
      perform public.resolve_ingestion_alert(p_source, 'drop_player_match_stats');
    end if;

    if v_prev.fixture_events_count > 0
      and v_latest.fixture_events_count < (v_prev.fixture_events_count * 0.80)
      and (v_prev.fixture_events_count - v_latest.fixture_events_count) >= 20 then
      v_detail := format(
        'fixture_events_count dropped from %s to %s.',
        v_prev.fixture_events_count,
        v_latest.fixture_events_count
      );
      if public.upsert_ingestion_alert(
        p_source,
        'drop_fixture_events',
        'critical',
        v_detail,
        jsonb_build_object(
          'previous', v_prev.fixture_events_count,
          'latest', v_latest.fixture_events_count
        )
      ) then
        v_created := v_created + 1;
      end if;
    else
      perform public.resolve_ingestion_alert(p_source, 'drop_fixture_events');
    end if;

    if v_prev.player_injuries_count > 0
      and v_latest.player_injuries_count < (v_prev.player_injuries_count * 0.60)
      and (v_prev.player_injuries_count - v_latest.player_injuries_count) >= 10 then
      v_detail := format(
        'player_injuries_count dropped from %s to %s.',
        v_prev.player_injuries_count,
        v_latest.player_injuries_count
      );
      if public.upsert_ingestion_alert(
        p_source,
        'drop_player_injuries',
        'warning',
        v_detail,
        jsonb_build_object(
          'previous', v_prev.player_injuries_count,
          'latest', v_latest.player_injuries_count
        )
      ) then
        v_created := v_created + 1;
      end if;
    else
      perform public.resolve_ingestion_alert(p_source, 'drop_player_injuries');
    end if;

    if v_prev.player_suspensions_count > 0
      and v_latest.player_suspensions_count < (v_prev.player_suspensions_count * 0.60)
      and (v_prev.player_suspensions_count - v_latest.player_suspensions_count) >= 5 then
      v_detail := format(
        'player_suspensions_count dropped from %s to %s.',
        v_prev.player_suspensions_count,
        v_latest.player_suspensions_count
      );
      if public.upsert_ingestion_alert(
        p_source,
        'drop_player_suspensions',
        'warning',
        v_detail,
        jsonb_build_object(
          'previous', v_prev.player_suspensions_count,
          'latest', v_latest.player_suspensions_count
        )
      ) then
        v_created := v_created + 1;
      end if;
    else
      perform public.resolve_ingestion_alert(p_source, 'drop_player_suspensions');
    end if;
  end if;

  select
    count(*) filter (where status <> 'succeeded'),
    count(*)
  into v_failed_recent, v_recent_runs
  from (
    select rd.status
    from cron.job_run_details rd
    where rd.jobid in (
      select jobid
      from cron.job
      where jobname = 'sportmonks-ingestion-healthcheck'
    )
    order by rd.start_time desc
    limit 3
  ) recent;

  if v_recent_runs = 3 and v_failed_recent = 3 then
    if public.upsert_ingestion_alert(
      p_source,
      'healthcheck_consecutive_failures',
      'critical',
      'sportmonks-ingestion-healthcheck failed in the last 3 runs.',
      jsonb_build_object('failed_runs', v_failed_recent, 'total_recent_runs', v_recent_runs)
    ) then
      v_created := v_created + 1;
    end if;
  else
    perform public.resolve_ingestion_alert(p_source, 'healthcheck_consecutive_failures');
  end if;

  return query
  select v_created, count(*)::integer
  from public.ingestion_alert_events
  where source = p_source
    and is_active = true;
end;
$$;

-- Idempotent schedule refresh for alert jobs.
do $$
declare
  v_job_id integer;
begin
  select jobid into v_job_id from cron.job where jobname = 'evaluate-ingestion-alerts';
  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  select jobid into v_job_id from cron.job where jobname = 'notify-ingestion-alerts';
  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
end $$;

-- Evaluate after snapshot writes at :05/:25/:45.
select cron.schedule(
  'evaluate-ingestion-alerts',
  '7,27,47 * * * *',
  $$
    select public.evaluate_ingestion_health_alerts('sportmonks-enrichment');
  $$
);

-- Notify shortly after evaluation.
select cron.schedule(
  'notify-ingestion-alerts',
  '9,29,49 * * * *',
  $$
    select net.http_post(
      url := 'https://oznmbinzelhcnfiwvapu.functions.supabase.co/send-ingestion-alerts',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-ingestion-secret', 'BwRfOFXvWxcj3Lm6VnaoUKzudCSZYEeMPtIQs24khNq0l781'
      ),
      body := jsonb_build_object('source', 'sportmonks-enrichment')
    ) as request_id;
  $$
);
