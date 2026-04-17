# Product Analytics and Telemetry Dashboard

This document defines the initial post-launch measurement plan for the app.

## Objectives

1. Measure core user journey completion.
2. Track feature adoption for team, league, transfer, and analytics features.
3. Monitor crash and error rates after release.
4. Identify drop-off points in onboarding and critical flows.

## Proposed events

- `login_success`
- `login_failure`
- `team_created`
- `league_created`
- `league_joined`
- `transfer_started`
- `transfer_completed`
- `points_view_opened`
- `analytics_opened`
- `ops_dashboard_opened`
- `crash_reported`

## Core dashboard widgets

1. Daily active users
2. Login success rate
3. League creation/join conversion
4. Transfer completion rate
5. Analytics screen opens
6. Crash-free sessions
7. Top runtime error reasons
8. Backend health and ingestion lag

## Implementation direction

- Route telemetry to Firebase Analytics or an equivalent events pipeline.
- Use Crashlytics for error and exception visibility.
- Correlate app events with backend health snapshots for release cohort review.
