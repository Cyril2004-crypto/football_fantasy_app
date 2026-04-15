-- Ingestion health snapshot + scheduled verification jobs.
-- Run after the sync schedules have already been installed and the Vault secrets set.

create extension if not exists pg_cron;

create table if not exists public.ingestion_health_snapshots (
  id bigserial primary key,
  source text not null,
  snapshot_at timestamptz not null default now(),
  teams_count bigint not null default 0,
  fixtures_count bigint not null default 0,
  players_count bigint not null default 0,
  gameweek_points_count bigint not null default 0,
  fixture_events_count bigint not null default 0,
  team_form_count bigint not null default 0,
  player_match_stats_count bigint not null default 0,
  player_injuries_count bigint not null default 0,
  player_suspensions_count bigint not null default 0,
  rows_with_xg bigint not null default 0,
  rows_with_xa bigint not null default 0,
  duplicate_gameweek_rows bigint not null default 0,
  duplicate_fixture_event_rows bigint not null default 0,
  last_gameweek_points_updated_at timestamptz,
  last_match_stats_updated_at timestamptz,
  last_fixture_events_created_at timestamptz,
  last_team_form_updated_at timestamptz,
  last_injuries_updated_at timestamptz,
  last_suspensions_updated_at timestamptz
);

create index if not exists idx_ingestion_health_snapshots_snapshot_at
  on public.ingestion_health_snapshots (snapshot_at desc);
create index if not exists idx_ingestion_health_snapshots_source
  on public.ingestion_health_snapshots (source, snapshot_at desc);

create or replace function public.record_ingestion_health_snapshot(p_source text)
returns void
language plpgsql
security definer
as $$
begin
  insert into public.ingestion_health_snapshots (
    source,
    snapshot_at,
    teams_count,
    fixtures_count,
    players_count,
    gameweek_points_count,
    fixture_events_count,
    team_form_count,
    player_match_stats_count,
    player_injuries_count,
    player_suspensions_count,
    rows_with_xg,
    rows_with_xa,
    duplicate_gameweek_rows,
    duplicate_fixture_event_rows,
    last_gameweek_points_updated_at,
    last_match_stats_updated_at,
    last_fixture_events_created_at,
    last_team_form_updated_at,
    last_injuries_updated_at,
    last_suspensions_updated_at
  )
  select
    p_source,
    now(),
    (select count(*)::bigint from public.fd_teams),
    (select count(*)::bigint from public.fd_fixtures),
    (select count(*)::bigint from public.fd_players),
    (select count(*)::bigint from public.fd_player_gameweek_points),
    (select count(*)::bigint from public.fd_fixture_events),
    (select count(*)::bigint from public.fd_team_form),
    (select count(*)::bigint from public.fd_player_match_stats),
    (select count(*)::bigint from public.fd_player_injuries),
    (select count(*)::bigint from public.fd_player_suspensions),
    (select count(*)::bigint from public.fd_player_match_stats where expected_goals > 0),
    (select count(*)::bigint from public.fd_player_match_stats where expected_assists > 0),
    coalesce((
      select count(*)::bigint
      from (
        select player_id, season, gameweek, fixture_id
        from public.fd_player_gameweek_points
        group by player_id, season, gameweek, fixture_id
        having count(*) > 1
      ) dupes
    ), 0),
    coalesce((
      select count(*)::bigint
      from (
        select provider, external_id
        from public.fd_fixture_events
        group by provider, external_id
        having count(*) > 1
      ) dupes
    ), 0),
    (select max(updated_at) from public.fd_player_gameweek_points),
    (select max(updated_at) from public.fd_player_match_stats),
    (select max(created_at) from public.fd_fixture_events),
    (select max(updated_at) from public.fd_team_form),
    (select max(updated_at) from public.fd_player_injuries),
    (select max(updated_at) from public.fd_player_suspensions)
  ;
end;
$$;

select cron.schedule(
  'daily-ingestion-healthcheck',
  '10 2 * * *',
  $$
    select public.record_ingestion_health_snapshot('daily-sync-fd-data');
  $$
);

select cron.schedule(
  'sportmonks-ingestion-healthcheck',
  '5,25,45 * * * *',
  $$
    select public.record_ingestion_health_snapshot('sportmonks-enrichment');
  $$
);
