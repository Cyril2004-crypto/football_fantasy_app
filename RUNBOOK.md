# Ingestion Ops Runbook (5-Minute)

This runbook covers daily checks and incident response for:
- football-data sync
- sportmonks enrichment
- ingestion health snapshots
- ingestion anomaly alerts and notifications

## 1) Daily 5-Minute Health Check

Run these in Supabase SQL Editor.

### 1.1 Cron jobs are present and active

```sql
SELECT jobid, jobname, schedule, active
FROM cron.job
WHERE jobname IN (
  'daily-sync-fd-data',
  'sportmonks-enrichment-20m',
  'daily-ingestion-healthcheck',
  'sportmonks-ingestion-healthcheck',
  'evaluate-ingestion-alerts',
  'notify-ingestion-alerts'
)
ORDER BY jobname;
```

Expected:
- All listed jobs exist
- `active = true`

### 1.2 Recent cron runs are succeeding

```sql
SELECT
  j.jobname,
  d.start_time,
  d.end_time,
  d.status,
  d.return_message
FROM cron.job_run_details d
JOIN cron.job j ON j.jobid = d.jobid
WHERE j.jobname IN (
  'sportmonks-enrichment-20m',
  'sportmonks-ingestion-healthcheck',
  'evaluate-ingestion-alerts',
  'notify-ingestion-alerts'
)
ORDER BY d.start_time DESC
LIMIT 30;
```

Expected:
- Recent rows show `status = succeeded`

### 1.3 Latest snapshots exist and are fresh

```sql
SELECT
  id,
  source,
  snapshot_at,
  gameweek_points_count,
  fixture_events_count,
  player_match_stats_count,
  player_injuries_count,
  player_suspensions_count
FROM public.ingestion_health_snapshots
ORDER BY snapshot_at DESC
LIMIT 10;
```

Expected:
- Recent `sportmonks-enrichment` rows present
- Counts are non-zero and stable

### 1.4 No active alerts (normal state)

```sql
SELECT
  id,
  source,
  alert_code,
  severity,
  message,
  first_seen_at,
  last_seen_at,
  occurrence_count,
  last_notified_at
FROM public.ingestion_alert_events
WHERE is_active = true
ORDER BY severity DESC, last_seen_at DESC;
```

Expected:
- Zero rows in healthy state

## 2) Weekly Notification Test (2 Minutes)

Use a controlled forced alert to verify end-to-end notification.

### 2.1 Create forced test alert

```sql
SELECT public.upsert_ingestion_alert(
  'sportmonks-enrichment',
  'forced_closeout_test',
  'warning',
  'Forced closeout test alert',
  jsonb_build_object('source', 'manual-test')
);
```

### 2.2 Trigger notifier manually

Use terminal (replace with current secret):

```powershell
curl.exe -s -X POST "https://oznmbinzelhcnfiwvapu.functions.supabase.co/send-ingestion-alerts" -H "Content-Type: application/json" -H "x-ingestion-secret: <INGESTION_SHARED_SECRET>" -d "{\"source\":\"sportmonks-enrichment\"}"
```

Expected:
- Response includes `"message":"Alerts sent"`

### 2.3 Verify notification mark

```sql
SELECT
  id,
  alert_code,
  is_active,
  last_seen_at,
  last_notified_at
FROM public.ingestion_alert_events
WHERE alert_code = 'forced_closeout_test'
ORDER BY id DESC
LIMIT 1;
```

Expected:
- `last_notified_at` is not null

### 2.4 Cleanup test alert

```sql
SELECT public.resolve_ingestion_alert('sportmonks-enrichment', 'forced_closeout_test');
```

## 3) Incident Response

### Symptom A: No new snapshots

1. Check `sportmonks-ingestion-healthcheck` run details.
2. Check `sportmonks-enrichment-20m` run details.
3. Manually invoke enrichment function once.
4. Re-check `ingestion_health_snapshots` within 2-5 minutes.

Manual invoke:

```powershell
curl.exe -s -X POST "https://oznmbinzelhcnfiwvapu.functions.supabase.co/sync-sportmonks-data" -H "Content-Type: application/json" -H "x-ingestion-secret: <INGESTION_SHARED_SECRET>" -d "{\"competitionExternalId\":\"2021\",\"season\":2025}"
```

### Symptom B: Alerts not being sent

1. Check `notify-ingestion-alerts` run status in `cron.job_run_details`.
2. Verify function deployed with JWT verification disabled.
3. Verify secrets are set:
   - `INGESTION_SHARED_SECRET`
   - `INGESTION_ALERT_WEBHOOK_URL`
4. Manually invoke `send-ingestion-alerts` and inspect JSON response.

### Symptom C: Unauthorized errors in function calls

1. Confirm cron SQL headers and function secret match exactly.
2. Rotate secret and re-apply scheduling SQL files:
   - `supabase/sql/schedule_daily_ingestion.sql`
   - `supabase/sql/schedule_sportmonks_enrichment.sql`
   - `supabase/sql/ingestion_alerts.sql`

## 4) Secret Rotation Procedure

1. Generate a strong new shared secret.
2. Set secret in Supabase:

```powershell
npx supabase secrets set INGESTION_SHARED_SECRET="<new_secret>" --project-ref oznmbinzelhcnfiwvapu
```

3. Update SQL schedule headers (`x-ingestion-secret`) in:
- `supabase/sql/schedule_daily_ingestion.sql`
- `supabase/sql/schedule_sportmonks_enrichment.sql`
- `supabase/sql/ingestion_alerts.sql`

4. Re-run those SQL files in Supabase SQL Editor.
5. Trigger one manual function call to verify auth.

## 5) Release Anchors

- Milestone tag: `ops-alerting-v1`
- Latest closeout commit: `8733a29`

If a rollback is needed, use the tag as the restore anchor for runbook-aligned ops behavior.
