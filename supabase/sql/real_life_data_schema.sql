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
  clean_sheet boolean not null default false,
  yellow_cards int not null default 0,
  red_cards int not null default 0,
  saves int not null default 0,
  bonus int not null default 0,
  points int not null default 0,
  source text not null default 'ingested',
  updated_at timestamptz not null default now(),
  unique (player_id, season, gameweek, fixture_id)
);

create index if not exists idx_fd_fixtures_comp_season_gw
  on public.fd_fixtures (competition_id, season, gameweek);

create index if not exists idx_fd_player_gw_lookup
  on public.fd_player_gameweek_points (season, gameweek, player_id);

-- Recommended: public read for real-life data tables, write via service role only.
alter table public.fd_competitions enable row level security;
alter table public.fd_teams enable row level security;
alter table public.fd_players enable row level security;
alter table public.fd_fixtures enable row level security;
alter table public.fd_player_gameweek_points enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_competitions' and policyname = 'fd_competitions_read_all'
  ) then
    create policy fd_competitions_read_all on public.fd_competitions for select using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_teams' and policyname = 'fd_teams_read_all'
  ) then
    create policy fd_teams_read_all on public.fd_teams for select using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_players' and policyname = 'fd_players_read_all'
  ) then
    create policy fd_players_read_all on public.fd_players for select using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_fixtures' and policyname = 'fd_fixtures_read_all'
  ) then
    create policy fd_fixtures_read_all on public.fd_fixtures for select using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fd_player_gameweek_points' and policyname = 'fd_player_gameweek_points_read_all'
  ) then
    create policy fd_player_gameweek_points_read_all on public.fd_player_gameweek_points for select using (true);
  end if;
end $$;
