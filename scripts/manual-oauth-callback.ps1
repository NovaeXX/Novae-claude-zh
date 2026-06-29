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
Write-Host "Claude zh-CN manual OAuth callback injection" -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($CallbackUrl)) {
  Write-Host "Paste the full claude:// callback URL from the browser." -ForegroundColor Yellow
  Write-Host "Do not share this URL. It may contain one-time login credentials."
  $CallbackUrl = Read-Host "claude:// URL"
}

$CallbackUrl = ($CallbackUrl + "").Trim()

if (($CallbackUrl.StartsWith('"') -and $CallbackUrl.EndsWith('"')) -or ($CallbackUrl.StartsWith("'") -and $CallbackUrl.EndsWith("'"))) {
  $CallbackUrl = $CallbackUrl.Substring(1, $CallbackUrl.Length - 2)
}

if ($CallbackUrl -notmatch "^claude://") {
  throw "Input is not a claude:// callback URL. If the browser is on an https://claude.ai page, click Open Claude / allow external app first."
}

if (-not (Test-Path -LiteralPath $config.launcherPath)) {
  throw "Claude zh-CN launcher not found: $($config.launcherPath)"
}

try {
  $configPath = Set-ClaudeZhPortableLocale -Config $config
  Write-Host "Locale config verified: $configPath"
} catch {
  Write-Host "Warning: failed to update locale config. Continuing callback forwarding. $($_.Exception.Message)" -ForegroundColor Yellow
}

$portableProcesses = @(Get-ClaudeProcessSummary -Config $config | Where-Object { $_.Kind -eq "portable" })
if ($portableProcesses.Count -eq 0) {
  Write-Host "No portable Claude process found. Starting Claude zh-CN..."
  Start-Process -FilePath "wscript.exe" -ArgumentList "`"$($config.launcherPath)`"" -WindowStyle Hidden
  Start-Sleep -Seconds 5
} else {
  Write-Host "Portable Claude process found: $($portableProcesses.Id -join ', ')"
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

Write-Host "Redacted callback diagnostic saved: $capturePath"
Write-Host "Forwarding callback to Claude zh-CN launcher. Full URL is not printed."

$wscriptPath = Join-Path $env:SystemRoot "System32\wscript.exe"
& $wscriptPath $config.launcherPath $CallbackUrl

Start-Sleep -Seconds 3

Write-Host "Callback submitted." -ForegroundColor Green
Write-Host "Check the existing Claude zh-CN window. If it is still not logged in, run diagnose.ps1 and keep the redacted diagnostic file."
