-- Daily schedule for Sportmonks enrichment sync.
-- Run after deploying `sync-sportmonks-data` function.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Schedule every 20 minutes for near-live enrichment.
select cron.schedule(
  'sportmonks-enrichment-20m',
  '*/20 * * * *',
  $$
    select net.http_post(
      url := 'https://oznmbinzelhcnfiwvapu.functions.supabase.co/sync-sportmonks-data',
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
