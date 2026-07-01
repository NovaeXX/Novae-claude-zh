. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig

Write-Host ""
Write-Host "修复 claude:// 登录回调" -ForegroundColor Cyan
Write-Host "这会修改当前 Windows 用户的 claude:// 协议处理器。" -ForegroundColor Yellow
Write-Host "影响：浏览器完成 Claude 登录后会优先回到汉化版启动器。"
Write-Host ""

$backup = Backup-ClaudeProtocolCommand -Config $config
Write-Host "已备份当前回调状态: $backup" -ForegroundColor Green

$code = Invoke-ClaudeZhPatchTool -Config $config -PatchArgs @("--prepare-oauth-login")
if ($code -ne 0) {
  Write-Host "补丁工具 --prepare-oauth-login 执行失败，返回码: $code" -ForegroundColor Yellow
  Write-Host "改用本地回调写入：不重建启动器，只把 claude:// 指向现有汉化启动器。" -ForegroundColor Yellow
  try {
    $command = Set-ClaudeProtocolToLauncher -Config $config
    Write-Host "已写入 HKCU claude:// 回调: $command" -ForegroundColor Green
  } catch {
    Write-Host "当前环境无法写入 HKCU 注册表: $($_.Exception.Message)" -ForegroundColor Red
    $regPath = New-ClaudeZhOAuthCallbackRegFile -Config $config
    Write-Host "请在普通 PowerShell 窗口运行本脚本，或双击导入以下文件:" -ForegroundColor Yellow
    Write-Host "  $regPath" -ForegroundColor Yellow
    throw
  }
}

$protocol = Get-ClaudeProtocolCommand
Write-Host ""
Write-Host "当前 claude:// 回调:"
Write-Host "  HKCU: $($protocol.HKCU)"
Write-Host "  HKCR: $($protocol.HKCR)"

if ((Test-ClaudeZhProtocolCommandContainsPath -Command $protocol.HKCU -ExpectedPath $config.launcherPath) -or
  (Test-ClaudeZhProtocolCommandContainsPath -Command $protocol.HKCR -ExpectedPath $config.launcherPath)) {
  Write-Host "修复完成：回调已指向汉化启动器。" -ForegroundColor Green
} else {
  Write-Host "警告：回调看起来仍未指向汉化启动器，请运行 diagnose.ps1 查看。" -ForegroundColor Yellow
}
