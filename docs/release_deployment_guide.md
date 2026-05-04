# Release Deployment Guide

## Prerequisites

- A clean `flutter analyze` run.
- A passing `flutter test` run.
- A successful web release build in `build/web/`.
- Production values for `dart_defines.local.json` or the equivalent release define source.

## Web deployment steps

1. Build the release artifact with the production define file.

   ```powershell
   flutter build web --release --dart-define-from-file=dart_defines.local.json
   ```

2. Copy the contents of `build/web/` to your static hosting target.

3. Ensure the host serves `index.html` as the app entry point.

4. Keep the generated service worker files in place so cached updates work correctly.

5. Confirm the deployed site points to the production backend and Firebase configuration.

## Post-deploy checks

- Open the app and confirm login works.
- Confirm fixture details render real scores rather than `0-0`.
- Open a fixture and verify the play-by-play tab still loads.
- Check the app shell, navigation, and match details on at least one desktop and one mobile viewport.

## Rollback note

- If the release needs to be withdrawn, restore the last known good build from `v1.0.5` or the release commit `dc58292` depending on the failure point.