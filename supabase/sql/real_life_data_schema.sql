-- Real-life football data schema
-- Run this in Supabase SQL Editor (or via supabase db push if you use migrations).

-- 1) Competitions
create table if not exists public.fd_competitions (
  id bigserial primary key,
  provider text not null default 'football-data',
  external_id text not null,
  code text,
  name text not null,
  country text,
  updated_at timestamptz not null default now(),
  unique (provider, external_id)
);

-- 2) Teams
create table if not exists public.fd_teams (
  id bigserial primary key,
  provider text not null default 'football-data',
  external_id text not null,
  name text not null,
  short_name text,
  tla text,
  crest_url text,
  competition_id bigint references public.fd_competitions(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique (provider, external_id)
);

-- 3) Players
create table if not exists public.fd_players (
  id bigserial primary key,
  provider text not null default 'football-data',
  external_id text not null,
  team_id bigint references public.fd_teams(id) on delete set null,
  name text not null,
  position text,
  nationality text,
  price numeric(6,2),
  is_active boolean not null default true,
  last_seen_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (provider, external_id)
);

-- 4) Fixtures (real matches)
create table if not exists public.fd_fixtures (
  id bigserial primary key,
  provider text not null default 'football-data',
  external_id text not null,
  competition_id bigint not null references public.fd_competitions(id) on delete cascade,
  season text not null,
  gameweek int not null,
  utc_kickoff timestamptz not null,
  status text not null,
  home_team_id bigint not null references public.fd_teams(id),
  away_team_id bigint not null references public.fd_teams(id),
  home_score int,
  away_score int,
  updated_at timestamptz not null default now(),
  unique (provider, external_id)
);

-- 5) Player points per gameweek
create table if not exists public.fd_player_gameweek_points (
  id bigserial primary key,
  player_id bigint not null references public.fd_players(id) on delete cascade,
  season text not null,
  gameweek int not null,
  fixture_id bigint references public.fd_fixtures(id) on delete set null,
  minutes int not null default 0,
  goals int not null default 0,
  assists int not null default 0,
  expected_goals numeric(8,3) not null default 0,
  expected_assists numeric(8,3) not null default 0,
  clean_sheet boolean not null default false,
  yellow_cards int not null default 0,
  red_cards int not null default 0,
  saves int not null default 0,
  bonus int not null default 0,
  points int not null default 0,
  source text not null default 'ingested',
  raw_stats jsonb,
  updated_at timestamptz not null default now(),
  unique (player_id, season, gameweek, fixture_id)
);

-- 6) Match events (goals, assists, cards, substitutions, etc.)
create table if not exists public.fd_fixture_events (
  id bigserial primary key,
  fixture_id bigint not null references public.fd_fixtures(id) on delete cascade,
  provider text not null default 'football-data',
  external_id text not null,
  event_type text not null,
  minute int,
  team_id bigint references public.fd_teams(id) on delete set null,
  player_id bigint references public.fd_players(id) on delete set null,
  related_player_id bigint references public.fd_players(id) on delete set null,
  description text,
  raw_event jsonb,
  created_at timestamptz not null default now(),
  unique (provider, external_id)
);

-- 7) Player match stats (one row per player per fixture)
create table if not exists public.fd_player_match_stats (
  id bigserial primary key,
  fixture_id bigint not null references public.fd_fixtures(id) on delete cascade,
  player_id bigint not null references public.fd_players(id) on delete cascade,
  team_id bigint references public.fd_teams(id) on delete set null,
  season text not null,
  gameweek int not null,
  minutes int not null default 0,
  goals int not null default 0,
  assists int not null default 0,
  expected_goals numeric(8,3) not null default 0,
  expected_assists numeric(8,3) not null default 0,
  clean_sheet boolean not null default false,
  yellow_cards int not null default 0,
  red_cards int not null default 0,
  saves int not null default 0,
  shots int not null default 0,
  shots_on_target int not null default 0,
  passes_completed int not null default 0,
  tackles int not null default 0,
  interceptions int not null default 0,
  bonus int not null default 0,
  raw_stats jsonb,
  updated_at timestamptz not null default now(),
  unique (fixture_id, player_id)
);

-- 8) Team recent form / rolling team stats
create table if not exists public.fd_team_form (
  id bigserial primary key,
  team_id bigint not null references public.fd_teams(id) on delete cascade,
  competition_id bigint references public.fd_competitions(id) on delete set null,
  season text not null,
  gameweek int not null,
  matches_played int not null default 0,
  wins int not null default 0,
  draws int not null default 0,
  losses int not null default 0,
  goals_for int not null default 0,
  goals_against int not null default 0,
  form_points int not null default 0,
  expected_goals_for numeric(8,3) not null default 0,
  expected_goals_against numeric(8,3) not null default 0,
  raw_stats jsonb,
  updated_at timestamptz not null default now(),
  unique (team_id, season, gameweek)
);

-- 9) Injury status tracking
create table if not exists public.fd_player_injuries (
  id bigserial primary key,
  player_id bigint not null references public.fd_players(id) on delete cascade,
  provider text not null default 'sportmonks',
  external_id text,
  season text not null,
  status text not null,
  reason text,
  expected_return text,
  notes text,
  source_url text,
  raw_payload jsonb,
  updated_at timestamptz not null default now(),
  unique (provider, external_id),
  unique (player_id, season, status)
);

-- 10) Suspension status tracking
create table if not exists public.fd_player_suspensions (
  id bigserial primary key,
  player_id bigint not null references public.fd_players(id) on delete cascade,
  provider text not null default 'sportmonks',
  external_id text,
  season text not null,
  reason text,
  matches_remaining int not null default 0,
  source_url text,
  raw_payload jsonb,
  updated_at timestamptz not null default now(),
  unique (provider, external_id),
  unique (player_id, season)
);

-- 11) Aggregated player form snapshot (helpful for ranking/recommendations)
create table if not exists public.fd_player_form (
  id bigserial primary key,
  player_id bigint not null references public.fd_players(id) on delete cascade,
  team_id bigint references public.fd_teams(id) on delete set null,
  season text not null,
  gameweek int not null,
  last_3_avg numeric(8,3) not null default 0,
  last_5_avg numeric(8,3) not null default 0,
  minutes_last_5 int not null default 0,
  goals_last_5 int not null default 0,
  assists_last_5 int not null default 0,
  xg_last_5 numeric(8,3) not null default 0,
  xa_last_5 numeric(8,3) not null default 0,
  raw_stats jsonb,
  updated_at timestamptz not null default now(),
  unique (player_id, season, gameweek)
);

create index if not exists idx_fd_fixtures_comp_season_gw
  on public.fd_fixtures (competition_id, season, gameweek);

create index if not exists idx_fd_player_gw_lookup
  on public.fd_player_gameweek_points (season, gameweek, player_id);

create index if not exists idx_fd_fixture_events_fixture
  on public.fd_fixture_events (fixture_id, event_type);

create index if not exists idx_fd_player_match_stats_lookup
  on public.fd_player_match_stats (season, gameweek, player_id);

create index if not exists idx_fd_team_form_lookup
  on public.fd_team_form (season, gameweek, team_id);

create index if not exists idx_fd_player_injuries_lookup
  on public.fd_player_injuries (season, player_id, status);

create index if not exists idx_fd_player_suspensions_lookup
  on public.fd_player_suspensions (season, player_id);

create index if not exists idx_fd_player_form_lookup
  on public.fd_player_form (season, gameweek, player_id);

-- Recommended: public read for real-life data tables, write via service role only.
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

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_competitions' and policyname = 'fd_competitions_read_limited'
  ) then
    create policy fd_competitions_read_limited on public.fd_competitions for select to anon, authenticated using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_teams' and policyname = 'fd_teams_read_limited'
  ) then
    create policy fd_teams_read_limited on public.fd_teams for select to anon, authenticated using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_players' and policyname = 'fd_players_read_limited'
  ) then
    create policy fd_players_read_limited on public.fd_players for select to anon, authenticated using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_fixtures' and policyname = 'fd_fixtures_read_limited'
  ) then
    create policy fd_fixtures_read_limited on public.fd_fixtures for select to anon, authenticated using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_player_gameweek_points' and policyname = 'fd_player_gameweek_points_read_limited'
  ) then
    create policy fd_player_gameweek_points_read_limited on public.fd_player_gameweek_points for select to anon, authenticated using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_fixture_events' and policyname = 'fd_fixture_events_read_limited'
  ) then
    create policy fd_fixture_events_read_limited on public.fd_fixture_events for select to anon, authenticated using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_player_match_stats' and policyname = 'fd_player_match_stats_read_limited'
  ) then
    create policy fd_player_match_stats_read_limited on public.fd_player_match_stats for select to anon, authenticated using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_team_form' and policyname = 'fd_team_form_read_limited'
  ) then
    create policy fd_team_form_read_limited on public.fd_team_form for select to anon, authenticated using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_player_injuries' and policyname = 'fd_player_injuries_read_limited'
  ) then
    create policy fd_player_injuries_read_limited on public.fd_player_injuries for select to anon, authenticated using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_player_suspensions' and policyname = 'fd_player_suspensions_read_limited'
  ) then
    create policy fd_player_suspensions_read_limited on public.fd_player_suspensions for select to anon, authenticated using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_player_form' and policyname = 'fd_player_form_read_limited'
  ) then
    create policy fd_player_form_read_limited on public.fd_player_form for select to anon, authenticated using (true);
  end if;
end $$;
