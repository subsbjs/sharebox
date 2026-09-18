$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
function Assert-Exit([string]$step) {
  if ($LASTEXITCODE -ne 0) { throw "$step failed (exit $LASTEXITCODE)." }
}
foreach ($name in @('SUPABASE_URL', 'SUPABASE_ANON_KEY', 'ANDROID_KEYSTORE_BASE64', 'ANDROID_KEYSTORE_PASSWORD')) {
  if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
    throw "Missing required build setting: $name"
  }
}
$uri = [Uri]$env:SUPABASE_URL
if ($uri.Scheme -ne 'https' -or $uri.Host -match 'YOUR_PROJECT') { throw 'A real HTTPS Supabase project URL is required.' }
if ($env:SUPABASE_ANON_KEY -match 'YOUR_|^sb_secret_') { throw 'Use a real client publishable/anon key.' }
if ($env:SUPABASE_ANON_KEY.StartsWith('eyJ')) {
  $parts = $env:SUPABASE_ANON_KEY.Split('.')
  if ($parts.Length -ne 3) { throw 'Invalid client JWT.' }
  $payload = $parts[1].Replace('-', '+').Replace('_', '/')
  $payload = $payload.PadRight($payload.Length + ((4 - $payload.Length % 4) % 4), '=')
  $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
  if ($claims.role -ne 'anon') { throw 'Only an anon JWT may be embedded in the app.' }
}
$configPath = Join-Path $root 'config.local.json'
$previousConfig = if (Test-Path $configPath) { [IO.File]::ReadAllBytes($configPath) } else { $null }
$keyPath = Join-Path $env:TEMP ('sharebox-' + [Guid]::NewGuid().ToString('N') + '.jks')
try {
  [IO.File]::WriteAllBytes($keyPath, [Convert]::FromBase64String($env:ANDROID_KEYSTORE_BASE64))
  $env:SHAREBOX_SIGNING_FILE = $keyPath.Replace('\', '/')
  @{
    SUPABASE_URL = $env:SUPABASE_URL
    SUPABASE_ANON_KEY = $env:SUPABASE_ANON_KEY
  } | ConvertTo-Json | Set-Content config.local.json -Encoding utf8

  & "$PSScriptRoot/bootstrap.ps1"
  # Bootstrap uses a generated template. Fail if the template layout changes.
  $gradlePath = Join-Path $root 'android/app/build.gradle.kts'
  $gradle = Get-Content $gradlePath -Raw
  $old = 'signingConfig = signingConfigs.getByName("debug")'
  if (-not $gradle.Contains($old) -or -not $gradle.Contains('    buildTypes {')) {
    throw 'Flutter signing template changed; review Android Gradle configuration.'
  }
  $signing = @'
    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("SHAREBOX_SIGNING_FILE"))
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            keyAlias = "sharebox"
            keyPassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
        }
    }
'@
  $gradle = $gradle.Replace('    buildTypes {', $signing + "`n    buildTypes {")
  $gradle = $gradle.Replace($old, 'signingConfig = signingConfigs.getByName("release")')
  Set-Content $gradlePath $gradle -Encoding utf8

  flutter analyze
  Assert-Exit 'Static analysis'
  flutter test
  Assert-Exit 'Flutter tests'
  flutter build apk --release --dart-define-from-file=config.local.json
  Assert-Exit 'Android release build'
  flutter build windows --release --dart-define-from-file=config.local.json
  Assert-Exit 'Windows release build'

  $release = Join-Path $root 'build/windows/x64/runner/Release'
  if (-not (Test-Path "$release/sharebox.exe")) { throw 'Missing Windows executable.' }
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
  $vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  Assert-Exit 'Visual Studio discovery'
  $crt = Get-ChildItem "$vs/VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT" -Directory | Sort-Object FullName -Descending | Select-Object -First 1
  if (-not $crt) { throw 'Visual C++ runtime not found.' }
  Copy-Item "$($crt.FullName)/*.dll" $release -Force
  foreach ($dll in @('vcruntime140.dll', 'vcruntime140_1.dll', 'msvcp140.dll')) {
    if (-not (Test-Path "$release/$dll")) { throw "Missing runtime: $dll" }
  }
  $dist = Join-Path $root 'dist'
  New-Item $dist -ItemType Directory -Force | Out-Null
  Copy-Item 'build/app/outputs/flutter-apk/app-release.apk' "$dist/ShareBox-Android.apk" -Force
  $iscc = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe'
  if (-not (Test-Path $iscc)) { throw 'Inno Setup 6 is required to create the EXE installer.' }
  & $iscc "/DReleaseDir=$release" "/DOutputPath=$dist" "$root/installer/sharebox.iss"
  Assert-Exit 'Windows installer packaging'
  $outputs = @("$dist/ShareBox-Android.apk", "$dist/ShareBox-Setup-Windows-x64.exe")
  $lines = foreach ($file in $outputs) {
    if (-not (Test-Path $file)) { throw "Missing output: $file" }
    $hash = (Get-FileHash $file -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $(Split-Path $file -Leaf)"
  }
  $lines | Set-Content "$dist/SHA256SUMS.txt" -Encoding ascii
} finally {
  Remove-Item $keyPath -ErrorAction SilentlyContinue
  if ($null -ne $previousConfig) {
    [IO.File]::WriteAllBytes($configPath, [byte[]]$previousConfig)
  } else {
    Remove-Item config.local.json -ErrorAction SilentlyContinue
  }
}
