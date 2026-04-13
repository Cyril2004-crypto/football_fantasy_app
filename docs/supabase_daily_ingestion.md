# Daily Supabase Ingestion

This schedules the `sync-fd-data` Edge Function to run every day at 02:00 UTC.

## SQL file

- `supabase/sql/schedule_daily_ingestion.sql`

## Schema upgrade to run first

- `supabase/sql/fd_schema_upgrade.sql`

## Before running

1. Deploy the Edge Function:
   - `sync-fd-data`
2. Make sure these secrets are set:
   - `SERVICE_ROLE_KEY`
   - `FOOTBALL_DATA_API_TOKEN`
   - `INGESTION_SHARED_SECRET`
3. Replace `YOUR_INGESTION_SECRET` in the SQL file with the same secret value.

## Required extensions

- `pg_cron`
- `pg_net`
- `vault`

## Verify schedule

```sql
select * from cron.job order by jobid desc;
```

## Verify requests

```sql
select * from net._http_response order by created desc limit 20;
```

## Notes

- The scheduled job posts to your deployed Edge Function.
- If you rotate the ingestion secret, update both the function secret and the Vault value used by this schedule.
