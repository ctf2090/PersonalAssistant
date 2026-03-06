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

$needsBuild = -not (Test-Path $exePath) -or -not (Test-Path $buildStampPath)

if (-not $needsBuild) {
  $buildStampWriteTime = (Get-Item $buildStampPath).LastWriteTimeUtc
  $latestSourceWriteTime = Get-LatestWriteTimeUtc -Paths $sourceInputs
  $needsBuild = $latestSourceWriteTime -gt $buildStampWriteTime
}

if ($needsBuild) {
  Write-Host 'Source changes detected. Building Windows release...'
  Push-Location $appRoot
  try {
    flutter build windows
    if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
    }
    Set-Content -Path $buildStampPath -Value (Get-Date).ToString('o')
  }
  finally {
    Pop-Location
  }
}
else {
  Write-Host 'No source changes detected. Launching existing Windows release exe...'
}

Stop-PaProcess
Start-Process -FilePath $exePath
