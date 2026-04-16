-- Least-privilege access hardening for the Flutter app.
--
-- Goals:
-- - Keep direct client read access only where the app needs it.
-- - Lock league/team tables away from direct client access.
-- - Preserve RPC-based cron visibility via public.get_ops_cron_job_statuses().
--
-- Run this in Supabase SQL editor as a privileged role.

-- -----------------------------------------------------------------------------
-- 1) App-read tables: explicit client read grants + narrow RLS policies
-- -----------------------------------------------------------------------------

alter table public.fd_competitions enable row level security;
alter table public.fd_teams enable row level security;
alter table public.fd_players enable row level security;
alter table public.fd_fixtures enable row level security;
alter table public.fd_player_gameweek_points enable row level security;
alter table public.fd_fixture_events enable row level security;
alter table public.fd_player_match_stats enable row level security;
alter table public.fd_team_form enable row level security;
alter table public.fd_player_injuries enable row level security;
alter table public.fd_player_suspensions enable row level security;
alter table public.fd_player_form enable row level security;
alter table public.ingestion_health_snapshots enable row level security;
alter table public.ingestion_alert_events enable row level security;

revoke all on table public.fd_competitions from public, anon, authenticated;
revoke all on table public.fd_teams from public, anon, authenticated;
revoke all on table public.fd_players from public, anon, authenticated;
revoke all on table public.fd_fixtures from public, anon, authenticated;
revoke all on table public.fd_player_gameweek_points from public, anon, authenticated;
revoke all on table public.fd_fixture_events from public, anon, authenticated;
revoke all on table public.fd_player_match_stats from public, anon, authenticated;
revoke all on table public.fd_team_form from public, anon, authenticated;
revoke all on table public.fd_player_injuries from public, anon, authenticated;
revoke all on table public.fd_player_suspensions from public, anon, authenticated;
revoke all on table public.fd_player_form from public, anon, authenticated;
revoke all on table public.ingestion_health_snapshots from public, anon, authenticated;
revoke all on table public.ingestion_alert_events from public, anon, authenticated;

grant select on table public.fd_competitions to anon, authenticated;
grant select on table public.fd_teams to anon, authenticated;
grant select on table public.fd_players to anon, authenticated;
grant select on table public.fd_fixtures to anon, authenticated;
grant select on table public.fd_player_gameweek_points to anon, authenticated;
grant select on table public.fd_fixture_events to anon, authenticated;
grant select on table public.fd_player_match_stats to anon, authenticated;
grant select on table public.fd_team_form to anon, authenticated;
grant select on table public.fd_player_injuries to anon, authenticated;
grant select on table public.fd_player_suspensions to anon, authenticated;
grant select on table public.fd_player_form to anon, authenticated;
grant select on table public.ingestion_health_snapshots to anon, authenticated;
grant select on table public.ingestion_alert_events to anon, authenticated;

drop policy if exists fd_competitions_read_all on public.fd_competitions;
drop policy if exists fd_competitions_read_limited on public.fd_competitions;
drop policy if exists fd_teams_read_all on public.fd_teams;
drop policy if exists fd_teams_read_limited on public.fd_teams;
drop policy if exists fd_players_read_all on public.fd_players;
drop policy if exists fd_players_read_limited on public.fd_players;
drop policy if exists fd_fixtures_read_all on public.fd_fixtures;
drop policy if exists fd_fixtures_read_limited on public.fd_fixtures;
drop policy if exists fd_player_gameweek_points_read_all on public.fd_player_gameweek_points;
drop policy if exists fd_player_gameweek_points_read_limited on public.fd_player_gameweek_points;
drop policy if exists fd_fixture_events_read_all on public.fd_fixture_events;
drop policy if exists fd_fixture_events_read_limited on public.fd_fixture_events;
drop policy if exists fd_player_match_stats_read_all on public.fd_player_match_stats;
drop policy if exists fd_player_match_stats_read_limited on public.fd_player_match_stats;
drop policy if exists fd_team_form_read_all on public.fd_team_form;
drop policy if exists fd_team_form_read_limited on public.fd_team_form;
drop policy if exists fd_player_injuries_read_all on public.fd_player_injuries;
drop policy if exists fd_player_injuries_read_limited on public.fd_player_injuries;
drop policy if exists fd_player_suspensions_read_all on public.fd_player_suspensions;
drop policy if exists fd_player_suspensions_read_limited on public.fd_player_suspensions;
drop policy if exists fd_player_form_read_all on public.fd_player_form;
drop policy if exists fd_player_form_read_limited on public.fd_player_form;
drop policy if exists read_health_snapshots on public.ingestion_health_snapshots;
drop policy if exists ingestion_health_snapshots_read_limited on public.ingestion_health_snapshots;
drop policy if exists read_ingestion_alert_events on public.ingestion_alert_events;
drop policy if exists ingestion_alert_events_read_limited on public.ingestion_alert_events;

create policy fd_competitions_read_limited on public.fd_competitions
  for select to anon, authenticated
  using (true);

create policy fd_teams_read_limited on public.fd_teams
  for select to anon, authenticated
  using (true);

create policy fd_players_read_limited on public.fd_players
  for select to anon, authenticated
  using (true);

create policy fd_fixtures_read_limited on public.fd_fixtures
  for select to anon, authenticated
  using (true);

create policy fd_player_gameweek_points_read_limited on public.fd_player_gameweek_points
  for select to anon, authenticated
  using (true);

create policy fd_fixture_events_read_limited on public.fd_fixture_events
  for select to anon, authenticated
  using (true);

create policy fd_player_match_stats_read_limited on public.fd_player_match_stats
  for select to anon, authenticated
  using (true);

create policy fd_team_form_read_limited on public.fd_team_form
  for select to anon, authenticated
  using (true);

create policy fd_player_injuries_read_limited on public.fd_player_injuries
  for select to anon, authenticated
  using (true);

create policy fd_player_suspensions_read_limited on public.fd_player_suspensions
  for select to anon, authenticated
  using (true);

create policy fd_player_form_read_limited on public.fd_player_form
  for select to anon, authenticated
  using (true);

create policy ingestion_health_snapshots_read_limited on public.ingestion_health_snapshots
  for select to anon, authenticated
  using (true);

create policy ingestion_alert_events_read_limited on public.ingestion_alert_events
  for select to anon, authenticated
  using (true);

-- -----------------------------------------------------------------------------
-- 2) League/team tables: remove direct client access
-- -----------------------------------------------------------------------------

alter table public.fantasy_teams enable row level security;
alter table public.fantasy_leagues enable row level security;
alter table public.fantasy_league_members enable row level security;

revoke all on table public.fantasy_teams from public, anon, authenticated;
revoke all on table public.fantasy_leagues from public, anon, authenticated;
revoke all on table public.fantasy_league_members from public, anon, authenticated;

drop policy if exists fantasy_teams_read_all on public.fantasy_teams;
drop policy if exists fantasy_teams_read_limited on public.fantasy_teams;
drop policy if exists fantasy_leagues_read_all on public.fantasy_leagues;
drop policy if exists fantasy_leagues_read_limited on public.fantasy_leagues;
drop policy if exists fantasy_league_members_read_all on public.fantasy_league_members;
drop policy if exists fantasy_league_members_read_limited on public.fantasy_league_members;

-- Intentionally no anon/authenticated policies here.
-- These tables should only be reached through trusted server-side functions.

-- -----------------------------------------------------------------------------
-- 3) Cron RPC remains the only client-facing cron path
-- -----------------------------------------------------------------------------

revoke all on function public.get_ops_cron_job_statuses() from public;
grant execute on function public.get_ops_cron_job_statuses() to anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4) Safety note for users table
-- -----------------------------------------------------------------------------
-- public.users is already locked down in users_option2_setup.sql.
