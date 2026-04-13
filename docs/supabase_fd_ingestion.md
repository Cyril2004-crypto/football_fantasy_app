# Supabase Football-Data Ingestion (Premier League)

This ingests real EPL data into:

- `public.fd_competitions`
- `public.fd_teams`
- `public.fd_fixtures`
- `public.fd_players`

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

select p.name, t.name as team
from public.fd_players p
left join public.fd_teams t on t.id = p.team_id
where p.provider = 'football-data'
order by p.name
limit 50;
```

## Notes

- `fd_player_gameweek_points` is not filled by this function because football-data may not provide enough per-player event detail for accurate fantasy scoring on all plans.
- Add a second ingestion source (e.g. Sportmonks) for per-player match stats if you want true gameweek fantasy points.

## Schema upgrade required for current app screens

Run `supabase/sql/fd_schema_upgrade.sql` once in the Supabase SQL Editor if your existing tables were created before the latest app changes.
