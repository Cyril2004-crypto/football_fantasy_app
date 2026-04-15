-- Client-safe cron status endpoint for Ops Dashboard.
-- Run this in Supabase SQL editor as a privileged role.

create or replace function public.get_ops_cron_job_statuses()
returns table (
  jobid int,
  jobname text,
  schedule text,
  active bool,
  last_run_start timestamptz,
  last_run_end timestamptz,
  last_run_status text,
  last_run_message text
)
language sql
security definer
set search_path = public, cron
as $$
  with monitored_jobs as (
    select
      j.jobid,
      j.jobname,
      j.schedule,
      j.active
    from cron.job j
    where j.jobname in (
      'daily-sync-fd-data',
      'sportmonks-enrichment-20m',
      'daily-ingestion-healthcheck',
      'sportmonks-ingestion-healthcheck',
      'evaluate-ingestion-alerts',
      'notify-ingestion-alerts'
    )
  ),
  latest_run as (
    select distinct on (rd.jobid)
      rd.jobid,
      rd.start_time,
      rd.end_time,
      rd.status,
      rd.return_message
    from cron.job_run_details rd
    order by rd.jobid, rd.start_time desc
  )
  select
    mj.jobid,
    mj.jobname,
    mj.schedule,
    mj.active,
    lr.start_time as last_run_start,
    lr.end_time as last_run_end,
    lr.status as last_run_status,
    lr.return_message as last_run_message
  from monitored_jobs mj
  left join latest_run lr on lr.jobid = mj.jobid
  order by mj.jobname;
$$;

revoke all on function public.get_ops_cron_job_statuses() from public;
grant execute on function public.get_ops_cron_job_statuses() to authenticated;
grant execute on function public.get_ops_cron_job_statuses() to anon;
