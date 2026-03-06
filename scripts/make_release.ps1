param(
  [switch]$SkipAnalyze,
  [switch]$SkipTest,
  [switch]$SkipBuild,
  [switch]$NoZip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message,
    [Parameter(Mandatory = $true)]
    [scriptblock]$Action
  )

  Write-Host "==> $Message" -ForegroundColor Cyan
  & $Action
}

function Get-TaipeiTimestamp {
  $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById('Taipei Standard Time')
  $taipeiNow = [System.TimeZoneInfo]::ConvertTime((Get-Date), $tz)
  return $taipeiNow.ToString('yyyyMMdd-HHmmss')
}

function Get-TaipeiIsoTimestamp {
  $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById('Taipei Standard Time')
  $taipeiNow = [System.TimeZoneInfo]::ConvertTime((Get-Date), $tz)
  return $taipeiNow.ToString('yyyy-MM-ddTHH:mm:sszzz')
}

function Resolve-CMakePath {
  $command = Get-Command cmake.exe -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $candidates = @(
    'C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe',
    'C:\Program Files\Microsoft Visual Studio\17\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe',
    'C:\Program Files\Microsoft Visual Studio\18\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe',
    'C:\Program Files\Microsoft Visual Studio\17\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
  )

  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      return $candidate
    }
  }

  throw 'Could not find cmake.exe. Install Visual Studio CMake support or add cmake to PATH.'
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$appRoot = Join-Path $repoRoot 'app'
$buildRoot = Join-Path $appRoot 'build\windows\x64'
$runnerReleaseDir = Join-Path $buildRoot 'runner\Release'
$distRoot = Join-Path $repoRoot 'dist'
$timestamp = Get-TaipeiTimestamp
$packageName = "PA-windows-x64-$timestamp"
$packageDir = Join-Path $distRoot $packageName
$zipPath = "$packageDir.zip"
$pubspecPath = Join-Path $appRoot 'pubspec.yaml'
$cmakePath = Resolve-CMakePath

if (-not (Test-Path $distRoot)) {
  New-Item -ItemType Directory -Path $distRoot | Out-Null
}

$gitStatus = git -C $repoRoot status --short
if ($gitStatus) {
  Write-Warning 'Git working tree is not clean. Release will continue with current contents.'
}

Push-Location $appRoot
try {
  if (-not $SkipAnalyze) {
    Invoke-Step -Message 'Running flutter analyze' -Action {
      & flutter analyze
    }
  }

  if (-not $SkipTest) {
    Invoke-Step -Message 'Running flutter test' -Action {
      & flutter test
    }
  }

  if (-not $SkipBuild) {
    Invoke-Step -Message 'Building Windows release with Flutter' -Action {
      & flutter build windows --release
    }
  }

  Invoke-Step -Message 'Bundling workspace JSON files via CMake release_bundle target' -Action {
    & $cmakePath --build $buildRoot --config Release --target release_bundle
  }
} finally {
  Pop-Location
}

if (-not (Test-Path $runnerReleaseDir)) {
  throw "Release output directory not found: $runnerReleaseDir"
}

if (Test-Path $packageDir) {
  Remove-Item -Recurse -Force $packageDir
}
New-Item -ItemType Directory -Path $packageDir | Out-Null

Invoke-Step -Message 'Copying packaged release output to dist/' -Action {
  Copy-Item -Recurse -Force (Join-Path $runnerReleaseDir '*') $packageDir
}

$gitHash = (git -C $repoRoot rev-parse --short HEAD).Trim()
$version = ''
foreach ($line in Get-Content $pubspecPath) {
  if ($line -match '^version:\s*(\S+)\s*$') {
    $version = $Matches[1]
    break
  }
}
if ([string]::IsNullOrWhiteSpace($version)) {
  $version = 'unknown'
}

$versionText = @(
  "package=$packageName"
  "git=$gitHash"
  "version=$version"
  'flutter_mode=release'
  "built_at_taipei=$(Get-TaipeiIsoTimestamp)"
) -join [Environment]::NewLine

Set-Content -Path (Join-Path $packageDir 'VERSION.txt') -Value "$versionText`n" -NoNewline

if (-not $NoZip) {
  if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
  }
  Invoke-Step -Message 'Creating release zip archive' -Action {
    Compress-Archive -Path (Join-Path $packageDir '*') -DestinationPath $zipPath
  }
}

Write-Host ''
Write-Host "Release package: $packageDir" -ForegroundColor Green
if (-not $NoZip) {
  Write-Host "Release archive: $zipPath" -ForegroundColor Green
}
