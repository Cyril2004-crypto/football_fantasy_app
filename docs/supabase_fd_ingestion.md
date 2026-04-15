# Supabase Football-Data Ingestion (Premier League)

This ingests real EPL data into:

- `public.fd_competitions`
- `public.fd_teams`
- `public.fd_fixtures`
- `public.fd_players`
- `public.fd_fixture_events`
- `public.fd_player_match_stats`
- `public.fd_team_form`
- `public.fd_player_gameweek_points`

Function file:

- `supabase/functions/sync-fd-data/index.ts`

## 1) Deploy function

```bash
supabase login
supabase link --project-ref <your-project-ref>
supabase functions deploy sync-fd-data --no-verify-jwt
```

## 2) Set required secrets

```bash
supabase secrets set SERVICE_ROLE_KEY=<your-service-role-key>
supabase secrets set FOOTBALL_DATA_API_TOKEN=<your-football-data-token>
```

Optional hardening:

```bash
supabase secrets set INGESTION_SHARED_SECRET=<long-random-secret>
```

## 3) Invoke the function

Default call uses EPL (`competitionExternalId=2021`) and season 2025.

```bash
curl -X POST "https://<project-ref>.functions.supabase.co/sync-fd-data" \
  -H "Content-Type: application/json" \
  -H "x-ingestion-secret: <long-random-secret>" \
  -d '{"competitionExternalId":"2021","season":2025}'
```

If you did not set `INGESTION_SHARED_SECRET`, omit that header.

## 4) Verify data

```sql
select count(*) from public.fd_competitions;
select count(*) from public.fd_teams;
select count(*) from public.fd_fixtures;
select count(*) from public.fd_players;
select count(*) from public.fd_fixture_events;
select count(*) from public.fd_player_match_stats;
select count(*) from public.fd_team_form;
select count(*) from public.fd_player_gameweek_points;

select p.name, t.name as team
from public.fd_players p
left join public.fd_teams t on t.id = p.team_id
where p.provider = 'football-data'
order by p.name
limit 50;

select p.name, gp.gameweek, gp.points, gp.goals, gp.assists, gp.clean_sheet
from public.fd_player_gameweek_points gp
join public.fd_players p on p.id = gp.player_id
order by gp.gameweek desc, gp.points desc
limit 50;

select t.name, tf.gameweek, tf.matches_played, tf.wins, tf.draws, tf.losses, tf.form_points
from public.fd_team_form tf
join public.fd_teams t on t.id = tf.team_id
order by tf.gameweek desc, tf.form_points desc
limit 50;
```

## Notes

- The function now computes points from match events and also stores fixture events, per-player match stats, and team form snapshots.
- For fuller fantasy context, add a second ingestion source (e.g. Sportmonks) for injuries, suspensions, xG/xA, and deeper player form data.
- `fd_player_injuries`, `fd_player_suspensions`, and `fd_player_form` are prepared in the schema for that second enrichment step.

## Schema upgrade required for current app screens

Run `supabase/sql/fd_schema_upgrade.sql` once in the Supabase SQL Editor if your existing tables were created before the latest app changes.
