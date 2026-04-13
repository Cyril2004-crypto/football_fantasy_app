-- Upgrade existing football-data tables to match the Flutter app expectations.
-- Run this once in the Supabase SQL Editor.

alter table public.fd_players
  add column if not exists is_active boolean not null default true,
  add column if not exists last_seen_at timestamptz;

alter table public.fd_fixtures
  add column if not exists venue text;

-- Optional: ensure old rows are marked active after the new column exists.
update public.fd_players
set is_active = true
where is_active is null;

-- Helpful indexes for the app screens.
create index if not exists idx_fd_players_active
  on public.fd_players (provider, is_active, name);

create index if not exists idx_fd_fixtures_gameweek
  on public.fd_fixtures (provider, competition_id, season, gameweek);
