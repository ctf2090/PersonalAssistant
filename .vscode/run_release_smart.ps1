param(
  [switch]$Watch,
  [int]$PollSeconds = 2
)

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$appRoot = Join-Path $workspaceRoot 'app'
$exePath = Join-Path $appRoot 'build\windows\x64\runner\Release\personal_assistant.exe'
$buildStampPath = Join-Path $PSScriptRoot 'release_build.stamp'

$sourceInputs = @(
  (Join-Path $appRoot 'lib'),
  (Join-Path $appRoot 'windows\runner'),
  (Join-Path $appRoot 'windows\CMakeLists.txt'),
  (Join-Path $appRoot 'pubspec.yaml'),
  (Join-Path $appRoot 'pubspec.lock'),
  (Join-Path $appRoot 'analysis_options.yaml'),
  (Join-Path $appRoot '.metadata')
)

function Get-LatestWriteTimeUtc {
  param([string[]]$Paths)

  $latest = [datetime]::MinValue

  foreach ($path in $Paths) {
    if (-not (Test-Path $path)) {
      continue
    }

    $item = Get-Item $path
    if ($item.PSIsContainer) {
      $files = Get-ChildItem -Path $path -Recurse -File
      foreach ($file in $files) {
        if ($file.LastWriteTimeUtc -gt $latest) {
          $latest = $file.LastWriteTimeUtc
        }
      }
      continue
    }

    if ($item.LastWriteTimeUtc -gt $latest) {
      $latest = $item.LastWriteTimeUtc
    }
  }

  return $latest
}

function Stop-PaProcess {
  $process = Get-Process personal_assistant -ErrorAction SilentlyContinue
  if ($process) {
    $process | Stop-Process -Force
  }
}

function Test-NeedsBuild {
  $needsBuild = -not (Test-Path $exePath) -or -not (Test-Path $buildStampPath)

  if (-not $needsBuild) {
    $buildStampWriteTime = (Get-Item $buildStampPath).LastWriteTimeUtc
    $latestSourceWriteTime = Get-LatestWriteTimeUtc -Paths $sourceInputs
    $needsBuild = $latestSourceWriteTime -gt $buildStampWriteTime
  }

  return $needsBuild
}

function Invoke-BuildAndRun {
  $needsBuild = Test-NeedsBuild

  if ($needsBuild) {
    Write-Host 'Source changes detected. Building Windows release...'
    Stop-PaProcess
    Push-Location $appRoot
    try {
      flutter build windows
      if ($LASTEXITCODE -ne 0) {
        throw "flutter build windows failed with exit code $LASTEXITCODE"
      }
      Set-Content -Path $buildStampPath -Value (Get-Date).ToString('o')
    }
    finally {
      Pop-Location
    }
  }
  else {
    Write-Host 'No source changes detected. Launching existing Windows release exe...'
    Stop-PaProcess
  }

  Start-Process -FilePath $exePath
}

Invoke-BuildAndRun

if (-not $Watch) {
  exit 0
}

$lastSeenWriteTime = Get-LatestWriteTimeUtc -Paths $sourceInputs
Write-Host "Watching Windows release inputs for changes every $PollSeconds second(s)..."

while ($true) {
  Start-Sleep -Seconds $PollSeconds
  $latestSourceWriteTime = Get-LatestWriteTimeUtc -Paths $sourceInputs
  if ($latestSourceWriteTime -le $lastSeenWriteTime) {
    continue
  }

  $lastSeenWriteTime = $latestSourceWriteTime
  try {
    Invoke-BuildAndRun
  }
  catch {
    Write-Host "Auto build failed: $($_.Exception.Message)"
  }
}
