$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if (-not (Test-Path 'windows')) { & "$PSScriptRoot\bootstrap.ps1" }
if (-not (Test-Path 'config.local.json')) { throw 'Missing config.local.json. Copy config.example.json and fill in Supabase values.' }
flutter pub get
flutter analyze
flutter test
flutter build windows --release --dart-define-from-file=config.local.json
Write-Host 'Windows release: build\windows\x64\runner\Release\' -ForegroundColor Green
