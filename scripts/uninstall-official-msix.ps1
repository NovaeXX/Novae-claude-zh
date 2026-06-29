. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRoot = Join-Path $config.backupDir "official-msix-userdata-$stamp"
$officialData = Join-Path $env:LOCALAPPDATA "Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude"

Write-Host ""
Write-Host "临时卸载官方 Claude MSIX" -ForegroundColor Cyan
Write-Host "用途：验证没有官方版干扰时，绿色汉化版能否完成 Google 登录。" -ForegroundColor Yellow
Write-Host ""
Write-Host "会影响："
Write-Host "  1. 当前用户的官方 Claude Desktop 应用会被移除。"
Write-Host "  2. 绿色汉化版目录和配置中的便携用户数据不会删除。"
Write-Host "  3. 如果官方数据目录可读，会先备份到: $backupRoot"
Write-Host ""

$confirm = Read-Host "输入 UNINSTALL-CLAUDE-MSIX 继续"
if ($confirm -ne "UNINSTALL-CLAUDE-MSIX") {
  Write-Host "已取消。"
  exit 0
}

if (Test-Path -LiteralPath $officialData) {
  New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
  Copy-Item -LiteralPath $officialData -Destination $backupRoot -Recurse -Force
  Write-Host "已备份官方用户数据: $backupRoot" -ForegroundColor Green
} else {
  Write-Host "未找到或无法读取官方用户数据目录: $officialData" -ForegroundColor Yellow
}

Get-Process Claude -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

$packages = @(Get-AppxPackage | Where-Object {
  $_.PackageFullName -eq "Claude_1.14271.0.0_x64__pzs8sxrjxfjjc" -or
  $_.PackageFamilyName -eq "Claude_pzs8sxrjxfjjc" -or
  $_.Name -eq "Claude" -or
  $_.InstallLocation -like "*WindowsApps\Claude_*"
})

if ($packages.Count -eq 0) {
  Write-Host "当前用户未找到官方 Claude MSIX 包。" -ForegroundColor Yellow
  exit 0
}

foreach ($package in $packages) {
  Write-Host "卸载: $($package.PackageFullName)" -ForegroundColor Yellow
  Remove-AppxPackage -Package $package.PackageFullName
}

Write-Host ""
Write-Host "官方 Claude MSIX 已卸载。下一步请运行:" -ForegroundColor Green
Write-Host "powershell.exe -NoProfile -ExecutionPolicy Bypass -File '$PSScriptRoot\prepare-login.ps1'"
