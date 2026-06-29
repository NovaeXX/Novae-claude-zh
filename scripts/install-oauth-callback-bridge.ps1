. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig
$bridgeScript = Join-Path $PSScriptRoot "manual-oauth-callback.ps1"

if (-not (Test-Path -LiteralPath $bridgeScript)) {
  throw "Missing callback bridge script: $bridgeScript"
}

Write-Host ""
Write-Host "安装 Claude zh-CN OAuth 回调桥接器" -ForegroundColor Cyan
Write-Host "桥接器会接收 claude:// 回调，写入脱敏诊断，然后转交给 Claude zh-CN。"
Write-Host ""

$backup = Backup-ClaudeProtocolCommand -Config $config
Write-Host "已备份当前 claude:// 处理器: $backup"

try {
  $configPath = Set-ClaudeZhPortableLocale -Config $config
  Write-Host "已确认语言配置: $configPath"
} catch {
  Write-Host "警告：更新语言配置失败，将继续安装桥接器。$($_.Exception.Message)" -ForegroundColor Yellow
}

$powershellPath = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$command = '"' + $powershellPath + '" -NoProfile -ExecutionPolicy Bypass -File "' + $bridgeScript + '" -FromProtocol -CallbackUrl "%1"'

Write-Host "正在写入 HKCU\Software\Classes\claude ..."
$protocolKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("Software\Classes\claude", $true)
if ($null -eq $protocolKey) {
  throw "无法创建 HKCU\Software\Classes\claude"
}
try {
  $protocolKey.SetValue("", "URL:claude", [Microsoft.Win32.RegistryValueKind]::String)
  $protocolKey.SetValue("URL Protocol", "", [Microsoft.Win32.RegistryValueKind]::String)
} finally {
  $protocolKey.Close()
}

Write-Host "正在写入 HKCU\Software\Classes\claude\shell\open\command ..."
$commandKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("Software\Classes\claude\shell\open\command", $true)
if ($null -eq $commandKey) {
  throw "无法创建 HKCU\Software\Classes\claude\shell\open\command"
}
try {
  $commandKey.SetValue("", $command, [Microsoft.Win32.RegistryValueKind]::String)
} finally {
  $commandKey.Close()
}

$protocol = Get-ClaudeProtocolCommand
Write-Host ""
Write-Host "当前 HKCU 处理器: $($protocol.HKCU)"

if (($protocol.HKCU + "") -notlike "*manual-oauth-callback.ps1*") {
  throw "回调桥接器验证失败。"
}

Write-Host "回调桥接器已安装。" -ForegroundColor Green
Write-Host "请重启 Claude zh-CN 并点击 Google 登录。浏览器触发 claude:// 后，桥接器会转交给 Claude zh-CN。"
