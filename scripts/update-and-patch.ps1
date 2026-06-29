param(
  [switch]$CheckOnly,
  [switch]$Force,
  [switch]$CloseClaude
)

. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig

Write-Host ""
Write-Host "Claude zh-CN update and patch" -ForegroundColor Cyan
Write-Host ""

$checkCode = Invoke-ClaudeZhPatchTool -Config $config -PatchArgs @("--check-update")

if ($CheckOnly) {
  exit $checkCode
}

if ($CloseClaude) {
  Write-Host "Closing Claude processes before patching..."
  Stop-ClaudeProcessesForLogin -Config $config
  Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "Creating pre-update backup..."
$backup = New-ClaudeZhUpdateBackup -Config $config -Reason "before-update-and-patch"
Write-Host "  Backup path: $($backup.Path)"
Write-Host "  File count:  $($backup.FileCount)"

if ($checkCode -eq 0 -and -not $Force) {
  Write-Host "Already up to date. Applying user settings and local overrides only." -ForegroundColor Green
  $code = Invoke-ClaudeZhPatchTool -Config $config -PatchArgs @("--apply-user-settings")
  if ($code -ne 0) {
    throw "Patch tool --apply-user-settings failed. Exit code: $code"
  }
} else {
  Write-Host "Updating and rebuilding zh-CN portable Claude. This may download official MSIX." -ForegroundColor Yellow
  $code = Invoke-ClaudeZhPatchTool -Config $config -PatchArgs @("--force-download")
  if ($code -ne 0) {
    throw "Patch tool --force-download failed. Exit code: $code"
  }
}

Write-Host ""
Write-Host "Applying local translation overrides..."
$results = Apply-ClaudeZhOverrides -Config $config
foreach ($result in $results) {
  Write-Host "  $($result.Changed) override(s): $($result.Override)"
}

Write-Host ""
Write-Host "Shadowing en-US resources with zh-CN resources..."
$shadowResults = Copy-ClaudeZhLocaleShadow -Config $config
foreach ($result in $shadowResults) {
  if ($result.Skipped) {
    Write-Host "  Skipped $($result.Name): $($result.Reason)"
  } else {
    Write-Host "  Updated $($result.Name): $($result.Target)"
  }
}

Write-Host ""
Write-Host "Refreshing launcher, shortcuts, and locale settings..."
$code = Invoke-ClaudeZhPatchTool -Config $config -PatchArgs @("--apply-user-settings")
if ($code -ne 0) {
  throw "Patch tool --apply-user-settings failed. Exit code: $code"
}

Write-Host ""
Write-Host "Injecting remote claude.ai DOM translation..."
& (Join-Path $PSScriptRoot "patch-remote-dom-translation.ps1")
if ($LASTEXITCODE -ne 0) {
  throw "Remote DOM translation patch failed. Exit code: $LASTEXITCODE"
}

Write-Host ""
Write-Host "Installing OAuth callback bridge..."
& (Join-Path $PSScriptRoot "install-oauth-callback-bridge.ps1")
if ($LASTEXITCODE -ne 0) {
  throw "OAuth callback bridge install failed. Exit code: $LASTEXITCODE"
}

$coverage = Get-ClaudeZhCoverage -Config $config
$protocol = Get-ClaudeProtocolCommand
$report = [pscustomobject]@{
  createdAt = (Get-Date).ToString("s")
  backupPath = $backup.Path
  checkUpdateExitCode = $checkCode
  forced = [bool]$Force
  portableClaudeDir = $config.portableClaudeDir
  coverage = $coverage
  protocol = $protocol
}
$reportPath = Save-ClaudeZhJsonReport -Config $config -Name "latest-update-and-patch.json" -Data $report

Write-Host ""
Write-Host "Update and patch finished." -ForegroundColor Green
if ($coverage.Exists) {
  Write-Host "zh-CN strings with Chinese: $($coverage.Chinese)/$($coverage.Total)"
  Write-Host "Estimated fallback count:  $($coverage.Fallback)"
}
Write-Host "Update report: $reportPath"
