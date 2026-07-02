param(
  [switch]$CheckOnly,
  [switch]$Force,
  [switch]$CloseClaude
)

. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig

Write-Host ""
Write-Host "Claude zh-CN 更新与重新汉化" -ForegroundColor Cyan
Write-Host ""

$checkCode = Invoke-ClaudeZhPatchTool -Config $config -PatchArgs @("--check-update")

if ($CheckOnly) {
  exit $checkCode
}

if ($CloseClaude) {
  Write-Host "正在关闭 Claude 进程..."
  Stop-ClaudeProcessesForLogin -Config $config
  Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "正在创建更新前备份..."
$backup = New-ClaudeZhUpdateBackup -Config $config -Reason "before-update-and-patch"
Write-Host "  备份路径: $($backup.Path)"
Write-Host "  文件数量: $($backup.FileCount)"

if ($checkCode -eq 0 -and -not $Force) {
  Write-Host "当前已是最新版本，只应用用户设置和本地增量。" -ForegroundColor Green
  $code = Invoke-ClaudeZhPatchTool -Config $config -PatchArgs @("--apply-user-settings")
  if ($code -ne 0) {
    throw "补丁工具 --apply-user-settings 执行失败，退出码: $code"
  }
} else {
  Write-Host "正在更新并重建 Claude zh-CN 便携版，可能会下载官方 MSIX。" -ForegroundColor Yellow
  $code = Invoke-ClaudeZhPatchTool -Config $config -PatchArgs @("--force-download")
  if ($code -ne 0) {
    throw "补丁工具 --force-download 执行失败，退出码: $code"
  }
}

Write-Host ""
Write-Host "正在应用本地增量翻译..."
$results = Apply-ClaudeZhOverrides -Config $config
foreach ($result in $results) {
  Write-Host "  $($result.Changed) override(s): $($result.Override)"
}

Write-Host ""
Write-Host "正在让 en-US 资源入口加载中文资源..."
$shadowResults = Copy-ClaudeZhLocaleShadow -Config $config
foreach ($result in $shadowResults) {
  if ($result.Skipped) {
    Write-Host "  已跳过 $($result.Name): $($result.Reason)"
  } else {
    Write-Host "  已更新 $($result.Name): $($result.Target)"
  }
}

Write-Host ""
Write-Host "正在刷新启动器、快捷方式和语言配置..."
$code = Invoke-ClaudeZhPatchTool -Config $config -PatchArgs @("--apply-user-settings")
if ($code -ne 0) {
  throw "补丁工具 --apply-user-settings 执行失败，退出码: $code"
}

Write-Host ""
Write-Host "正在注入远程 claude.ai 页面汉化..."
& (Join-Path $PSScriptRoot "patch-remote-dom-translation.ps1")
if ($LASTEXITCODE -ne 0) {
  throw "远程页面汉化注入失败，退出码: $LASTEXITCODE"
}

Write-Host ""
Write-Host "正在安装 OAuth 回调桥接器..."
& (Join-Path $PSScriptRoot "install-oauth-callback-bridge.ps1")
if ($LASTEXITCODE -ne 0) {
  throw "OAuth 回调桥接器安装失败，退出码: $LASTEXITCODE"
}

$coverage = Get-ClaudeZhCoverage -Config $config
$protocol = Get-ClaudeProtocolCommand
$report = [pscustomobject]@{
  createdAt = (Get-Date).ToString("s")
  backupPath = $backup.Path
  checkUpdateExitCode = $checkCode
  forced = [bool]$Force
  portableClaudeDir = $config.portableClaudeDir
  coverage = $coverage
  protocol = $protocol
}
$reportPath = Save-ClaudeZhJsonReport -Config $config -Name "latest-update-and-patch.json" -Data $report

Write-Host ""
Write-Host "更新与重新汉化完成。" -ForegroundColor Green
if ($coverage.Exists) {
  Write-Host "包含中文的 zh-CN 文案: $($coverage.Chinese)/$($coverage.Total)"
  Write-Host "估算回退数量: $($coverage.Fallback)"
}
Write-Host "更新报告: $reportPath"
