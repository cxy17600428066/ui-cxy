param(
  [int]$DebounceSeconds = 8
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pidFile = Join-Path $repoRoot ".git-auto-sync.pid"
$logFile = Join-Path $repoRoot ".git-auto-sync.log"

function Write-Log {
  param([string]$Message)
  $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
  Add-Content -LiteralPath $logFile -Value $line
}

Set-Content -LiteralPath $pidFile -Value $PID
Write-Log "Auto sync watcher started."

$script:pending = $false
$script:lastEvent = Get-Date

function Invoke-SyncIfNeeded {
  param(
    [string]$Reason
  )

  Push-Location $repoRoot
  try {
    $status = git status --porcelain
    if ([string]::IsNullOrWhiteSpace(($status | Out-String))) {
      return $false
    }

    Write-Log ("Detected changes ({0}). Running git quick." -f $Reason)
    git quick ("Auto sync " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
    if ($LASTEXITCODE -ne 0) {
      throw "git quick failed with exit code $LASTEXITCODE"
    }
    Write-Log "Auto sync completed."
    return $true
  }
  finally {
    Pop-Location
  }
}

function Mark-Pending {
  param($Sender, $EventArgs)
  $fullPath = ""
  if ($null -ne $EventArgs) {
    if ($EventArgs.PSObject.Properties.Name -contains "FullPath") {
      $fullPath = $EventArgs.FullPath
    }
    elseif ($EventArgs.PSObject.Properties.Name -contains "SourceEventArgs" -and
            $EventArgs.SourceEventArgs.PSObject.Properties.Name -contains "FullPath") {
      $fullPath = $EventArgs.SourceEventArgs.FullPath
    }
  }
  if ($fullPath -like "$repoRoot\.git*") {
    return
  }
  if ($fullPath -like "$repoRoot\.git-auto-sync*") {
    return
  }
  $script:pending = $true
  $script:lastEvent = Get-Date
}

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $repoRoot
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, DirectoryName, LastWrite, CreationTime, Size'
$watcher.EnableRaisingEvents = $true

$changed = Register-ObjectEvent -InputObject $watcher -EventName Changed -Action { Mark-Pending $Sender $EventArgs }
$created = Register-ObjectEvent -InputObject $watcher -EventName Created -Action { Mark-Pending $Sender $EventArgs }
$deleted = Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action { Mark-Pending $Sender $EventArgs }
$renamed = Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action { Mark-Pending $Sender $EventArgs }

try {
  try {
    Invoke-SyncIfNeeded -Reason "startup scan" | Out-Null
  }
  catch {
    Write-Log ("Auto sync failed: " + $_.Exception.Message)
  }

  while ($true) {
    Start-Sleep -Seconds 2
    if (-not $script:pending) {
      continue
    }

    $elapsed = (Get-Date) - $script:lastEvent
    if ($elapsed.TotalSeconds -lt $DebounceSeconds) {
      continue
    }

    try {
      $script:pending = $false
      Invoke-SyncIfNeeded -Reason "file watcher" | Out-Null
    }
    catch {
      Write-Log ("Auto sync failed: " + $_.Exception.Message)
      $script:pending = $true
      $script:lastEvent = Get-Date
    }
  }
}
finally {
  Unregister-Event -SourceIdentifier $changed.Name -ErrorAction SilentlyContinue
  Unregister-Event -SourceIdentifier $created.Name -ErrorAction SilentlyContinue
  Unregister-Event -SourceIdentifier $deleted.Name -ErrorAction SilentlyContinue
  Unregister-Event -SourceIdentifier $renamed.Name -ErrorAction SilentlyContinue
  $watcher.Dispose()
  Remove-Item -LiteralPath $pidFile -ErrorAction SilentlyContinue
  Write-Log "Auto sync watcher stopped."
}
