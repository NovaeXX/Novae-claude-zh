. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig
$bridgeScript = Get-ClaudeZhBridgeScriptPath

Write-Host ""
Write-Host "修复 Claude zh-CN 登录状态" -ForegroundColor Cyan
Write-Host "这个脚本会执行一个更确定的流程：" -ForegroundColor Yellow
Write-Host "  1. 关闭所有 Claude 进程"
Write-Host "  2. 强制汉化版配置为 zh-CN"
Write-Host "  3. 写入当前项目的 OAuth 回调桥接器"
Write-Host "  4. 启动汉化版"
Write-Host "  5. 启动后再次确认回调没有被旧路径覆盖"
Write-Host ""

$confirm = Read-Host "输入 REPAIR-LOGIN 继续"
if ($confirm -ne "REPAIR-LOGIN") {
  Write-Host "已取消。"
  exit 0
}

Stop-ClaudeProcessesForLogin -Config $config

$configPath = Set-ClaudeZhPortableLocale -Config $config
Write-Host "已设置汉化版语言: $configPath" -ForegroundColor Green

Write-Host "开始写入 claude:// OAuth 桥接器..."
$command = Set-ClaudeProtocolToBridge -BridgeScript $bridgeScript
Write-Host "已写入 claude:// OAuth 桥接器: $command" -ForegroundColor Green

if (-not (Test-Path -LiteralPath $config.launcherPath)) {
  throw "汉化启动器不存在: $($config.launcherPath)"
}

Start-Process -FilePath "wscript.exe" -ArgumentList "`"$($config.launcherPath)`"" -WindowStyle Hidden
Write-Host "已启动 Claude zh-CN，等待应用完成启动..."
Start-Sleep -Seconds 5

$protocol = Get-ClaudeProtocolCommand
Write-Host "当前 HKCU 回调: $($protocol.HKCU)"
if (-not (Test-ClaudeZhProtocolCommandContainsPath -Command $protocol.HKCU -ExpectedPath $bridgeScript)) {
  Write-Host "检测到启动后 claude:// 被覆盖，正在重新写回 OAuth 桥接器..." -ForegroundColor Yellow
  $command = Set-ClaudeProtocolToBridge -BridgeScript $bridgeScript
  Write-Host "已重新写入 claude:// OAuth 桥接器: $command" -ForegroundColor Green
}

$protocol = Get-ClaudeProtocolCommand
Write-Host "最终 HKCU 回调: $($protocol.HKCU)"
if (-not (Test-ClaudeZhProtocolCommandContainsPath -Command $protocol.HKCU -ExpectedPath $bridgeScript)) {
  throw "回调验证失败：HKCU 没有指向当前项目的 OAuth 桥接器。"
}

Write-Host "准备完成。请只在已经打开的 Claude zh-CN 窗口点击 Google 登录。" -ForegroundColor Green
