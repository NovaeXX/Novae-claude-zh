param(
  [switch]$CloseClaude
)

. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig
$root = Get-ClaudeZhProjectRoot
$configPath = Join-Path $root "config\paths.local.json"
$python = Resolve-ClaudeZhPython -Config $config
$patcher = Join-Path $PSScriptRoot "patch-remote-dom-translation.py"

Write-Host ""
Write-Host "Patch remote claude.ai DOM translation" -ForegroundColor Cyan
Write-Host "This injects a runtime translator into Claude Desktop's remote page preload."
Write-Host ""

if ($CloseClaude) {
  Stop-ClaudeProcessesForLogin -Config $config
  Start-Sleep -Seconds 2
  $remaining = @(Get-ClaudeProcessSummary -Config $config)
  if ($remaining.Count -gt 0) {
    Write-Host "Warning: some Claude processes are still running. If patching fails, quit Claude from tray or Task Manager and rerun." -ForegroundColor Yellow
    foreach ($process in $remaining) {
      Write-Host "  PID=$($process.Id) kind=$($process.Kind) $($process.Path)" -ForegroundColor Yellow
    }
  }
}

if (-not (Test-Path -LiteralPath $patcher)) {
  throw "Missing patcher: $patcher"
}

if ((Split-Path -Leaf $python) -ieq "py.exe") {
  & $python -3 $patcher --config $configPath
} else {
  & $python $patcher --config $configPath
}

if ($LASTEXITCODE -ne 0) {
  throw "Remote DOM translation patch failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Done. Start Claude zh-CN again and verify the main page." -ForegroundColor Green
