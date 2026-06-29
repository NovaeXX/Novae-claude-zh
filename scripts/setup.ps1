param(
  [switch]$Force,
  [switch]$InstallCallbackBridge,
  [switch]$RunManager,
  [string]$PythonExe,
  [string]$PatchToolRoot,
  [string]$PatchScript,
  [string]$PortableClaudeDir,
  [string]$PortableUserDataDir,
  [string]$LauncherPath
)

. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

function Read-SetupValue {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [string]$DefaultValue = "",
    [switch]$Required
  )

  while ($true) {
    if ([string]::IsNullOrWhiteSpace($DefaultValue)) {
      $value = Read-Host "$Label"
    } else {
      $value = Read-Host "$Label [$DefaultValue]"
      if ([string]::IsNullOrWhiteSpace($value)) {
        $value = $DefaultValue
      }
    }

    $value = ($value + "").Trim()
    if (-not $Required -or -not [string]::IsNullOrWhiteSpace($value)) {
      return $value
    }

    Write-Host "这个值必填。" -ForegroundColor Yellow
  }
}

function Get-ExistingSetupConfig {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return $null
  }

  try {
    $config = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    return Normalize-ClaudeZhConfig -Config $config
  } catch {
    Write-Host "警告：无法读取现有配置，将创建新配置。$($_.Exception.Message)" -ForegroundColor Yellow
    return $null
  }
}

function Select-SetupDefault {
  param(
    [string]$ExplicitValue,
    $ExistingConfig,
    [string]$PropertyName,
    [string]$Fallback = ""
  )

  if (-not [string]::IsNullOrWhiteSpace($ExplicitValue)) {
    return $ExplicitValue
  }

  if ($null -ne $ExistingConfig -and ($ExistingConfig.PSObject.Properties.Name -contains $PropertyName)) {
    $value = $ExistingConfig.$PropertyName
    if (-not [string]::IsNullOrWhiteSpace($value)) {
      return $value
    }
  }

  return $Fallback
}

function Test-SetupFile {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [string]$Path
  )

  if ([string]::IsNullOrWhiteSpace($Path)) {
    Write-Host "  缺失：$Label 为空。" -ForegroundColor Yellow
    return $false
  }

  $exists = Test-Path -LiteralPath $Path -PathType Leaf
  $color = if ($exists) { "Green" } else { "Yellow" }
  Write-Host "  ${Label}: $exists - $Path" -ForegroundColor $color
  return $exists
}

function Test-SetupDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [string]$Path
  )

  if ([string]::IsNullOrWhiteSpace($Path)) {
    Write-Host "  缺失：$Label 为空。" -ForegroundColor Yellow
    return $false
  }

  $exists = Test-Path -LiteralPath $Path -PathType Container
  $color = if ($exists) { "Green" } else { "Yellow" }
  Write-Host "  ${Label}: $exists - $Path" -ForegroundColor $color
  return $exists
}

$root = Get-ClaudeZhProjectRoot
$configDir = Join-Path $root "config"
$configPath = Join-Path $configDir "paths.local.json"
$existing = Get-ExistingSetupConfig -Path $configPath

Write-Host ""
Write-Host "Claude zh-CN setup" -ForegroundColor Cyan
Write-Host "这个向导会创建本机配置、检查路径并运行诊断。"
Write-Host ""

if ((Test-Path -LiteralPath $configPath) -and -not $Force) {
  Write-Host "已发现现有配置: $configPath" -ForegroundColor Yellow
  Write-Host "如果要覆盖它，请加 -Force。"
  Write-Host ""
} else {
  New-Item -ItemType Directory -Force -Path $configDir | Out-Null
}

$pythonDefault = Select-SetupDefault -ExplicitValue $PythonExe -ExistingConfig $existing -PropertyName "pythonExe" -Fallback "py"
$patchRootDefault = Select-SetupDefault -ExplicitValue $PatchToolRoot -ExistingConfig $existing -PropertyName "patchToolRoot" -Fallback "D:\Tools\claude-zh-patch-tool"
$patchScriptDefault = Select-SetupDefault -ExplicitValue $PatchScript -ExistingConfig $existing -PropertyName "patchScript" -Fallback (Join-Path $patchRootDefault "cc_desktop_zh_cn_windows.py")
$portableClaudeDefault = Select-SetupDefault -ExplicitValue $PortableClaudeDir -ExistingConfig $existing -PropertyName "portableClaudeDir" -Fallback "D:\Apps\ClaudeZhCN\Claude"
$userDataDefault = Select-SetupDefault -ExplicitValue $PortableUserDataDir -ExistingConfig $existing -PropertyName "portableUserDataDir" -Fallback (Join-Path $env:APPDATA "ClaudeZhCN-3p")
$launcherDefault = Select-SetupDefault -ExplicitValue $LauncherPath -ExistingConfig $existing -PropertyName "launcherPath" -Fallback (Join-Path $env:LOCALAPPDATA "ClaudeZhCN\launch_claude_zh_cn.vbs")

if ((-not (Test-Path -LiteralPath $configPath)) -or $Force) {
  Write-Host "创建本机配置" -ForegroundColor Cyan
  $python = Read-SetupValue -Label "Python 可执行文件" -DefaultValue $pythonDefault -Required
  $patchRoot = Read-SetupValue -Label "补丁工具目录" -DefaultValue $patchRootDefault -Required
  $patchScriptPath = Read-SetupValue -Label "补丁脚本路径" -DefaultValue $patchScriptDefault -Required
  $portableClaude = Read-SetupValue -Label "便携版 Claude 目录" -DefaultValue $portableClaudeDefault -Required
  $userData = Read-SetupValue -Label "Claude zh-CN 用户数据目录" -DefaultValue $userDataDefault -Required
  $launcher = Read-SetupValue -Label "Claude zh-CN 启动器路径" -DefaultValue $launcherDefault -Required

  $data = [ordered]@{
    projectRoot = $root
    pythonExe = $python
    patchToolRoot = $patchRoot
    patchScript = $patchScriptPath
    portableClaudeDir = $portableClaude
    portableUserDataDir = $userData
    launcherPath = $launcher
    overridesDir = Join-Path $root "overrides"
    backupDir = Join-Path $root "backups"
  }

  Write-ClaudeJsonNoBom -Path $configPath -Data $data
  Write-Host "配置已写入: $configPath" -ForegroundColor Green
}

$config = Get-ClaudeZhConfig

New-Item -ItemType Directory -Force -Path `
  (Join-Path $root "backups"), `
  (Join-Path $root "reports"), `
  (Join-Path $root "downloads"), `
  (Join-Path $root "logs"), `
  $config.overridesDir, `
  $config.backupDir, `
  $config.portableUserDataDir | Out-Null

Write-Host ""
Write-Host "环境检查" -ForegroundColor Cyan
try {
  $pythonResolved = Resolve-ClaudeZhPython -Config $config
  Write-Host "  Python: True - $pythonResolved" -ForegroundColor Green
} catch {
  Write-Host "  Python: False - $($_.Exception.Message)" -ForegroundColor Yellow
}

Test-SetupDirectory -Label "补丁工具目录" -Path $config.patchToolRoot | Out-Null
Test-SetupFile -Label "补丁脚本" -Path $config.patchScript | Out-Null
Test-SetupDirectory -Label "便携版 Claude 目录" -Path $config.portableClaudeDir | Out-Null
Test-SetupFile -Label "Claude.exe" -Path (Join-Path $config.portableClaudeDir "Claude.exe") | Out-Null
Test-SetupDirectory -Label "用户数据目录" -Path $config.portableUserDataDir | Out-Null
Test-SetupFile -Label "启动器" -Path $config.launcherPath | Out-Null

Write-Host ""
Write-Host "运行诊断" -ForegroundColor Cyan
try {
  & (Join-Path $PSScriptRoot "diagnose.ps1")
} catch {
  Write-Host "诊断完成，但有警告: $($_.Exception.Message)" -ForegroundColor Yellow
}

if ($InstallCallbackBridge) {
  Write-Host ""
  Write-Host "安装 OAuth 回调桥接器" -ForegroundColor Cyan
  & (Join-Path $PSScriptRoot "install-oauth-callback-bridge.ps1")
} else {
  Write-Host ""
  Write-Host "下一步" -ForegroundColor Cyan
  Write-Host "如需安装登录回调桥接器，请运行:"
  Write-Host "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-oauth-callback-bridge.ps1"
}

if ($RunManager) {
  & (Join-Path $PSScriptRoot "claude-zh-manager.ps1")
} else {
  Write-Host ""
  Write-Host "部署向导已完成。启动管理器:" -ForegroundColor Green
  Write-Host "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\claude-zh-manager.ps1"
}
