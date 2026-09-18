$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$release = Join-Path $root 'build/windows/x64/runner/Release'
if (-not (Test-Path "$release/sharebox.exe")) { throw 'Missing Windows executable.' }
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0) { throw 'Visual Studio discovery failed.' }
$crt = Get-ChildItem "$vs/VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT" -Directory | Sort-Object FullName -Descending | Select-Object -First 1
if (-not $crt) { throw 'Visual C++ runtime not found.' }
Copy-Item "$($crt.FullName)/*.dll" $release -Force
foreach ($dll in @('vcruntime140.dll','vcruntime140_1.dll','msvcp140.dll')) {
  if (-not (Test-Path "$release/$dll")) { throw "Missing runtime: $dll" }
}
$dist = Join-Path $root 'dist'
New-Item $dist -ItemType Directory -Force | Out-Null
$iscc = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe'
if (-not (Test-Path $iscc)) { throw 'Inno Setup 6 is required.' }
& $iscc "/DReleaseDir=$release" "/DOutputPath=$dist" "$root/installer/sharebox.iss"
if ($LASTEXITCODE -ne 0) { throw 'Installer packaging failed.' }
Get-FileHash "$dist/ShareBox-Setup-Windows-x64.exe" | Format-List
