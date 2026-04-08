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

$branch = git rev-parse --abbrev-ref HEAD
$upstream = git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($upstream | Out-String))) {
  git push -u origin $branch
}
else {
  git push
}
