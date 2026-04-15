-- Verify Football Data ingestion
-- Run these queries in Supabase SQL Editor to check what data has been ingested

-- 1. Check fd_player_gameweek_points table
SELECT COUNT(*) as total_gameweek_points, 
       COUNT(DISTINCT player_id) as unique_players,
       COUNT(DISTINCT fixture_id) as unique_fixtures
FROM public.fd_player_gameweek_points;

-- 2. Check fd_fixture_events table
SELECT COUNT(*) as total_fixture_events,
       COUNT(DISTINCT fixture_id) as unique_fixtures_with_events
FROM public.fd_fixture_events;

-- 3. Check fd_team_form table
SELECT COUNT(*) as total_team_form_rows,
       COUNT(DISTINCT team_id) as teams_with_form
FROM public.fd_team_form;

-- 4. Check fd_player_injuries table
SELECT COUNT(*) as total_injuries
FROM public.fd_player_injuries;

-- 5. Check fd_player_suspensions table
SELECT COUNT(*) as total_suspensions
FROM public.fd_player_suspensions;

-- 6. Check fd_player_match_stats table
SELECT COUNT(*) as total_match_stats
FROM public.fd_player_match_stats;

-- 7. Check if any teams exist
SELECT COUNT(*) as total_teams FROM public.fd_teams;

-- 8. Check if any fixtures exist
SELECT COUNT(*) as total_fixtures FROM public.fd_fixtures;

-- 9. Check if any players exist
SELECT COUNT(*) as total_players FROM public.fd_players;

-- 10. Sample of recent gameweek points with stats
SELECT 
    pgp.gameweek,
    pgp.player_id,
    pgp.fixture_id,
    pgp.points,
    pgp.expected_goals,
    pgp.expected_assists,
    pgp.raw_stats
FROM public.fd_player_gameweek_points pgp
ORDER BY pgp.updated_at DESC
LIMIT 10;

-- 11. One-shot ingestion health check (single result set)
SELECT 'fd_teams' AS table_name, COUNT(*)::bigint AS row_count FROM public.fd_teams
UNION ALL
SELECT 'fd_fixtures', COUNT(*)::bigint FROM public.fd_fixtures
UNION ALL
SELECT 'fd_players', COUNT(*)::bigint FROM public.fd_players
UNION ALL
SELECT 'fd_player_gameweek_points', COUNT(*)::bigint FROM public.fd_player_gameweek_points
UNION ALL
SELECT 'fd_fixture_events', COUNT(*)::bigint FROM public.fd_fixture_events
UNION ALL
SELECT 'fd_team_form', COUNT(*)::bigint FROM public.fd_team_form
UNION ALL
SELECT 'fd_player_match_stats', COUNT(*)::bigint FROM public.fd_player_match_stats
UNION ALL
SELECT 'fd_player_injuries', COUNT(*)::bigint FROM public.fd_player_injuries
UNION ALL
SELECT 'fd_player_suspensions', COUNT(*)::bigint FROM public.fd_player_suspensions
ORDER BY table_name;

-- 12. Fixture season coverage check (helps explain 0-match enrichments)
SELECT season, COUNT(*) AS fixtures
FROM public.fd_fixtures
GROUP BY season
ORDER BY season DESC;

-- 13. Most recent fixtures loaded
SELECT
    f.external_id,
    f.season,
    f.utc_kickoff,
    f.status,
    ht.name AS home_team_name,
    at.name AS away_team_name
FROM public.fd_fixtures f
LEFT JOIN public.fd_teams ht ON ht.id = f.home_team_id
LEFT JOIN public.fd_teams at ON at.id = f.away_team_id
ORDER BY f.utc_kickoff DESC
LIMIT 20;
