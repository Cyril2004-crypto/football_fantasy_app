# Rollback Anchors

## Current anchors

- Stable release tag: `v1.0.5`
- Previous known good closeout anchor: `8733a29`

## If app rollback is needed

1. Roll back to the last stable tag.
2. Revert any release-specific config changes.
3. Confirm backend health and ingestion jobs are green before re-enabling users.

## If database rollback is needed

Review the following SQL/script files before rolling back:

- `supabase/sql/schedule_daily_ingestion.sql`
- `supabase/sql/schedule_sportmonks_enrichment.sql`
- `supabase/sql/ingestion_alerts.sql`
- `supabase/sql/fd_schema_upgrade.sql`
- `supabase/sql/recompute_gameweek_points.sql`
