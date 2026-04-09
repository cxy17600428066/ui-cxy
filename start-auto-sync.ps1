$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pidFile = Join-Path $repoRoot ".git-auto-sync.pid"
$scriptPath = Join-Path $repoRoot "git-auto-sync.ps1"

if (Test-Path -LiteralPath $pidFile) {
  $existingPid = Get-Content -LiteralPath $pidFile -ErrorAction SilentlyContinue
  if ($existingPid) {
    $process = Get-Process -Id $existingPid -ErrorAction SilentlyContinue
    if ($process) {
      Write-Host "Auto sync is already running. PID=$existingPid"
      exit 0
    }
  }
  Remove-Item -LiteralPath $pidFile -ErrorAction SilentlyContinue
}

Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -WindowStyle Hidden
Write-Host "Auto sync started."
