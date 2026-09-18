$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter was not found in PATH. Install Flutter first, reopen PowerShell, then run this script again.'
}

Write-Host '== ShareBox platform bootstrap ==' -ForegroundColor Cyan
flutter --version
if ($LASTEXITCODE -ne 0) { throw "Flutter version check failed." }

$tmp = Join-Path $env:TEMP ('sharebox_template_' + [Guid]::NewGuid().ToString('N'))
try {
  flutter create --no-pub --platforms=android,windows --org com.sharebox --project-name sharebox $tmp
  if ($LASTEXITCODE -ne 0) { throw "Platform generation failed." }

  foreach ($platform in @('android', 'windows')) {
    if (-not (Test-Path (Join-Path $root $platform))) {
      Copy-Item (Join-Path $tmp $platform) (Join-Path $root $platform) -Recurse
    }
  }

  $manifestPath = Join-Path $root 'android\app\src\main\AndroidManifest.xml'
  $manifest = Get-Content $manifestPath -Raw
  if ($manifest -notmatch 'android.permission.INTERNET') {
    $manifest = $manifest -replace '(<manifest[^>]*>)', "`$1`r`n    <uses-permission android:name=`"android.permission.INTERNET`" />"
  }
  $manifest = $manifest -replace 'android:label="sharebox"', 'android:label="ShareBox"'
  Set-Content $manifestPath $manifest -Encoding UTF8

  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw "Dependency download failed." }

  Write-Host ''
  Write-Host 'Bootstrap complete.' -ForegroundColor Green
  Write-Host 'Next: copy config.example.json to config.local.json and fill in Supabase values.'
  Write-Host 'Then run: .\tooling\run_windows.ps1  OR  .\tooling\run_android.ps1'
}
finally {
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
}
