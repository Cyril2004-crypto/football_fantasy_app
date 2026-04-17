# football_manager_companion_app2

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

## Supabase + Firebase Auth (Option 2)

Use the trusted backend write flow documented in `docs/supabase_option2_setup.md`.

## Release Readiness Checklist

- `flutter analyze` returns no issues.
- `flutter test` passes.
- Firebase is initialized in the target environment (`firebase_options.dart` and platform config files).
- `API_BASE_URL` is set for the target environment.
- Supabase secrets and function URLs are configured (if used).
- Push notification keys are set (`FIREBASE_WEB_VAPID_KEY` for web).
- Crash reporting is configured (Crashlytics enabled in non-debug mobile builds).
- Run smoke flow before release: login -> create/join league -> team status -> transfers.
- Confirm backend health endpoint responds: `GET http://localhost:3000/api/health`.
- Build artifacts generated and validated for target platform.

## Release Governance and Post-Launch Ops

- Release governance: [docs/release_governance.md](docs/release_governance.md)
- Rollback anchors: [docs/rollback_anchors.md](docs/rollback_anchors.md)
- Product analytics plan: [docs/product_analytics_dashboard.md](docs/product_analytics_dashboard.md)

Recommended stable tag for the first governed release: `v1.0.5`

## GitHub Actions CI/CD

Two workflows are configured in `.github/workflows`:

- `ci.yml`: runs on push and pull request to `main`/`develop`.
	- `dart format --set-exit-if-changed .`
	- `flutter analyze`
	- `flutter test`
- `release.yml`: manual release workflow (`workflow_dispatch`) that builds and publishes artifacts.

### Trigger a Release Build

1. Open GitHub repository -> **Actions** -> **Build and Release**.
2. Click **Run workflow**.
3. Set inputs:
	 - `tag`: version tag like `v1.0.1`
	 - `prerelease`: `true` for prerelease, `false` for stable
4. Run workflow and wait for all jobs to complete.

Or trigger automatically by pushing a version tag:

```powershell
git tag v1.0.1
git push origin v1.0.1
```

### Release Artifacts Produced

- Android: `app-release.apk`
- Android store artifact: `app-release.aab`
- Web: `web-build.zip`
- iOS (unsigned): `ios-runner-app.tar.gz`

The workflow publishes a GitHub Release with these artifacts attached.

### Governance and Guardrails

- Secret scanning runs in GitHub Actions via the `Secret Scan` workflow.
- Local pre-commit secret guardrails are available in `.githooks/pre-commit`.
- Critical-flow smoke coverage runs in the nightly E2E workflow.

To enable the local hook path:

```powershell
git config core.hooksPath .githooks
```

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
