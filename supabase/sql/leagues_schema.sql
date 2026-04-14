-- Fantasy league schema for public/private leagues and team snapshots.

create extension if not exists pgcrypto;

create table if not exists public.fantasy_teams (
  id uuid primary key default gen_random_uuid(),
  user_id text not null unique,
  user_name text,
  team_name text not null,
  total_points int not null default 0,
  gameweek_points int not null default 0,
  remaining_budget numeric(6,2) not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.fantasy_leagues (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text unique,
  type text not null check (type in ('public', 'private')),
  created_by_user_id text not null,
  created_by_name text,
  members_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.fantasy_league_members (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.fantasy_leagues(id) on delete cascade,
  user_id text not null,
  joined_at timestamptz not null default now(),
  unique (league_id, user_id)
);

create index if not exists idx_fantasy_league_members_league_id on public.fantasy_league_members (league_id);
create index if not exists idx_fantasy_league_members_user_id on public.fantasy_league_members (user_id);
create index if not exists idx_fantasy_teams_user_id on public.fantasy_teams (user_id);

alter table public.fantasy_teams enable row level security;
alter table public.fantasy_leagues enable row level security;
alter table public.fantasy_league_members enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fantasy_teams' and policyname = 'fantasy_teams_read_all'
  ) then
    create policy fantasy_teams_read_all on public.fantasy_teams for select using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fantasy_leagues' and policyname = 'fantasy_leagues_read_all'
  ) then
    create policy fantasy_leagues_read_all on public.fantasy_leagues for select using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'fantasy_league_members' and policyname = 'fantasy_league_members_read_all'
  ) then
    create policy fantasy_league_members_read_all on public.fantasy_league_members for select using (true);
  end if;
end $$;
