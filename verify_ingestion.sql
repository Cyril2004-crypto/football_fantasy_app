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

-- 14. Freshness check (most recent updates by table)
SELECT 'fd_player_gameweek_points' AS table_name, MAX(updated_at) AS last_updated
FROM public.fd_player_gameweek_points
UNION ALL
SELECT 'fd_player_match_stats', MAX(updated_at)
FROM public.fd_player_match_stats
UNION ALL
SELECT 'fd_fixture_events', MAX(created_at)
FROM public.fd_fixture_events
UNION ALL
SELECT 'fd_team_form', MAX(updated_at)
FROM public.fd_team_form
UNION ALL
SELECT 'fd_player_injuries', MAX(updated_at)
FROM public.fd_player_injuries
UNION ALL
SELECT 'fd_player_suspensions', MAX(updated_at)
FROM public.fd_player_suspensions
ORDER BY table_name;

-- 15. Last 7 days write activity (pipeline heartbeat)
SELECT 'fd_fixture_events' AS table_name, DATE(created_at) AS day, COUNT(*) AS rows_written
FROM public.fd_fixture_events
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
UNION ALL
SELECT 'fd_player_match_stats', DATE(updated_at), COUNT(*)
FROM public.fd_player_match_stats
WHERE updated_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(updated_at)
UNION ALL
SELECT 'fd_player_gameweek_points', DATE(updated_at), COUNT(*)
FROM public.fd_player_gameweek_points
WHERE updated_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(updated_at)
UNION ALL
SELECT 'fd_team_form', DATE(updated_at), COUNT(*)
FROM public.fd_team_form
WHERE updated_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(updated_at)
ORDER BY day DESC, table_name;

-- 16. xG/xA coverage by season (quality monitor)
SELECT
    season,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE expected_goals > 0) AS rows_with_xg,
    COUNT(*) FILTER (WHERE expected_assists > 0) AS rows_with_xa
FROM public.fd_player_match_stats
GROUP BY season
ORDER BY season DESC;

-- 17. Injury and suspension trend by update date (last 30 days)
SELECT 'injuries' AS bucket, DATE(updated_at) AS day, COUNT(*) AS rows
FROM public.fd_player_injuries
WHERE updated_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(updated_at)
UNION ALL
SELECT 'suspensions', DATE(updated_at), COUNT(*)
FROM public.fd_player_suspensions
WHERE updated_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(updated_at)
ORDER BY day DESC, bucket;

-- 18. Duplicate safety check (should return zero rows)
SELECT player_id, season, gameweek, fixture_id, COUNT(*) AS dupes
FROM public.fd_player_gameweek_points
GROUP BY player_id, season, gameweek, fixture_id
HAVING COUNT(*) > 1
ORDER BY dupes DESC;

-- 19. Event uniqueness check (should return zero rows)
SELECT provider, external_id, COUNT(*) AS dupes
FROM public.fd_fixture_events
GROUP BY provider, external_id
HAVING COUNT(*) > 1
ORDER BY dupes DESC;

-- 20. Rows currently at zero expected metrics (can indicate source gaps)
SELECT
    season,
    COUNT(*) FILTER (WHERE expected_goals = 0) AS zero_xg_rows,
    COUNT(*) FILTER (WHERE expected_assists = 0) AS zero_xa_rows,
    COUNT(*) AS total_rows
FROM public.fd_player_gameweek_points
GROUP BY season
ORDER BY season DESC;

-- 21. Active ingestion alerts (should be empty when healthy)
SELECT
    id,
    source,
    alert_code,
    severity,
    message,
    first_seen_at,
    last_seen_at,
    occurrence_count,
    last_notified_at
FROM public.ingestion_alert_events
WHERE is_active = true
ORDER BY severity DESC, last_seen_at DESC;

-- 22. Alert history (latest 20)
SELECT
    id,
    source,
    alert_code,
    severity,
    is_active,
    first_seen_at,
    last_seen_at,
    resolved_at,
    last_notified_at
FROM public.ingestion_alert_events
ORDER BY id DESC
LIMIT 20;

-- 23. Alert job run status (evaluate + notify)
SELECT
    j.jobname,
    d.start_time,
    d.end_time,
    d.status,
    d.return_message
FROM cron.job_run_details d
JOIN cron.job j ON j.jobid = d.jobid
WHERE j.jobname IN ('evaluate-ingestion-alerts', 'notify-ingestion-alerts')
ORDER BY d.start_time DESC
LIMIT 30;
