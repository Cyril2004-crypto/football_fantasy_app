-- Option 2 (Firebase Auth + trusted server write) setup for public.users

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  firebase_uid text not null unique,
  email text not null unique,
  username text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Service-role writes bypass RLS, but keep client roles blocked.
alter table public.users enable row level security;

revoke all on table public.users from anon;
revoke all on table public.users from authenticated;

-- No policies for anon/authenticated means no direct client access.
-- If you need client reads later, add a narrow select policy explicitly.
