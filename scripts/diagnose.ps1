. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig
$launcher = Test-ClaudeZhLauncher -Config $config
$protocol = Get-ClaudeProtocolCommand
$coverage = Get-ClaudeZhCoverage -Config $config
$portableLocale = Get-ClaudeZhPortableLocale -Config $config
$processes = @(Get-ClaudeProcessSummary -Config $config)
$remotePendingPath = Join-Path (Get-ClaudeZhReportsDir -Config $config) "runtime-remote-dom-pending.json"
$remotePendingCount = 0
if (Test-Path -LiteralPath $remotePendingPath) {
  try {
    $remoteRaw = Get-Content -LiteralPath $remotePendingPath -Raw -Encoding UTF8
    if (-not [string]::IsNullOrWhiteSpace($remoteRaw)) {
      $remotePendingCount = @($remoteRaw | ConvertFrom-Json).Count
    }
  } catch {
    $remotePendingCount = -1
  }
}

$protocolText = $protocol.HKCU + $protocol.HKCR
$protocolStatus = "unknown"
if ($protocolText -like "*manual-oauth-callback.ps1*") {
  $protocolStatus = "bridge"
} elseif ($protocolText -like "*launch_claude_zh_cn.vbs*") {
  $protocolStatus = "launcher"
} else {
  $protocolStatus = "not-zh-cn"
}

$report = [pscustomobject]@{
  createdAt = (Get-Date).ToString("s")
  paths = [pscustomobject]@{
    patchToolRoot = $config.patchToolRoot
    patchScript = $config.patchScript
    portableClaudeDir = $config.portableClaudeDir
    portableUserDataDir = $config.portableUserDataDir
    launcherPath = $config.launcherPath
  }
  files = [pscustomobject]@{
    patchScript = Test-Path -LiteralPath $config.patchScript
    claudeExe = Test-Path -LiteralPath (Join-Path $config.portableClaudeDir "Claude.exe")
    launcher = $launcher
  }
  locale = [pscustomobject]@{
    portableConfigLocale = $portableLocale
  }
  processes = $processes
  protocol = [pscustomobject]@{
    hkcu = $protocol.HKCU
    hkcr = $protocol.HKCR
    status = $protocolStatus
  }
  coverage = $coverage
  remoteRuntimePending = [pscustomobject]@{
    path = $remotePendingPath
    count = $remotePendingCount
  }
}
$reportPath = Save-ClaudeZhJsonReport -Config $config -Name "latest-diagnose.json" -Data $report

Write-Host ""
Write-Host "Claude zh-CN Diagnose" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan
Write-Host ""

Write-Host "路径"
Write-Host "  补丁工具目录:     $($config.patchToolRoot)"
Write-Host "  补丁脚本:         $($config.patchScript)"
Write-Host "  便携版 Claude:    $($config.portableClaudeDir)"
Write-Host "  用户数据目录:     $($config.portableUserDataDir)"
Write-Host "  启动器:           $($config.launcherPath)"
Write-Host ""

Write-Host "文件"
Write-Host "  补丁脚本存在:     $(Test-Path -LiteralPath $config.patchScript)"
Write-Host "  Claude.exe:       $(Test-Path -LiteralPath (Join-Path $config.portableClaudeDir 'Claude.exe'))"
Write-Host "  启动器存在:       $($launcher.Exists)"
Write-Host "  启动器程序正确:   $($launcher.UsesPortableExe)"
Write-Host "  启动器数据正确:   $($launcher.UsesPortableUserData)"
Write-Host "  语言配置:         $portableLocale"
Write-Host ""

Write-Host "Claude 进程"
if ($processes.Count -eq 0) {
  Write-Host "  没有 Claude.exe 进程。"
} else {
  foreach ($process in $processes) {
    Write-Host "  [$($process.Kind)] PID=$($process.Id) $($process.Path)"
  }
  if (@($processes | Where-Object { $_.Kind -eq "official-msix" }).Count -gt 0) {
    Write-Host "  警告：官方 MSIX Claude 正在运行，登录回调可能进入错误窗口。" -ForegroundColor Yellow
  }
}
Write-Host ""

Write-Host "claude:// 回调"
Write-Host "  HKCU: $($protocol.HKCU)"
Write-Host "  HKCR: $($protocol.HKCR)"
if ($protocolStatus -eq "bridge") {
  Write-Host "  状态：本地 OAuth 桥接器已安装。" -ForegroundColor Green
} elseif ($protocolStatus -eq "launcher") {
  Write-Host "  状态：zh-CN 启动器已注册。" -ForegroundColor Green
} else {
  Write-Host "  状态：未注册到 zh-CN 启动器或桥接器。" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "中文资源覆盖"
if ($coverage.Exists) {
  Write-Host "  含中文的 zh-CN 文案: $($coverage.Chinese)/$($coverage.Total)"
  Write-Host "  预计英文回退数量:    $($coverage.Fallback)"
} else {
  Write-Host "  未找到前端 zh-CN 资源。" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "远程页面运行时待翻译"
if ($remotePendingCount -eq -1) {
  Write-Host "  文件存在但无法读取: $remotePendingPath" -ForegroundColor Yellow
} else {
  Write-Host "  待处理数量: $remotePendingCount"
  Write-Host "  文件路径:   $remotePendingPath"
}
Write-Host ""

Write-Host "JSON 诊断报告: $reportPath" -ForegroundColor Green
Write-Host ""

Write-Host "补丁工具诊断"
if (Test-Path -LiteralPath $config.patchScript) {
  $code = Invoke-ClaudeZhPatchTool -Config $config -PatchArgs @("--show-user-data")
  if ($code -ne 0) {
    Write-Host "  补丁工具 --show-user-data 退出码: $code" -ForegroundColor Yellow
  }
  $code = Invoke-ClaudeZhPatchTool -Config $config -PatchArgs @("--show-oauth-protocol")
  if ($code -ne 0) {
    Write-Host "  补丁工具 --show-oauth-protocol 退出码: $code" -ForegroundColor Yellow
  }
} else {
  Write-Host "  已跳过：未找到补丁脚本。" -ForegroundColor Yellow
}
