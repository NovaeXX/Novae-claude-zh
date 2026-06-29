. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig
$bridgeScript = Join-Path $PSScriptRoot "manual-oauth-callback.ps1"

if (-not (Test-Path -LiteralPath $bridgeScript)) {
  throw "Missing callback bridge script: $bridgeScript"
}

Write-Host ""
Write-Host "Install Claude zh-CN OAuth callback bridge" -ForegroundColor Cyan
Write-Host "The bridge receives claude://, writes a redacted diagnostic, then forwards it to Claude zh-CN."
Write-Host ""

$backup = Backup-ClaudeProtocolCommand -Config $config
Write-Host "Current claude:// handler backed up: $backup"

try {
  $configPath = Set-ClaudeZhPortableLocale -Config $config
  Write-Host "Locale config verified: $configPath"
} catch {
  Write-Host "Warning: failed to update locale config. Continuing bridge install. $($_.Exception.Message)" -ForegroundColor Yellow
}

$powershellPath = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$command = '"' + $powershellPath + '" -NoProfile -ExecutionPolicy Bypass -File "' + $bridgeScript + '" -FromProtocol -CallbackUrl "%1"'

Write-Host "Writing HKCU\Software\Classes\claude ..."
$protocolKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("Software\Classes\claude", $true)
if ($null -eq $protocolKey) {
  throw "Failed to create HKCU\Software\Classes\claude"
}
try {
  $protocolKey.SetValue("", "URL:claude", [Microsoft.Win32.RegistryValueKind]::String)
  $protocolKey.SetValue("URL Protocol", "", [Microsoft.Win32.RegistryValueKind]::String)
} finally {
  $protocolKey.Close()
}

Write-Host "Writing HKCU\Software\Classes\claude\shell\open\command ..."
$commandKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("Software\Classes\claude\shell\open\command", $true)
if ($null -eq $commandKey) {
  throw "Failed to create HKCU\Software\Classes\claude\shell\open\command"
}
try {
  $commandKey.SetValue("", $command, [Microsoft.Win32.RegistryValueKind]::String)
} finally {
  $commandKey.Close()
}

$protocol = Get-ClaudeProtocolCommand
Write-Host ""
Write-Host "Current HKCU handler: $($protocol.HKCU)"

if (($protocol.HKCU + "") -notlike "*manual-oauth-callback.ps1*") {
  throw "Callback bridge verification failed."
}

Write-Host "Callback bridge installed." -ForegroundColor Green
Write-Host "Restart Claude zh-CN and click Google login. If the browser triggers claude://, this bridge will forward it to Claude zh-CN."
