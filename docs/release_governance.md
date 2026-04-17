# Release Governance

This document captures the operational hardening steps for release control.

## Stable release tags

- Use a semantic tag such as `v1.0.5` for the first stable post-hardening release.
- Release tags should point to a commit that has passed:
  - `flutter analyze`
  - `flutter test`
  - secret scanning
  - smoke/E2E-style critical-flow validation

## Branch protection policy

Recommended `main` branch rules:

1. Require pull requests before merging.
2. Require at least one approving review.
3. Require status checks to pass before merge:
   - CI
   - Secret Scan
   - Nightly E2E Smoke
4. Dismiss stale approvals when new commits are pushed.
5. Restrict force pushes.
6. Restrict branch deletion.

## Release notes process

For each stable tag:

1. Create a release notes file under `docs/release_notes/`.
2. Summarize feature changes, bug fixes, operational changes, and known limitations.
3. Link the tag in the release notes and GitHub Release body.

## Rollback anchors

Keep the last known good release plus rollback references documented:

- Stable tag: `v1.0.5`
- Example last good operational anchor: `8733a29`

Database/script rollback references:

- `supabase/sql/schedule_daily_ingestion.sql`
- `supabase/sql/schedule_sportmonks_enrichment.sql`
- `supabase/sql/ingestion_alerts.sql`
- `supabase/sql/fd_schema_upgrade.sql`
- `supabase/sql/recompute_gameweek_points.sql`

## Store delivery notes

- Android: prefer signed App Bundle (`.aab`) for Play Console.
- iOS: use a signed archive and TestFlight/App Store pipeline once provisioning is configured.
- Keep unsigned artifacts only for internal validation.
