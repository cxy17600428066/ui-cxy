param(
  [string]$Message
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Message)) {
  $Message = "update $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

git add .

$status = git status --porcelain
if ([string]::IsNullOrWhiteSpace(($status | Out-String))) {
  Write-Host "No changes to commit."
  exit 0
}

git commit -m $Message
git push
