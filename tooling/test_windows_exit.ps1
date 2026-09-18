$ErrorActionPreference = 'Stop'
$app = Resolve-Path 'build/windows/x64/runner/Release/sharebox.exe'
$process = Start-Process -FilePath $app -WorkingDirectory (Split-Path $app) -PassThru
try {
  $deadline = (Get-Date).AddSeconds(45)
  do {
    Start-Sleep -Milliseconds 250
    $process.Refresh()
    if ($process.HasExited) { throw 'ShareBox exited before showing a window' }
  } while ($process.MainWindowHandle -eq 0 -and (Get-Date) -lt $deadline)
  if ($process.MainWindowHandle -eq 0) { throw 'ShareBox did not open a window' }
  if (-not $process.CloseMainWindow()) { throw 'Could not send window close request' }
  if (-not $process.WaitForExit(15000)) { throw 'ShareBox process remained alive after closing its window' }
  if ($process.ExitCode -ne 0) { throw "ShareBox exited abnormally: $($process.ExitCode)" }
  Write-Output 'PASS: closing the Windows window ended the application process.'
} finally {
  if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
}
