-- Upgrade existing football-data tables to match the Flutter app expectations.
-- Run this once in the Supabase SQL Editor.

alter table public.fd_players
  add column if not exists is_active boolean not null default true,
  add column if not exists last_seen_at timestamptz;

alter table public.fd_fixtures
  add column if not exists venue text;

alter table public.fd_player_gameweek_points
  add column if not exists expected_goals numeric(8,3) not null default 0,
  add column if not exists expected_assists numeric(8,3) not null default 0,
  add column if not exists raw_stats jsonb;

-- Optional: ensure old rows are marked active after the new column exists.
update public.fd_players
set is_active = true
where is_active is null;

-- Helpful indexes for the app screens.
create index if not exists idx_fd_players_active
  on public.fd_players (provider, is_active, name);

create index if not exists idx_fd_fixtures_gameweek
  on public.fd_fixtures (provider, competition_id, season, gameweek);

-- New supporting tables for richer gameweek-point calculations.
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

alter table public.fd_fixture_events enable row level security;
alter table public.fd_player_match_stats enable row level security;
alter table public.fd_team_form enable row level security;
alter table public.fd_player_injuries enable row level security;
alter table public.fd_player_suspensions enable row level security;
alter table public.fd_player_form enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_fixture_events' and policyname = 'fd_fixture_events_read_all'
  ) then
    create policy fd_fixture_events_read_all on public.fd_fixture_events for select using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_player_match_stats' and policyname = 'fd_player_match_stats_read_all'
  ) then
    create policy fd_player_match_stats_read_all on public.fd_player_match_stats for select using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_team_form' and policyname = 'fd_team_form_read_all'
  ) then
    create policy fd_team_form_read_all on public.fd_team_form for select using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_player_injuries' and policyname = 'fd_player_injuries_read_all'
  ) then
    create policy fd_player_injuries_read_all on public.fd_player_injuries for select using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_player_suspensions' and policyname = 'fd_player_suspensions_read_all'
  ) then
    create policy fd_player_suspensions_read_all on public.fd_player_suspensions for select using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_player_form' and policyname = 'fd_player_form_read_all'
  ) then
    create policy fd_player_form_read_all on public.fd_player_form for select using (true);
  end if;
end $$;
