param(
  [Parameter(Mandatory = $true)][string]$TargetDir,
  [switch]$SkipLocalConfig
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$targetRoot = [System.IO.Path]::GetFullPath($TargetDir)

New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null

function Get-RelativePathCompat {
  param(
    [Parameter(Mandatory = $true)][string]$BasePath,
    [Parameter(Mandatory = $true)][string]$ChildPath
  )

  $baseFullPath = [System.IO.Path]::GetFullPath($BasePath)
  $childFullPath = [System.IO.Path]::GetFullPath($ChildPath)

  if (-not $baseFullPath.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
    $baseFullPath += [System.IO.Path]::DirectorySeparatorChar
  }

  $baseUri = New-Object System.Uri($baseFullPath)
  $childUri = New-Object System.Uri($childFullPath)
  $relativeUri = $baseUri.MakeRelativeUri($childUri).ToString()
  return [System.Uri]::UnescapeDataString($relativeUri).Replace("/", [System.IO.Path]::DirectorySeparatorChar)
}

function Copy-ProjectFile {
  param(
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )

  $destination = Join-Path $targetRoot $RelativePath
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
  Copy-Item -LiteralPath $SourcePath -Destination $destination -Force
}

$gitRoot = (& git -C $projectRoot rev-parse --show-toplevel 2>$null)
$copied = 0

if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
  $projectRelative = (Get-RelativePathCompat -BasePath $gitRoot -ChildPath $projectRoot).Replace("\", "/")
  $files = & git -C $gitRoot ls-files $projectRelative

  foreach ($file in $files) {
    $relative = $file.Substring($projectRelative.Length).TrimStart("/")
    $source = Join-Path $gitRoot ($file -replace "/", "\")
    Copy-ProjectFile -SourcePath $source -RelativePath ($relative -replace "/", "\")
    $copied += 1
  }
} else {
  $excludedDirs = @("\backups\", "\reports\", "\downloads\", "\logs\", "\__pycache__\")
  $excludedFiles = @("paths.local.json", "install-claude-oauth-callback.reg")

  foreach ($file in Get-ChildItem -LiteralPath $projectRoot -Recurse -File -Force) {
    $relative = Get-RelativePathCompat -BasePath $projectRoot -ChildPath $file.FullName
    $relativeWithSlashes = "\" + ($relative -replace "/", "\")
    if ($excludedDirs | Where-Object { $relativeWithSlashes.Contains($_) }) {
      continue
    }
    if ($excludedFiles -contains $file.Name) {
      continue
    }

    Copy-ProjectFile -SourcePath $file.FullName -RelativePath $relative
    $copied += 1
  }
}

if (-not $SkipLocalConfig) {
  $localConfig = Join-Path $projectRoot "config\paths.local.json"
  if (Test-Path -LiteralPath $localConfig) {
    $config = Get-Content -LiteralPath $localConfig -Raw -Encoding UTF8 | ConvertFrom-Json
    $config.projectRoot = $targetRoot
    $config.overridesDir = Join-Path $targetRoot "overrides"
    $config.backupDir = Join-Path $targetRoot "backups"

    $configPath = Join-Path $targetRoot "config\paths.local.json"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $configPath) | Out-Null
    $json = $config | ConvertTo-Json -Depth 20
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($configPath, $json + [Environment]::NewLine, $encoding)
  }
}

New-Item -ItemType Directory -Force -Path (Join-Path $targetRoot "backups"), (Join-Path $targetRoot "reports"), (Join-Path $targetRoot "downloads"), (Join-Path $targetRoot "logs") | Out-Null

Write-Host "Export finished." -ForegroundColor Green
Write-Host "Copied project files: $copied"
Write-Host "Target: $targetRoot"
