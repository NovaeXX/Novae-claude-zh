param(
  [switch]$CloseClaude
)

. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig

Write-Host ""
Write-Host "Force Claude zh-CN resources for en-US locale" -ForegroundColor Cyan
Write-Host "This keeps the UI Chinese even if Claude rewrites config.json locale to en-US."
Write-Host ""

if ($CloseClaude) {
  Stop-ClaudeProcessesForLogin -Config $config
  Start-Sleep -Seconds 2
}

try {
  Write-Host "Applying local translation overrides before shadowing resources..."
  $overrideResults = Apply-ClaudeZhOverrides -Config $config
  foreach ($result in $overrideResults) {
    Write-Host "  $($result.Changed) override(s): $($result.Override)"
  }

  $results = Copy-ClaudeZhLocaleShadow -Config $config
} catch [System.UnauthorizedAccessException] {
  Write-Host "Access denied while writing Claude app resources." -ForegroundColor Red
  Write-Host "Close Claude completely, then run this script from your own PowerShell window." -ForegroundColor Yellow
  Write-Host "Command:" -ForegroundColor Yellow
  Write-Host "powershell.exe -NoProfile -ExecutionPolicy Bypass -File '$PSCommandPath' -CloseClaude" -ForegroundColor Yellow
  throw
}

foreach ($result in $results) {
  if ($result.Skipped) {
    Write-Host "Skipped $($result.Name): $($result.Reason) - $($result.Target)" -ForegroundColor Yellow
  } else {
    Write-Host "Updated $($result.Name): $($result.Target)" -ForegroundColor Green
  }
}

Write-Host ""
Write-Host "Done. Fully close Claude and start Claude zh-CN again." -ForegroundColor Green
