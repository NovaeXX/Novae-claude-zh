. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig

Write-Host ""
Write-Host "准备 Claude zh-CN 登录环境" -ForegroundColor Cyan
Write-Host "这会关闭所有 Claude.exe 进程，然后强制汉化版语言为 zh-CN。" -ForegroundColor Yellow
Write-Host "作用：避免官方 MSIX 版接走 Google 登录回调。"
Write-Host ""

Stop-ClaudeProcessesForLogin -Config $config

$configPath = Set-ClaudeZhPortableLocale -Config $config
Write-Host "已设置汉化版语言: $configPath" -ForegroundColor Green

$command = Set-ClaudeProtocolToLauncher -Config $config
Write-Host "已写入 claude:// 回调: $command" -ForegroundColor Green

$protocol = Get-ClaudeProtocolCommand
if (($protocol.HKCU + "") -notlike "*launch_claude_zh_cn.vbs*") {
  throw "claude:// 回调写入后仍未生效。请确认当前 PowerShell 对 HKCU 注册表有写入权限，然后重新运行本脚本。"
}

if (-not (Test-Path -LiteralPath $config.launcherPath)) {
  throw "汉化启动器不存在: $($config.launcherPath)"
}

Start-Process -FilePath "wscript.exe" -ArgumentList "`"$($config.launcherPath)`"" -WindowStyle Hidden
Write-Host "已启动 Claude zh-CN。请在这个窗口完成登录。" -ForegroundColor Green
