. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig
$bridgeScript = Get-ClaudeZhBridgeScriptPath

Write-Host ""
Write-Host "准备 Claude zh-CN 登录环境" -ForegroundColor Cyan
Write-Host "这会关闭所有 Claude.exe 进程、强制 zh-CN，并把 claude:// 指向当前项目的 OAuth 桥接器。" -ForegroundColor Yellow
Write-Host "作用：避免旧窗口或旧工作区接走 Google 登录回调。"
Write-Host ""

Stop-ClaudeProcessesForLogin -Config $config

$configPath = Set-ClaudeZhPortableLocale -Config $config
Write-Host "已设置汉化版语言: $configPath" -ForegroundColor Green

$command = Set-ClaudeProtocolToBridge -BridgeScript $bridgeScript
Write-Host "已写入 claude:// OAuth 桥接器: $command" -ForegroundColor Green

$protocol = Get-ClaudeProtocolCommand
if (-not (Test-ClaudeZhProtocolCommandContainsPath -Command $protocol.HKCU -ExpectedPath $bridgeScript)) {
  throw "claude:// 回调写入后仍未指向当前项目的 OAuth 桥接器。请确认当前 PowerShell 对 HKCU 注册表有写入权限，然后重新运行本脚本。"
}

if (-not (Test-Path -LiteralPath $config.launcherPath)) {
  throw "汉化启动器不存在: $($config.launcherPath)"
}

Start-Process -FilePath "wscript.exe" -ArgumentList "`"$($config.launcherPath)`"" -WindowStyle Hidden
Write-Host "已启动 Claude zh-CN，等待应用完成启动..."
Start-Sleep -Seconds 5

$protocol = Get-ClaudeProtocolCommand
if (-not (Test-ClaudeZhProtocolCommandContainsPath -Command $protocol.HKCU -ExpectedPath $bridgeScript)) {
  Write-Host "检测到启动后 claude:// 被覆盖，正在重新写回 OAuth 桥接器..." -ForegroundColor Yellow
  $command = Set-ClaudeProtocolToBridge -BridgeScript $bridgeScript
  Write-Host "已重新写入 claude:// OAuth 桥接器: $command" -ForegroundColor Green
}

$protocol = Get-ClaudeProtocolCommand
if (-not (Test-ClaudeZhProtocolCommandContainsPath -Command $protocol.HKCU -ExpectedPath $bridgeScript)) {
  throw "启动后回调验证失败：HKCU 没有指向当前项目的 OAuth 桥接器。"
}

Write-Host "已启动 Claude zh-CN。请在这个窗口完成登录。" -ForegroundColor Green
