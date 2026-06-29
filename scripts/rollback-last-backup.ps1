param(
  [string]$BackupPath
)

. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig

Write-Host ""
Write-Host "Claude zh-CN rollback" -ForegroundColor Cyan
Write-Host "This will overwrite current Claude.exe, app.asar, and key locale resources."
Write-Host "It will not delete account data or chat history."
Write-Host ""

if ([string]::IsNullOrWhiteSpace($BackupPath)) {
  $latest = Get-ClaudeZhLatestUpdateBackup -Config $config
  if ($null -eq $latest) {
    throw "No update backup found."
  }
  $BackupPath = $latest.FullName
}

$manifestPath = Join-Path $BackupPath "manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath)) {
  throw "Backup is missing manifest.json: $BackupPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Host "Backup path: $BackupPath"
Write-Host "Created:     $($manifest.createdAt)"
Write-Host "Reason:      $($manifest.reason)"
Write-Host "File count:  $(@($manifest.files).Count)"
Write-Host ""

$answer = Read-Host "Type RESTORE to continue"
if ($answer -ne "RESTORE") {
  Write-Host "Rollback canceled." -ForegroundColor Yellow
  exit 0
}

Stop-ClaudeProcessesForLogin -Config $config
Start-Sleep -Seconds 2

$result = Restore-ClaudeZhUpdateBackup -Config $config -BackupPath $BackupPath

Write-Host ""
Write-Host "Rollback finished. Restored $($result.RestoredCount) file(s)." -ForegroundColor Green
foreach ($item in @($result.Restored)) {
  Write-Host "  $($item.relativePath)"
}

Write-Host ""
Write-Host "Run diagnose again to verify callback and translation resources."
