param(
  [switch]$NoWrite
)

. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig

function Test-ClaudeZhHasCjk {
  param([AllowNull()][string]$Text)
  return (($Text + "") -match "\p{IsCJKUnifiedIdeographs}")
}

function Test-ClaudeZhLooksEnglish {
  param([AllowNull()][string]$Text)

  $value = ($Text + "").Trim()
  if ($value.Length -lt 2) { return $false }
  if (Test-ClaudeZhHasCjk -Text $value) { return $false }
  if ($value -notmatch "[A-Za-z]") { return $false }
  if ($value -match "^(https?|claude)://") { return $false }
  if ($value -match "^[A-Z0-9_\-./:]{6,}$") { return $false }
  return $true
}

function Read-ClaudeZhJsonMap {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return @{}
  }

  $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return @{}
  }

  return ConvertTo-PlainHashtable ($raw | ConvertFrom-Json)
}

function Get-ClaudeZhLatestLocaleBackup {
  param(
    [Parameter(Mandatory = $true)][string]$Area,
    [Parameter(Mandatory = $true)][string]$FileName
  )

  $root = Join-Path $config.backupDir "locale-shadow"
  if (-not (Test-Path -LiteralPath $root)) {
    return $null
  }

  $candidates = @()
  foreach ($dir in @(Get-ChildItem -LiteralPath $root -Directory)) {
    $path = Join-Path $dir.FullName (Join-Path $Area $FileName)
    if (-not (Test-Path -LiteralPath $path)) {
      continue
    }

    $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    $cjkCount = ([regex]::Matches($raw, "[\u4e00-\u9fff]")).Count
    $candidates += [pscustomobject]@{
      Path = $path
      CjkCount = $cjkCount
      Length = $raw.Length
      LastWriteTime = (Get-Item -LiteralPath $path).LastWriteTime
    }
  }

  if ($candidates.Count -eq 0) {
    return $null
  }

  return ($candidates | Sort-Object CjkCount, LastWriteTime -Descending | Select-Object -First 1).Path
}

function Get-ClaudeZhUntranslatedFromPair {
  param(
    [Parameter(Mandatory = $true)][string]$Area,
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [Parameter(Mandatory = $true)][string]$TargetPath
  )

  $source = Read-ClaudeZhJsonMap -Path $SourcePath
  $target = Read-ClaudeZhJsonMap -Path $TargetPath
  $items = @()

  foreach ($key in $source.Keys) {
    $sourceText = $source[$key]
    if ($sourceText -isnot [string]) {
      continue
    }
    if (-not (Test-ClaudeZhLooksEnglish -Text $sourceText)) {
      continue
    }

    $targetText = $null
    if ($target.ContainsKey($key)) {
      $targetText = $target[$key]
    }

    $sourceHasCjk = Test-ClaudeZhHasCjk -Text $sourceText
    $targetHasCjk = Test-ClaudeZhHasCjk -Text $targetText
    $needsTranslation = $false

    if ($targetText -isnot [string] -or [string]::IsNullOrWhiteSpace($targetText)) {
      $needsTranslation = $true
    } elseif (-not $sourceHasCjk -and $targetText -eq $sourceText) {
      $needsTranslation = $true
    } elseif (-not $targetHasCjk -and (Test-ClaudeZhLooksEnglish -Text $targetText)) {
      $needsTranslation = $true
    }

    if ($needsTranslation) {
      $items += [pscustomobject]@{
        area = $Area
        key = $key
        source = $sourceText
        current = $targetText
        suggested = ""
      }
    }
  }

  return $items
}

function Get-ClaudeZhLogCandidates {
  $roots = @(
    $config.portableUserDataDir,
    (Join-Path $env:APPDATA "Claude"),
    (Join-Path $env:LOCALAPPDATA "Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude")
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -LiteralPath $_) }

  $files = @()
  foreach ($root in $roots) {
    $files += Get-ChildItem -LiteralPath $root -Recurse -File -Include *.log,*.txt -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 8
  }

  return $files | Sort-Object LastWriteTime -Descending | Select-Object -First 20
}

function Protect-ClaudeZhSensitiveText {
  param([AllowNull()][string]$Text)

  $value = $Text + ""
  $value = $value -replace "claude://\S+", "claude://...[hidden]"
  $value = $value -replace "(?i)(code|token|state|session|secret)=([^&\s]+)", '$1=[hidden]'
  $value = $value -replace "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", "[uuid]"
  $value = $value -replace "C:\\Users\\[^\\\s`"]+", "C:\Users\[user]"
  return $value
}

function Get-ClaudeZhLogEnglishSnippets {
  $items = @()
  $seen = @{}
  foreach ($file in @(Get-ClaudeZhLogCandidates)) {
    $matches = Select-String -LiteralPath $file.FullName -Pattern "error|failed|unable|denied|timeout|network|permission|invalid|corrupt|CLAUDE_ZH_PENDING_TRANSLATION" -CaseSensitive:$false -ErrorAction SilentlyContinue |
      Select-Object -First 12

    foreach ($match in $matches) {
      $rawLine = $match.Line.Trim()
      if ($rawLine -match "[\x00-\x08\x0B\x0C\x0E-\x1F]") {
        continue
      }

      if ($rawLine -match "CLAUDE_ZH_PENDING_TRANSLATION") {
        continue
      }

      $missingMatches = [regex]::Matches(
        $rawLine,
        '"code"\s*:\s*"MISSING_TRANSLATION".{0,1000}?"defaultMessage"\s*:\s*"((?:\\.|[^"\\])*)".{0,300}?"id"\s*:\s*"((?:\\.|[^"\\])*)"',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
      )

      if ($missingMatches.Count -gt 0) {
        foreach ($missing in $missingMatches) {
          $text = [System.Text.RegularExpressions.Regex]::Unescape($missing.Groups[1].Value)
          $key = [System.Text.RegularExpressions.Regex]::Unescape($missing.Groups[2].Value)
          if (-not (Test-ClaudeZhLooksEnglish -Text $text)) {
            continue
          }

          $signature = "missing-translation|$key|$text"
          if ($seen.ContainsKey($signature)) {
            continue
          }
          $seen[$signature] = $true

          $items += [pscustomobject]@{
            kind = "missing-translation"
            file = $file.FullName
            lineNumber = $match.LineNumber
            key = $key
            text = $text
            suggested = ""
          }
        }
        continue
      }

      if ($rawLine.TrimStart().StartsWith("{")) {
        continue
      }

      $line = Protect-ClaudeZhSensitiveText -Text $rawLine
      if ($line.Length -gt 240) {
        $line = $line.Substring(0, 240) + "..."
      }
      if (-not (Test-ClaudeZhLooksEnglish -Text $line)) {
        continue
      }

      $signature = "log|$line"
      if ($seen.ContainsKey($signature)) {
        continue
      }
      $seen[$signature] = $true

      $items += [pscustomobject]@{
        kind = "log-snippet"
        file = $file.FullName
        lineNumber = $match.LineNumber
        text = $line
        suggested = ""
      }
    }
  }

  return $items
}

function Get-ClaudeZhRemotePendingFromLogs {
  $items = @()
  $seen = @{}

  foreach ($file in @(Get-ClaudeZhLogCandidates)) {
    $matches = Select-String -LiteralPath $file.FullName -Pattern "CLAUDE_ZH_PENDING_TRANSLATION" -CaseSensitive:$false -ErrorAction SilentlyContinue |
      Select-Object -First 200

    foreach ($match in $matches) {
      $line = Protect-ClaudeZhSensitiveText -Text $match.Line.Trim()
      $markerIndex = $line.IndexOf("CLAUDE_ZH_PENDING_TRANSLATION")
      if ($markerIndex -lt 0) {
        continue
      }

      $text = $line.Substring($markerIndex + "CLAUDE_ZH_PENDING_TRANSLATION".Length)
      $text = $text.Trim(" ", "[", "]", '"', "'", ":", ",")
      $text = $text -replace '\\n.*$', ''
      $text = $text -replace '","logger".*$', ''
      $text = $text -replace '"\}\].*$', ''
      $text = $text.Trim(" ", "[", "]", '"', "'", ":", ",")

      if ($text.Length -gt 500) {
        $text = $text.Substring(0, 500)
      }
      if ([string]::IsNullOrWhiteSpace($text)) {
        continue
      }
      if ($seen.ContainsKey($text)) {
        continue
      }

      $seen[$text] = $true
      $items += [pscustomobject]@{
        source = $text
        from = "log-marker"
        file = $file.FullName
        lineNumber = $match.LineNumber
        suggested = ""
      }
    }
  }

  return $items
}

$frontendSource = Get-ClaudeZhLatestLocaleBackup -Area "frontend" -FileName "en-US.json"
$desktopSource = Get-ClaudeZhLatestLocaleBackup -Area "desktop" -FileName "en-US.json"
$statsigSource = Get-ClaudeZhLatestLocaleBackup -Area "statsig" -FileName "en-US.json"

$frontendTarget = Join-Path $config.portableClaudeDir "resources\ion-dist\i18n\zh-CN.json"
$desktopTarget = Join-Path $config.portableClaudeDir "resources\zh-CN.json"
$statsigTarget = Join-Path $config.portableClaudeDir "resources\ion-dist\i18n\statsig\zh-CN.json"

$localItems = @()
if ($frontendSource) {
  $localItems += Get-ClaudeZhUntranslatedFromPair -Area "frontend" -SourcePath $frontendSource -TargetPath $frontendTarget
}
if ($desktopSource) {
  $localItems += Get-ClaudeZhUntranslatedFromPair -Area "desktop" -SourcePath $desktopSource -TargetPath $desktopTarget
}
if ($statsigSource -and (Test-Path -LiteralPath $statsigTarget)) {
  $localItems += Get-ClaudeZhUntranslatedFromPair -Area "statsig" -SourcePath $statsigSource -TargetPath $statsigTarget
}

$logItems = @(Get-ClaudeZhLogEnglishSnippets)

$remotePendingPath = Join-Path (Get-ClaudeZhReportsDir -Config $config) "runtime-remote-dom-pending.json"
$remoteItems = @()
$remoteSeen = @{}
if (Test-Path -LiteralPath $remotePendingPath) {
  try {
    $remoteRaw = Get-Content -LiteralPath $remotePendingPath -Raw -Encoding UTF8
    if (-not [string]::IsNullOrWhiteSpace($remoteRaw)) {
      foreach ($item in @($remoteRaw | ConvertFrom-Json)) {
        $text = $item + ""
        if (-not $remoteSeen.ContainsKey($text)) {
          $remoteSeen[$text] = $true
          $remoteItems += [pscustomobject]@{
            source = $text
            from = "runtime-file"
            suggested = ""
          }
        }
      }
    }
  } catch {
    Write-Host "Could not read runtime remote pending file: $remotePendingPath" -ForegroundColor Yellow
  }
}

foreach ($item in @(Get-ClaudeZhRemotePendingFromLogs)) {
  $text = $item.source + ""
  if (-not $remoteSeen.ContainsKey($text)) {
    $remoteSeen[$text] = $true
    $remoteItems += $item
  }
}

$pendingLocal = [pscustomobject]@{
  createdAt = (Get-Date).ToString("s")
  note = "Fill suggested values, then move confirmed translations into the matching override file. Pending files are not applied directly."
  sources = [pscustomobject]@{
    frontend = $frontendSource
    desktop = $desktopSource
    statsig = $statsigSource
  }
  items = $localItems
}

$report = [pscustomobject]@{
  createdAt = (Get-Date).ToString("s")
  localResourcePendingCount = $localItems.Count
  remoteRuntimePendingCount = $remoteItems.Count
  logEnglishSnippetCount = $logItems.Count
  localResources = $localItems
  remoteRuntime = $remoteItems
  logs = $logItems
}

Write-Host ""
Write-Host "Claude zh-CN untranslated scan" -ForegroundColor Cyan
Write-Host "Local resource pending: $($localItems.Count)"
Write-Host "Remote runtime pending: $($remoteItems.Count)"
Write-Host "Log English snippets:   $($logItems.Count)"

if ($NoWrite) {
  Write-Host "NoWrite mode: no pending/report files were written." -ForegroundColor Yellow
  exit 0
}

$pendingLocalPath = Join-Path $config.overridesDir "pending-local-resources.json"
Write-ClaudeJsonNoBom -Path $pendingLocalPath -Data $pendingLocal
$reportPath = Save-ClaudeZhJsonReport -Config $config -Name "latest-untranslated.json" -Data $report

Write-Host ""
Write-Host "Pending file: $pendingLocalPath" -ForegroundColor Green
Write-Host "Report file:  $reportPath" -ForegroundColor Green
Write-Host "After confirming translations, update override files and rerun local overrides / remote DOM injection."
