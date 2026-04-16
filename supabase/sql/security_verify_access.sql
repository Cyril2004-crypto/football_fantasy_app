-- Verification queries for least-privilege hardening.
-- Run in Supabase SQL editor (postgres role) and inspect results.

-- 1) Show table privileges for anon/authenticated in public schema.
select
  table_schema,
  table_name,
  privilege_type,
  grantee
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee in ('anon', 'authenticated')
order by table_name, grantee, privilege_type;

-- 2) Show all public RLS policies.
select
  schemaname,
  tablename,
  policyname,
  roles,
  cmd
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

-- 3) Confirm locked tables have no client grants.
select
  table_name,
  count(*) filter (where grantee in ('anon', 'authenticated')) as client_grant_count
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in ('fantasy_teams', 'fantasy_leagues', 'fantasy_league_members', 'users')
group by table_name
order by table_name;

-- 4) Confirm required read tables are client-readable.
select
  table_name,
  string_agg(
    distinct (grantee || ':' || privilege_type),
    ', ' order by (grantee || ':' || privilege_type)
  ) as grants
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee in ('anon', 'authenticated')
  and table_name in (
    'fd_competitions',
    'fd_teams',
    'fd_players',
    'fd_fixtures',
    'fd_player_gameweek_points',
    'fd_fixture_events',
    'fd_player_match_stats',
    'fd_team_form',
    'fd_player_injuries',
    'fd_player_suspensions',
    'fd_player_form',
    'ingestion_health_snapshots',
    'ingestion_alert_events'
  )
group by table_name
order by table_name;

-- 5) Confirm cron RPC is callable and returns rows.
select * from public.get_ops_cron_job_statuses();
