param(
  [string]$CallbackUrl,
  [switch]$FromProtocol
)

. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

function Get-RedactedClaudeCallback {
  param([Parameter(Mandatory = $true)][string]$Url)

  if ($Url.Length -le 32) {
    return "claude://..."
  }

  return $Url.Substring(0, [Math]::Min(32, $Url.Length)) + "...[hidden]"
}

$config = Get-ClaudeZhConfig

Write-Host ""
Write-Host "Claude zh-CN 手动提交 OAuth 回调" -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($CallbackUrl)) {
  Write-Host "请粘贴浏览器里的完整 claude:// 回调 URL。" -ForegroundColor Yellow
  Write-Host "不要分享这个 URL，它可能包含一次性登录凭据。"
  $CallbackUrl = Read-Host "claude:// URL"
}

$CallbackUrl = ($CallbackUrl + "").Trim()

if (($CallbackUrl.StartsWith('"') -and $CallbackUrl.EndsWith('"')) -or ($CallbackUrl.StartsWith("'") -and $CallbackUrl.EndsWith("'"))) {
  $CallbackUrl = $CallbackUrl.Substring(1, $CallbackUrl.Length - 2)
}

if ($CallbackUrl -notmatch "^claude://") {
  throw "输入内容不是 claude:// 回调 URL。如果浏览器停在 https://claude.ai 页面，请先点击 Open Claude 或允许打开外部应用。"
}

if (-not (Test-Path -LiteralPath $config.launcherPath)) {
  throw "未找到 Claude zh-CN 启动器: $($config.launcherPath)"
}

try {
  $configPath = Set-ClaudeZhPortableLocale -Config $config
  Write-Host "已确认语言配置: $configPath"
} catch {
  Write-Host "警告：更新语言配置失败，将继续转交回调。$($_.Exception.Message)" -ForegroundColor Yellow
}

$portableProcesses = @(Get-ClaudeProcessSummary -Config $config | Where-Object { $_.Kind -eq "portable" })
if ($portableProcesses.Count -eq 0) {
  Write-Host "未发现便携版 Claude 进程，正在启动 Claude zh-CN..."
  Start-Process -FilePath "wscript.exe" -ArgumentList "`"$($config.launcherPath)`"" -WindowStyle Hidden
  Start-Sleep -Seconds 5
} else {
  Write-Host "已发现便携版 Claude 进程: $($portableProcesses.Id -join ', ')"
}

$backupRoot = Join-Path $config.backupDir "oauth-callback-captures"
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
$capturePath = Join-Path $backupRoot ("callback-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".json")

[pscustomobject]@{
  createdAt = (Get-Date).ToString("s")
  fromProtocol = [bool]$FromProtocol
  redactedCallback = Get-RedactedClaudeCallback -Url $CallbackUrl
  callbackLength = $CallbackUrl.Length
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $capturePath -Encoding UTF8

Write-Host "已保存脱敏回调诊断: $capturePath"
Write-Host "正在把回调转交给 Claude zh-CN 启动器。完整 URL 不会打印。"

$wscriptPath = Join-Path $env:SystemRoot "System32\wscript.exe"
& $wscriptPath $config.launcherPath $CallbackUrl

Start-Sleep -Seconds 3

Write-Host "回调已提交。" -ForegroundColor Green
Write-Host "请查看现有 Claude zh-CN 窗口。如果仍未登录，请运行 diagnose.ps1，并保留脱敏诊断文件。"
