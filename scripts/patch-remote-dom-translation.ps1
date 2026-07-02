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
Write-Host "注入远程 claude.ai 页面汉化" -ForegroundColor Cyan
Write-Host "这会把运行时翻译器注入 Claude Desktop 的远程页面 preload。"
Write-Host ""

if ($CloseClaude) {
  Stop-ClaudeProcessesForLogin -Config $config
  Start-Sleep -Seconds 2
  $remaining = @(Get-ClaudeProcessSummary -Config $config)
  if ($remaining.Count -gt 0) {
    Write-Host "警告：仍有 Claude 进程在运行。如果注入失败，请从托盘或任务管理器彻底退出 Claude 后重试。" -ForegroundColor Yellow
    foreach ($process in $remaining) {
      Write-Host "  PID=$($process.Id) kind=$($process.Kind) $($process.Path)" -ForegroundColor Yellow
    }
  }
}

if (-not (Test-Path -LiteralPath $patcher)) {
  throw "缺少远程页面汉化补丁脚本: $patcher"
}

if ((Split-Path -Leaf $python) -ieq "py.exe") {
  & $python -3 $patcher --config $configPath
} else {
  & $python $patcher --config $configPath
}

if ($LASTEXITCODE -ne 0) {
  throw "远程页面汉化注入失败，退出码: $LASTEXITCODE"
}

Write-Host ""
Write-Host "完成。请重新启动 Claude zh-CN，并检查主界面。" -ForegroundColor Green
