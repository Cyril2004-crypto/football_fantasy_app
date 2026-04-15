# Supabase Sportmonks Enrichment Ingestion

This enriches your fantasy data with Sportmonks live/match-centre data and writes into:

- `public.fd_fixture_events` (provider `sportmonks`)
- `public.fd_player_match_stats`
- `public.fd_player_gameweek_points` (source `sportmonks-lineups`)
- `public.fd_player_injuries`
- `public.fd_player_suspensions`

Function file:

- `supabase/functions/sync-sportmonks-data/index.ts`

## 1) Deploy function

```bash
supabase login
supabase link --project-ref <your-project-ref>
supabase functions deploy sync-sportmonks-data --no-verify-jwt
```

## 2) Set required secrets

```bash
supabase secrets set SERVICE_ROLE_KEY=<your-service-role-key>
supabase secrets set SPORTMONKS_API_TOKEN=<your-sportmonks-token>
```

Optional hardening:

```bash
supabase secrets set INGESTION_SHARED_SECRET=<long-random-secret>
```

## 3) Invoke the function

```bash
curl -X POST "https://<project-ref>.functions.supabase.co/sync-sportmonks-data" \
  -H "Content-Type: application/json" \
  -H "x-ingestion-secret: <long-random-secret>" \
  -d '{"competitionExternalId":"2021","season":2025}'
```

If you did not set `INGESTION_SHARED_SECRET`, omit that header.

## 4) Verify enrichment rows

```sql
select count(*) from public.fd_fixture_events where provider = 'sportmonks';
select count(*) from public.fd_player_match_stats;
select count(*) from public.fd_player_injuries;
select count(*) from public.fd_player_suspensions;

select p.name, gp.gameweek, gp.points, gp.expected_goals, gp.expected_assists, gp.source
from public.fd_player_gameweek_points gp
join public.fd_players p on p.id = gp.player_id
where gp.source = 'sportmonks-lineups'
order by gp.updated_at desc
limit 50;
```

## Notes

- This first version enriches best-effort from in-play fixtures and match-centre payloads.
- Player mapping uses normalized `team + player name` against your `fd_players` table.
- If Sportmonks IDs differ from football-data IDs, some rows may not map until you add provider mapping tables.
- Next hardening step: add explicit cross-provider mapping tables (`provider_player_map`, `provider_team_map`).
