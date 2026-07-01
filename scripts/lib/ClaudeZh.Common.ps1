Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ClaudeZhProjectRoot {
  $scriptDir = Split-Path -Parent $PSScriptRoot
  return Split-Path -Parent $scriptDir
}

function Get-ClaudeZhScriptsDir {
  return Split-Path -Parent $PSScriptRoot
}

function Get-ClaudeZhBridgeScriptPath {
  return Join-Path (Get-ClaudeZhScriptsDir) "manual-oauth-callback.ps1"
}

function Test-ClaudeZhProtocolCommandContainsPath {
  param(
    [AllowNull()][string]$Command,
    [Parameter(Mandatory = $true)][string]$ExpectedPath
  )

  if ([string]::IsNullOrWhiteSpace($Command) -or [string]::IsNullOrWhiteSpace($ExpectedPath)) {
    return $false
  }

  $commandText = ($Command + "").Replace("/", "\")
  $expectedText = ([System.IO.Path]::GetFullPath($ExpectedPath)).Replace("/", "\")
  return ($commandText.IndexOf($expectedText, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
}

function New-ClaudeZhLauncherProtocolCommand {
  param([Parameter(Mandatory = $true)]$Config)

  $wscriptPath = Join-Path $env:SystemRoot "System32\wscript.exe"
  return '"' + $wscriptPath + '" "' + $Config.launcherPath + '" "%1"'
}

function New-ClaudeZhBridgeProtocolCommand {
  param([Parameter(Mandatory = $true)][string]$BridgeScript)

  $powershellPath = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
  return '"' + $powershellPath + '" -NoProfile -ExecutionPolicy Bypass -File "' + $BridgeScript + '" -FromProtocol -CallbackUrl "%1"'
}

function Get-ClaudeZhProtocolStatus {
  param(
    [Parameter(Mandatory = $true)]$Config,
    [Parameter(Mandatory = $true)]$Protocol
  )

  $hkcu = $Protocol.HKCU + ""
  $hkcr = $Protocol.HKCR + ""
  $commands = @($hkcu, $hkcr)
  $bridgeScript = Get-ClaudeZhBridgeScriptPath
  $launcherPath = $Config.launcherPath

  if (@($commands | Where-Object { Test-ClaudeZhProtocolCommandContainsPath -Command $_ -ExpectedPath $bridgeScript }).Count -gt 0) {
    return "bridge-current"
  }

  if (@($commands | Where-Object { Test-ClaudeZhProtocolCommandContainsPath -Command $_ -ExpectedPath $launcherPath }).Count -gt 0) {
    return "launcher-current"
  }

  $protocolText = $hkcu + $hkcr
  if ($protocolText -like "*manual-oauth-callback.ps1*") {
    return "bridge-stale"
  }

  if ($protocolText -like "*launch_claude_zh_cn.vbs*") {
    return "launcher-stale"
  }

  return "not-zh-cn"
}

function ConvertTo-ClaudeZhRegString {
  param([AllowNull()][string]$Value)

  $escaped = ($Value + "") -replace '\\', '\\'
  $escaped = $escaped -replace '"', '\"'
  return '"' + $escaped + '"'
}

function New-ClaudeZhOAuthCallbackRegFile {
  param([Parameter(Mandatory = $true)]$Config)

  $root = Get-ClaudeZhProjectRoot
  $regPath = Join-Path $root "config\install-claude-oauth-callback.reg"
  $command = New-ClaudeZhLauncherProtocolCommand -Config $Config

  $lines = @(
    "Windows Registry Editor Version 5.00",
    "",
    "[HKEY_CURRENT_USER\Software\Classes\claude]",
    "@=" + (ConvertTo-ClaudeZhRegString -Value "URL:claude"),
    '"URL Protocol"=""',
    "",
    "[HKEY_CURRENT_USER\Software\Classes\claude\shell\open\command]",
    "@=" + (ConvertTo-ClaudeZhRegString -Value $command)
  )

  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $regPath) | Out-Null
  Set-Content -LiteralPath $regPath -Value $lines -Encoding Unicode
  return $regPath
}

function Get-ClaudeZhConfig {
  $root = Get-ClaudeZhProjectRoot
  $configPath = Join-Path $root "config\paths.local.json"
  if (-not (Test-Path -LiteralPath $configPath)) {
    $examplePath = Join-Path $root "config\paths.example.json"
    throw "缺少本机配置文件: $configPath。请复制 $examplePath 为 paths.local.json，并按本机路径修改。"
  }
  $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  return Normalize-ClaudeZhConfig -Config $config
}

function Normalize-ClaudeZhConfig {
  param([Parameter(Mandatory = $true)]$Config)

  $names = @($Config.PSObject.Properties.Name)
  if (($names -notcontains "projectRoot") -or [string]::IsNullOrWhiteSpace($Config.projectRoot)) {
    $Config | Add-Member -NotePropertyName "projectRoot" -NotePropertyValue (Get-ClaudeZhProjectRoot) -Force
  }
  return $Config
}

function Resolve-ClaudeZhPython {
  param([Parameter(Mandatory = $true)]$Config)

  if ($Config.pythonExe -and (Test-Path -LiteralPath $Config.pythonExe)) {
    return $Config.pythonExe
  }

  $py = Get-Command py -ErrorAction SilentlyContinue
  if ($py) {
    return $py.Source
  }

  $python = Get-Command python -ErrorAction SilentlyContinue
  if ($python) {
    return $python.Source
  }

  throw "未找到 Python。请检查 config/paths.local.json 中的 pythonExe。"
}

function Write-ClaudeJsonNoBom {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)]$Data
  )

  $json = $Data | ConvertTo-Json -Depth 20
  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $encoding)
}

function Invoke-ClaudeZhPatchTool {
  param(
    [Parameter(Mandatory = $true)]$Config,
    [string[]]$PatchArgs = @()
  )

  $patchScript = $Config.patchScript
  if ([string]::IsNullOrWhiteSpace($patchScript) -or -not (Test-Path -LiteralPath $patchScript)) {
    throw "缺少补丁脚本: $patchScript"
  }

  $python = Resolve-ClaudeZhPython -Config $Config
  $args = @()

  if ((Split-Path -Leaf $python) -ieq "py.exe") {
    $args += "-3"
  }

  $args += $patchScript
  $args += "--target-dir"
  $args += $Config.portableClaudeDir
  $args += $PatchArgs

  & $python @args | ForEach-Object { Write-Host $_ }
  $exitCode = $LASTEXITCODE
  return $exitCode
}

function Get-ClaudeProtocolCommand {
  $hkcuPath = "Registry::HKEY_CURRENT_USER\Software\Classes\claude\shell\open\command"
  $hkcrPath = "Registry::HKEY_CLASSES_ROOT\claude\shell\open\command"

  $hkcu = $null
  $hkcr = $null

  try {
    $hkcuKey = Get-Item -LiteralPath $hkcuPath -ErrorAction Stop
    $hkcu = $hkcuKey.GetValue("")
  } catch {}

  try {
    $hkcrKey = Get-Item -LiteralPath $hkcrPath -ErrorAction Stop
    $hkcr = $hkcrKey.GetValue("")
  } catch {}

  [pscustomobject]@{
    HKCU = $hkcu
    HKCR = $hkcr
  }
}

function Set-ClaudeProtocolToLauncher {
  param([Parameter(Mandatory = $true)]$Config)

  if (-not (Test-Path -LiteralPath $Config.launcherPath)) {
    throw "汉化启动器不存在，无法设置回调: $($Config.launcherPath)"
  }

  $command = New-ClaudeZhLauncherProtocolCommand -Config $Config
  return (Set-ClaudeProtocolCommand -Command $command)
}

function Set-ClaudeProtocolToBridge {
  param([Parameter(Mandatory = $true)][string]$BridgeScript)

  if (-not (Test-Path -LiteralPath $BridgeScript)) {
    throw "回调桥接脚本不存在: $BridgeScript"
  }

  $command = New-ClaudeZhBridgeProtocolCommand -BridgeScript $BridgeScript
  return (Set-ClaudeProtocolCommand -Command $command)
}

function Set-ClaudeProtocolCommand {
  param([Parameter(Mandatory = $true)][string]$Command)

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
    $commandKey.SetValue("", $Command, [Microsoft.Win32.RegistryValueKind]::String)
  } finally {
    $commandKey.Close()
  }

  return $Command
}

function Backup-ClaudeProtocolCommand {
  param([Parameter(Mandatory = $true)]$Config)

  $commands = Get-ClaudeProtocolCommand
  $backupRoot = Join-Path $Config.backupDir "oauth-protocol"
  New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $backupPath = Join-Path $backupRoot "claude-protocol-$stamp.json"

  [pscustomobject]@{
    createdAt = (Get-Date).ToString("s")
    hkcu = $commands.HKCU
    hkcr = $commands.HKCR
  } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $backupPath -Encoding UTF8

  return $backupPath
}

function Test-ClaudeZhLauncher {
  param([Parameter(Mandatory = $true)]$Config)

  if (-not (Test-Path -LiteralPath $Config.launcherPath)) {
    return [pscustomobject]@{
      Exists = $false
      UsesPortableExe = $false
      UsesPortableUserData = $false
    }
  }

  $content = Get-Content -LiteralPath $Config.launcherPath -Raw -Encoding UTF8
  [pscustomobject]@{
    Exists = $true
    UsesPortableExe = ($content -like "*$($Config.portableClaudeDir)*")
    UsesPortableUserData = ($content -like "*$($Config.portableUserDataDir)*")
  }
}

function Set-ClaudeZhPortableLocale {
  param([Parameter(Mandatory = $true)]$Config)

  $configPath = Join-Path $Config.portableUserDataDir "config.json"
  New-Item -ItemType Directory -Force -Path $Config.portableUserDataDir | Out-Null

  $data = @{}
  if (Test-Path -LiteralPath $configPath) {
    $raw = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
      $data = ConvertTo-PlainHashtable ($raw | ConvertFrom-Json)
    }
  }

  $data["locale"] = "zh-CN"
  Write-ClaudeJsonNoBom -Path $configPath -Data $data
  return $configPath
}

function Get-ClaudeZhPortableLocale {
  param([Parameter(Mandatory = $true)]$Config)

  $configPath = Join-Path $Config.portableUserDataDir "config.json"
  if (-not (Test-Path -LiteralPath $configPath)) {
    return $null
  }

  $raw = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return $null
  }

  $data = $raw | ConvertFrom-Json
  return $data.locale
}

function Get-ClaudeProcessSummary {
  param([Parameter(Mandatory = $true)]$Config)

  $portableRoot = ($Config.portableClaudeDir + "").ToLowerInvariant()
  $officialRoot = "c:\program files\windowsapps\"
  $items = @()

  foreach ($process in @(Get-Process Claude -ErrorAction SilentlyContinue)) {
    $path = $process.Path
    $kind = "unknown"
    if ($path) {
      $lower = $path.ToLowerInvariant()
      if ($lower.StartsWith($portableRoot)) {
        $kind = "portable"
      } elseif ($lower.StartsWith($officialRoot)) {
        $kind = "official-msix"
      }
    }

    $items += [pscustomobject]@{
      Id = $process.Id
      Kind = $kind
      Path = $path
      MainWindowTitle = $process.MainWindowTitle
    }
  }

  return $items
}

function Stop-ClaudeProcessesForLogin {
  param([Parameter(Mandatory = $true)]$Config)

  $processes = @(Get-Process Claude -ErrorAction SilentlyContinue)
  foreach ($process in $processes) {
    try {
      Stop-Process -Id $process.Id -Force -ErrorAction Stop
      Write-Host "已关闭 Claude 进程: $($process.Id)"
    } catch {
      Write-Host "无法关闭 Claude 进程 $($process.Id): $($_.Exception.Message)" -ForegroundColor Yellow
    }
  }
}

function ConvertTo-PlainHashtable {
  param($InputObject)

  if ($null -eq $InputObject) {
    return $null
  }

  if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string] -and $InputObject -isnot [pscustomobject]) {
    $items = @()
    foreach ($item in $InputObject) {
      $items += ConvertTo-PlainHashtable $item
    }
    return $items
  }

  if ($InputObject -is [pscustomobject]) {
    $hash = @{}
    foreach ($property in $InputObject.PSObject.Properties) {
      $hash[$property.Name] = ConvertTo-PlainHashtable $property.Value
    }
    return $hash
  }

  return $InputObject
}

function Merge-ClaudeZhJsonOverride {
  param(
    [Parameter(Mandatory = $true)][string]$TargetPath,
    [Parameter(Mandatory = $true)][string]$OverridePath
  )

  if (-not (Test-Path -LiteralPath $OverridePath)) {
    return [pscustomobject]@{ Changed = 0; Target = $TargetPath; Override = $OverridePath }
  }

  if (-not (Test-Path -LiteralPath $TargetPath)) {
    throw "目标 JSON 不存在: $TargetPath"
  }

  $overrideRaw = Get-Content -LiteralPath $OverridePath -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($overrideRaw)) {
    return [pscustomobject]@{ Changed = 0; Target = $TargetPath; Override = $OverridePath }
  }

  $overrideObj = $overrideRaw | ConvertFrom-Json
  $override = ConvertTo-PlainHashtable $overrideObj
  if ($override.Count -eq 0) {
    return [pscustomobject]@{ Changed = 0; Target = $TargetPath; Override = $OverridePath }
  }

  $targetObj = Get-Content -LiteralPath $TargetPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $target = ConvertTo-PlainHashtable $targetObj
  $changed = 0

  foreach ($key in $override.Keys) {
    if (-not $target.ContainsKey($key) -or $target[$key] -ne $override[$key]) {
      $target[$key] = $override[$key]
      $changed += 1
    }
  }

  if ($changed -gt 0) {
    Write-ClaudeJsonNoBom -Path $TargetPath -Data $target
  }

  return [pscustomobject]@{ Changed = $changed; Target = $TargetPath; Override = $OverridePath }
}

function Apply-ClaudeZhOverrides {
  param([Parameter(Mandatory = $true)]$Config)

  $frontendTarget = Join-Path $Config.portableClaudeDir "resources\ion-dist\i18n\zh-CN.json"
  $desktopTarget = Join-Path $Config.portableClaudeDir "resources\zh-CN.json"
  $statsigTargets = @(
    (Join-Path $Config.portableClaudeDir "resources\ion-dist\i18n\statsig\zh-CN.json"),
    (Join-Path $Config.portableClaudeDir "resources\statsig\zh-CN.json")
  )

  $results = @()
  $results += Merge-ClaudeZhJsonOverride -TargetPath $frontendTarget -OverridePath (Join-Path $Config.overridesDir "frontend-zh-CN.override.json")
  $results += Merge-ClaudeZhJsonOverride -TargetPath $desktopTarget -OverridePath (Join-Path $Config.overridesDir "desktop-zh-CN.override.json")

  foreach ($statsigTarget in $statsigTargets) {
    if (Test-Path -LiteralPath $statsigTarget) {
      $results += Merge-ClaudeZhJsonOverride -TargetPath $statsigTarget -OverridePath (Join-Path $Config.overridesDir "statsig-zh-CN.override.json")
    }
  }

  return $results
}

function Get-ClaudeZhReportsDir {
  param([Parameter(Mandatory = $true)]$Config)

  $root = Get-ClaudeZhProjectRoot
  if ($Config.PSObject.Properties.Name -contains "projectRoot" -and -not [string]::IsNullOrWhiteSpace($Config.projectRoot)) {
    $root = $Config.projectRoot
  }

  $reportsDir = Join-Path $root "reports"
  New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null
  return $reportsDir
}

function Save-ClaudeZhJsonReport {
  param(
    [Parameter(Mandatory = $true)]$Config,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)]$Data
  )

  $reportsDir = Get-ClaudeZhReportsDir -Config $Config
  $path = Join-Path $reportsDir $Name
  Write-ClaudeJsonNoBom -Path $path -Data $Data
  return $path
}

function New-ClaudeZhUpdateBackup {
  param(
    [Parameter(Mandatory = $true)]$Config,
    [string]$Reason = "manual"
  )

  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $backupRoot = Join-Path $Config.backupDir "updates\$stamp"
  New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

  $relativeFiles = @(
    "Claude.exe",
    "resources\app.asar",
    "resources\en-US.json",
    "resources\zh-CN.json",
    "resources\ion-dist\i18n\en-US.json",
    "resources\ion-dist\i18n\zh-CN.json",
    "resources\ion-dist\i18n\statsig\en-US.json",
    "resources\ion-dist\i18n\statsig\zh-CN.json"
  )

  $copied = @()
  foreach ($relative in $relativeFiles) {
    $source = Join-Path $Config.portableClaudeDir $relative
    if (-not (Test-Path -LiteralPath $source)) {
      continue
    }

    $destination = Join-Path $backupRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
    $item = Get-Item -LiteralPath $source
    $copied += [pscustomobject]@{
      relativePath = $relative
      source = $source
      backup = $destination
      length = $item.Length
      lastWriteTime = $item.LastWriteTime.ToString("s")
    }
  }

  $protocol = Get-ClaudeProtocolCommand
  $manifest = [pscustomobject]@{
    createdAt = (Get-Date).ToString("s")
    reason = $Reason
    portableClaudeDir = $Config.portableClaudeDir
    portableUserDataDir = $Config.portableUserDataDir
    hkcuProtocol = $protocol.HKCU
    hkcrProtocol = $protocol.HKCR
    files = $copied
  }

  Write-ClaudeJsonNoBom -Path (Join-Path $backupRoot "manifest.json") -Data $manifest
  return [pscustomobject]@{
    Path = $backupRoot
    FileCount = $copied.Count
    Manifest = Join-Path $backupRoot "manifest.json"
  }
}

function Get-ClaudeZhLatestUpdateBackup {
  param([Parameter(Mandatory = $true)]$Config)

  $updatesRoot = Join-Path $Config.backupDir "updates"
  if (-not (Test-Path -LiteralPath $updatesRoot)) {
    return $null
  }

  return Get-ChildItem -LiteralPath $updatesRoot -Directory |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
}

function Restore-ClaudeZhUpdateBackup {
  param(
    [Parameter(Mandatory = $true)]$Config,
    [string]$BackupPath
  )

  if ([string]::IsNullOrWhiteSpace($BackupPath)) {
    $latest = Get-ClaudeZhLatestUpdateBackup -Config $Config
    if ($null -eq $latest) {
      throw "没有找到可回滚的更新备份。"
    }
    $BackupPath = $latest.FullName
  }

  $manifestPath = Join-Path $BackupPath "manifest.json"
  if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "备份缺少 manifest.json: $BackupPath"
  }

  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $restored = @()
  foreach ($file in @($manifest.files)) {
    $backupFile = Join-Path $BackupPath $file.relativePath
    $targetFile = Join-Path $Config.portableClaudeDir $file.relativePath
    if (-not (Test-Path -LiteralPath $backupFile)) {
      continue
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetFile) | Out-Null
    Copy-Item -LiteralPath $backupFile -Destination $targetFile -Force
    $restored += [pscustomobject]@{
      relativePath = $file.relativePath
      target = $targetFile
    }
  }

  return [pscustomobject]@{
    BackupPath = $BackupPath
    RestoredCount = $restored.Count
    Restored = $restored
  }
}

function Get-ClaudeZhCoverage {
  param([Parameter(Mandatory = $true)]$Config)

  $frontendTarget = Join-Path $Config.portableClaudeDir "resources\ion-dist\i18n\zh-CN.json"
  if (-not (Test-Path -LiteralPath $frontendTarget)) {
    return [pscustomobject]@{
      Exists = $false
      Total = 0
      Chinese = 0
      Fallback = 0
    }
  }

  $data = Get-Content -LiteralPath $frontendTarget -Raw -Encoding UTF8 | ConvertFrom-Json
  $values = @($data.PSObject.Properties | ForEach-Object { $_.Value } | Where-Object { $_ -is [string] })
  $chinese = @($values | Where-Object { $_ -match "[\u4e00-\u9fff]" }).Count

  [pscustomobject]@{
    Exists = $true
    Total = $values.Count
    Chinese = $chinese
    Fallback = ($values.Count - $chinese)
  }
}

function Copy-ClaudeZhLocaleShadow {
  param(
    [Parameter(Mandatory = $true)]$Config,
    [switch]$NoBackup
  )

  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $backupRoot = Join-Path $Config.backupDir "locale-shadow\$stamp"
  $pairs = @(
    [pscustomobject]@{
      Name = "frontend"
      Source = Join-Path $Config.portableClaudeDir "resources\ion-dist\i18n\zh-CN.json"
      Target = Join-Path $Config.portableClaudeDir "resources\ion-dist\i18n\en-US.json"
    },
    [pscustomobject]@{
      Name = "desktop"
      Source = Join-Path $Config.portableClaudeDir "resources\zh-CN.json"
      Target = Join-Path $Config.portableClaudeDir "resources\en-US.json"
    },
    [pscustomobject]@{
      Name = "statsig"
      Source = Join-Path $Config.portableClaudeDir "resources\ion-dist\i18n\statsig\zh-CN.json"
      Target = Join-Path $Config.portableClaudeDir "resources\ion-dist\i18n\statsig\en-US.json"
    }
  )

  $results = @()
  foreach ($pair in $pairs) {
    if (-not (Test-Path -LiteralPath $pair.Source)) {
      $results += [pscustomobject]@{ Name = $pair.Name; Changed = $false; Skipped = $true; Reason = "missing source"; Target = $pair.Target }
      continue
    }

    if (-not $NoBackup -and (Test-Path -LiteralPath $pair.Target)) {
      $backupPath = Join-Path $backupRoot $pair.Name
      New-Item -ItemType Directory -Force -Path $backupPath | Out-Null
      Copy-Item -LiteralPath $pair.Target -Destination (Join-Path $backupPath (Split-Path -Leaf $pair.Target)) -Force
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $pair.Target) | Out-Null
    Copy-Item -LiteralPath $pair.Source -Destination $pair.Target -Force
    $results += [pscustomobject]@{ Name = $pair.Name; Changed = $true; Skipped = $false; Reason = ""; Target = $pair.Target }
  }

  return $results
}
