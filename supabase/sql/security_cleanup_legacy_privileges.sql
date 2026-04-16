-- Optional cleanup for legacy public table privileges not used by this app.
-- Safe/idempotent: revokes client grants from every non-allowlisted public table.

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_type IN ('BASE TABLE', 'VIEW')
      AND table_name NOT IN (
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
  LOOP
    EXECUTE format(
      'REVOKE ALL ON TABLE public.%I FROM public, anon, authenticated',
      r.table_name
    );
  END LOOP;
END $$;

-- Report any remaining unexpected client table privileges in public schema.
select
  table_name,
  privilege_type,
  grantee
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee in ('anon', 'authenticated')
  and table_name not in (
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
order by table_name, grantee, privilege_type;
