. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig

function Pause-ClaudeZhMenu {
  Write-Host ""
  Read-Host "按 Enter 继续"
}

function Start-ClaudeZh {
  Set-ClaudeZhPortableLocale -Config $config | Out-Null
  if (-not (Test-Path -LiteralPath $config.launcherPath)) {
    Write-Host "未找到 zh-CN 启动器，先刷新用户设置。" -ForegroundColor Yellow
    $code = Invoke-ClaudeZhPatchTool -Config $config -PatchArgs @("--apply-user-settings")
    if ($code -ne 0) {
      throw "无法创建 zh-CN 启动器。退出码: $code"
    }
  }

  Start-Process -FilePath "wscript.exe" -ArgumentList "`"$($config.launcherPath)`"" -WindowStyle Hidden
  Write-Host "Claude zh-CN 已启动。" -ForegroundColor Green
}

function Confirm-ClaudeZhManagerAction {
  param(
    [Parameter(Mandatory = $true)][string]$Token,
    [Parameter(Mandatory = $true)][string]$Message
  )

  Write-Host ""
  Write-Host $Message -ForegroundColor Yellow
  $answer = Read-Host "输入 $Token 继续"
  return ($answer -eq $Token)
}

function Prepare-ClaudeZhLogin {
  & (Join-Path $PSScriptRoot "prepare-login.ps1")
}

while ($true) {
  Clear-Host
  Write-Host ""
  Write-Host "============================================" -ForegroundColor Cyan
  Write-Host " Claude zh-CN Manager" -ForegroundColor Cyan
  Write-Host "============================================" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "日常使用"
  Write-Host " 1. 启动 Claude zh-CN"
  Write-Host " 2. 诊断当前状态"
  Write-Host " 3. 检查官方更新"
  Write-Host " 4. 一键更新并重新汉化"
  Write-Host ""
  Write-Host "维护工具"
  Write-Host " 5. 配置 claude:// 回调"
  Write-Host " 6. 安装 OAuth 回调桥接器"
  Write-Host " 7. 准备登录并启动"
  Write-Host " 8. 强制 en-US 资源加载中文"
  Write-Host " 9. 重新注入远程 claude.ai 页面汉化"
  Write-Host "10. 手动提交 claude:// 回调"
  Write-Host ""
  Write-Host "翻译维护"
  Write-Host "11. 扫描待翻译文本"
  Write-Host "12. 应用本地增量翻译"
  Write-Host "13. 生成覆盖报告"
  Write-Host ""
  Write-Host "备份回滚"
  Write-Host "14. 查看最近更新备份"
  Write-Host "15. 回滚到最近更新备份"
  Write-Host ""
  Write-Host " 0. 退出"
  Write-Host ""

  $choice = Read-Host "请选择"

  try {
    if ($choice -eq "0") { exit 0 }
    if ($choice -eq "1") { Start-ClaudeZh; Pause-ClaudeZhMenu; continue }
    if ($choice -eq "2") { & (Join-Path $PSScriptRoot "diagnose.ps1"); Pause-ClaudeZhMenu; continue }
    if ($choice -eq "3") { & (Join-Path $PSScriptRoot "update-and-patch.ps1") -CheckOnly; Pause-ClaudeZhMenu; continue }
    if ($choice -eq "4") {
      if (Confirm-ClaudeZhManagerAction -Token "UPDATE" -Message "这会关闭 Claude、更新/重建应用、重新应用汉化，并创建备份。") {
        & (Join-Path $PSScriptRoot "update-and-patch.ps1") -Force -CloseClaude
      } else {
        Write-Host "已取消更新。" -ForegroundColor Yellow
      }
      Pause-ClaudeZhMenu
      continue
    }

    if ($choice -eq "5") { & (Join-Path $PSScriptRoot "fix-oauth-callback.ps1"); Pause-ClaudeZhMenu; continue }
    if ($choice -eq "6") { & (Join-Path $PSScriptRoot "install-oauth-callback-bridge.ps1"); Pause-ClaudeZhMenu; continue }
    if ($choice -eq "7") { Prepare-ClaudeZhLogin; Pause-ClaudeZhMenu; continue }
    if ($choice -eq "8") { & (Join-Path $PSScriptRoot "force-zh-cn-resources.ps1") -CloseClaude; Pause-ClaudeZhMenu; continue }
    if ($choice -eq "9") { & (Join-Path $PSScriptRoot "patch-remote-dom-translation.ps1") -CloseClaude; Pause-ClaudeZhMenu; continue }
    if ($choice -eq "10") { & (Join-Path $PSScriptRoot "manual-oauth-callback.ps1"); Pause-ClaudeZhMenu; continue }

    if ($choice -eq "11") { & (Join-Path $PSScriptRoot "scan-untranslated.ps1"); Pause-ClaudeZhMenu; continue }
    if ($choice -eq "12") {
      $results = Apply-ClaudeZhOverrides -Config $config
      foreach ($result in $results) {
        Write-Host "  $($result.Changed) override(s): $($result.Override)"
      }
      Write-Host "如果远程页面翻译有变化，请选择 9 重新注入。" -ForegroundColor Yellow
      Pause-ClaudeZhMenu
      continue
    }
    if ($choice -eq "13") { & (Join-Path $PSScriptRoot "scan-untranslated.ps1"); & (Join-Path $PSScriptRoot "diagnose.ps1"); Pause-ClaudeZhMenu; continue }

    if ($choice -eq "14") {
      $latest = Get-ClaudeZhLatestUpdateBackup -Config $config
      if ($null -eq $latest) {
        Write-Host "没有找到更新备份。" -ForegroundColor Yellow
      } else {
        Write-Host "最近备份: $($latest.FullName)" -ForegroundColor Green
        $manifestPath = Join-Path $latest.FullName "manifest.json"
        if (Test-Path -LiteralPath $manifestPath) {
          $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
          Write-Host "  Created: $($manifest.createdAt)"
          Write-Host "  Reason:  $($manifest.reason)"
          Write-Host "  Files:   $(@($manifest.files).Count)"
        }
      }
      Pause-ClaudeZhMenu
      continue
    }
    if ($choice -eq "15") {
      & (Join-Path $PSScriptRoot "rollback-last-backup.ps1")
      Pause-ClaudeZhMenu
      continue
    }

    Write-Host "未知选项: $choice" -ForegroundColor Red
    Pause-ClaudeZhMenu
  } catch {
    Write-Host ""
    Write-Host "执行失败: $($_.Exception.Message)" -ForegroundColor Red
    Pause-ClaudeZhMenu
  }
}
