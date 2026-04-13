-- Daily ingestion schedule for football-data sync.
-- Run in Supabase SQL Editor after the sync-fd-data function has been deployed.
-- This uses pg_cron + pg_net + Vault secrets.

create extension if not exists pg_cron;
create extension if not exists pg_net;
create extension if not exists vault;

-- Store the function URL and secret in Vault.
-- Replace YOUR_INGESTION_SECRET with the same secret used in the function.
select vault.create_secret(
  'https://oznmbinzelhcnfiwvapu.functions.supabase.co/sync-fd-data',
  'fd_sync_function_url'
);

select vault.create_secret(
  'YOUR_INGESTION_SECRET',
  'fd_ingestion_secret'
);

-- Schedule a daily sync at 02:00 UTC.
select cron.schedule(
  'daily-sync-fd-data',
  '0 2 * * *',
  $$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name = 'fd_sync_function_url'),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-ingestion-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'fd_ingestion_secret')
      ),
      body := jsonb_build_object(
        'competitionExternalId', '2021',
        'season', 2025
      )
    ) as request_id;
  $$
);
