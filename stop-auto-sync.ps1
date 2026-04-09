$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pidFile = Join-Path $repoRoot ".git-auto-sync.pid"

if (-not (Test-Path -LiteralPath $pidFile)) {
  Write-Host "Auto sync is not running."
  exit 0
}

$existingPid = Get-Content -LiteralPath $pidFile -ErrorAction SilentlyContinue
if ($existingPid) {
  Stop-Process -Id $existingPid -Force -ErrorAction SilentlyContinue
}
Remove-Item -LiteralPath $pidFile -ErrorAction SilentlyContinue
Write-Host "Auto sync stopped."
