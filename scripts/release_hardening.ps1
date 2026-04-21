param(
  [switch]$SkipWebBuild,
  [switch]$SkipApkBuild
)

$ErrorActionPreference = 'Stop'

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)] [string]$Name,
    [Parameter(Mandatory = $true)] [scriptblock]$Action
  )

  Write-Host "`n=== $Name ===" -ForegroundColor Cyan
  & $Action
  Write-Host "PASS: $Name" -ForegroundColor Green
}

Invoke-Step -Name 'Flutter pub get' -Action {
  flutter pub get
}

Invoke-Step -Name 'Static analysis' -Action {
  flutter analyze
}

Invoke-Step -Name 'Unit and widget tests' -Action {
  flutter test
}

if (-not $SkipWebBuild) {
  Invoke-Step -Name 'Web release build' -Action {
    flutter build web --release
  }
}

if (-not $SkipApkBuild) {
  Invoke-Step -Name 'Android APK release build' -Action {
    flutter build apk --release
  }
}

Write-Host "`nRelease hardening checks completed successfully." -ForegroundColor Green
