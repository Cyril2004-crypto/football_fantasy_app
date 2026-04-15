-- Daily schedule for Sportmonks enrichment sync.
-- Run after deploying `sync-sportmonks-data` function.

create extension if not exists pg_cron;
create extension if not exists pg_net;
create extension if not exists vault;

-- Store function URL and shared secret in Vault.
select vault.create_secret(
  'https://oznmbinzelhcnfiwvapu.functions.supabase.co/sync-sportmonks-data',
  'sportmonks_sync_function_url'
);

select vault.create_secret(
  'YOUR_INGESTION_SECRET',
  'sportmonks_ingestion_secret'
);

-- Schedule every 20 minutes for near-live enrichment.
select cron.schedule(
  'sportmonks-enrichment-20m',
  '*/20 * * * *',
  $$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name = 'sportmonks_sync_function_url'),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-ingestion-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'sportmonks_ingestion_secret')
      ),
      body := jsonb_build_object(
        'competitionExternalId', '2021',
        'season', 2025
      )
    ) as request_id;
  $$
);
