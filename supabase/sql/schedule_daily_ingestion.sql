-- Daily ingestion schedule for football-data sync.
-- Run in Supabase SQL Editor after the sync-fd-data function has been deployed.
-- This uses pg_cron + pg_net + Vault secrets.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Schedule a daily sync at 02:00 UTC.
select cron.schedule(
  'daily-sync-fd-data',
  '0 2 * * *',
  $$
    select net.http_post(
      url := 'https://oznmbinzelhcnfiwvapu.functions.supabase.co/sync-fd-data',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-ingestion-secret', 'BwRfOFXvWxcj3Lm6VnaoUKzudCSZYEeMPtIQs24khNq0l781'
      ),
      body := jsonb_build_object(
        'competitionExternalId', '2021',
        'season', 2025
      )
    ) as request_id;
  $$
);
