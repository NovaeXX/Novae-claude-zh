. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig
$launcher = Test-ClaudeZhLauncher -Config $config
$protocol = Get-ClaudeProtocolCommand
$coverage = Get-ClaudeZhCoverage -Config $config
$portableLocale = Get-ClaudeZhPortableLocale -Config $config
$processes = @(Get-ClaudeProcessSummary -Config $config)
$remotePendingPath = Join-Path (Get-ClaudeZhReportsDir -Config $config) "runtime-remote-dom-pending.json"
$remotePendingCount = 0
if (Test-Path -LiteralPath $remotePendingPath) {
  try {
    $remoteRaw = Get-Content -LiteralPath $remotePendingPath -Raw -Encoding UTF8
    if (-not [string]::IsNullOrWhiteSpace($remoteRaw)) {
      $remotePendingCount = @($remoteRaw | ConvertFrom-Json).Count
    }
  } catch {
    $remotePendingCount = -1
  }
}

$protocolText = $protocol.HKCU + $protocol.HKCR
$protocolStatus = "unknown"
if ($protocolText -like "*manual-oauth-callback.ps1*") {
  $protocolStatus = "bridge"
} elseif ($protocolText -like "*launch_claude_zh_cn.vbs*") {
  $protocolStatus = "launcher"
} else {
  $protocolStatus = "not-zh-cn"
}

$report = [pscustomobject]@{
  createdAt = (Get-Date).ToString("s")
  paths = [pscustomobject]@{
    fomoRoot = $config.fomoRoot
    portableClaudeDir = $config.portableClaudeDir
    portableUserDataDir = $config.portableUserDataDir
    launcherPath = $config.launcherPath
  }
  files = [pscustomobject]@{
    fomoPatchScript = Test-Path -LiteralPath $config.fomoPatchScript
    claudeExe = Test-Path -LiteralPath (Join-Path $config.portableClaudeDir "Claude.exe")
    launcher = $launcher
  }
  locale = [pscustomobject]@{
    portableConfigLocale = $portableLocale
  }
  processes = $processes
  protocol = [pscustomobject]@{
    hkcu = $protocol.HKCU
    hkcr = $protocol.HKCR
    status = $protocolStatus
  }
  coverage = $coverage
  remoteRuntimePending = [pscustomobject]@{
    path = $remotePendingPath
    count = $remotePendingCount
  }
}
$reportPath = Save-ClaudeZhJsonReport -Config $config -Name "latest-diagnose.json" -Data $report

Write-Host ""
Write-Host "Claude zh-CN Diagnose" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Paths"
Write-Host "  FOMO root:        $($config.fomoRoot)"
Write-Host "  Portable Claude:  $($config.portableClaudeDir)"
Write-Host "  User data dir:    $($config.portableUserDataDir)"
Write-Host "  Launcher:         $($config.launcherPath)"
Write-Host ""

Write-Host "Files"
Write-Host "  FOMO patcher:     $(Test-Path -LiteralPath $config.fomoPatchScript)"
Write-Host "  Claude.exe:       $(Test-Path -LiteralPath (Join-Path $config.portableClaudeDir 'Claude.exe'))"
Write-Host "  Launcher exists:  $($launcher.Exists)"
Write-Host "  Launcher exe ok:  $($launcher.UsesPortableExe)"
Write-Host "  Launcher data ok: $($launcher.UsesPortableUserData)"
Write-Host "  Locale config:    $portableLocale"
Write-Host ""

Write-Host "Claude processes"
if ($processes.Count -eq 0) {
  Write-Host "  No Claude.exe process."
} else {
  foreach ($process in $processes) {
    Write-Host "  [$($process.Kind)] PID=$($process.Id) $($process.Path)"
  }
  if (@($processes | Where-Object { $_.Kind -eq "official-msix" }).Count -gt 0) {
    Write-Host "  Warning: official MSIX Claude is running. OAuth callback may go to the wrong window." -ForegroundColor Yellow
  }
}
Write-Host ""

Write-Host "claude:// callback"
Write-Host "  HKCU: $($protocol.HKCU)"
Write-Host "  HKCR: $($protocol.HKCR)"
if ($protocolStatus -eq "bridge") {
  Write-Host "  Status: local OAuth bridge is installed." -ForegroundColor Green
} elseif ($protocolStatus -eq "launcher") {
  Write-Host "  Status: zh-CN launcher is registered." -ForegroundColor Green
} else {
  Write-Host "  Status: not registered to zh-CN launcher or bridge." -ForegroundColor Yellow
}
Write-Host ""

Write-Host "Chinese resource coverage"
if ($coverage.Exists) {
  Write-Host "  zh-CN strings with Chinese: $($coverage.Chinese)/$($coverage.Total)"
  Write-Host "  Estimated fallback count:  $($coverage.Fallback)"
} else {
  Write-Host "  Frontend zh-CN resource not found." -ForegroundColor Yellow
}
Write-Host ""

Write-Host "Remote runtime pending translations"
if ($remotePendingCount -eq -1) {
  Write-Host "  File exists but could not be read: $remotePendingPath" -ForegroundColor Yellow
} else {
  Write-Host "  Pending count: $remotePendingCount"
  Write-Host "  File path:     $remotePendingPath"
}
Write-Host ""

Write-Host "JSON report: $reportPath" -ForegroundColor Green
Write-Host ""

Write-Host "FOMO diagnostics"
$code = Invoke-FomoPatcher -Config $config -PatchArgs @("--show-user-data")
if ($code -ne 0) {
  Write-Host "  FOMO --show-user-data exit code: $code" -ForegroundColor Yellow
}
$code = Invoke-FomoPatcher -Config $config -PatchArgs @("--show-oauth-protocol")
if ($code -ne 0) {
  Write-Host "  FOMO --show-oauth-protocol exit code: $code" -ForegroundColor Yellow
}
