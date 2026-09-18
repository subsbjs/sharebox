$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if (-not (Test-Path 'android')) { & "$PSScriptRoot\bootstrap.ps1" }
if (-not (Test-Path 'config.local.json')) { throw 'Missing config.local.json. Copy config.example.json and fill in Supabase values.' }
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define-from-file=config.local.json
Write-Host 'Android APK: build\app\outputs\flutter-apk\app-release.apk' -ForegroundColor Green
