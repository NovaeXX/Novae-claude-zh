param(
  [switch]$CloseClaude
)

. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig

Write-Host ""
Write-Host "强制 en-US 入口加载中文资源" -ForegroundColor Cyan
Write-Host "即使 Claude 把 config.json 语言改回 en-US，也会继续加载中文资源。"
Write-Host ""

if ($CloseClaude) {
  Stop-ClaudeProcessesForLogin -Config $config
  Start-Sleep -Seconds 2
}

try {
  Write-Host "正在应用本地增量翻译..."
  $overrideResults = Apply-ClaudeZhOverrides -Config $config
  foreach ($result in $overrideResults) {
    Write-Host "  $($result.Changed) override(s): $($result.Override)"
  }

  $results = Copy-ClaudeZhLocaleShadow -Config $config
} catch [System.UnauthorizedAccessException] {
  Write-Host "写入 Claude 应用资源时权限不足。" -ForegroundColor Red
  Write-Host "请彻底关闭 Claude，然后在你自己的 PowerShell 窗口重新运行本脚本。" -ForegroundColor Yellow
  Write-Host "命令:" -ForegroundColor Yellow
  Write-Host "powershell.exe -NoProfile -ExecutionPolicy Bypass -File '$PSCommandPath' -CloseClaude" -ForegroundColor Yellow
  throw
}

foreach ($result in $results) {
  if ($result.Skipped) {
    Write-Host "已跳过 $($result.Name): $($result.Reason) - $($result.Target)" -ForegroundColor Yellow
  } else {
    Write-Host "已更新 $($result.Name): $($result.Target)" -ForegroundColor Green
  }
}

Write-Host ""
Write-Host "完成。请彻底关闭 Claude 后重新启动 Claude zh-CN。" -ForegroundColor Green
