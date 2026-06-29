. "$PSScriptRoot\lib\ClaudeZh.Common.ps1"

$config = Get-ClaudeZhConfig

function Pause-ClaudeZhMenu {
  Write-Host ""
  Read-Host "Press Enter to continue"
}

function Start-ClaudeZh {
  Set-ClaudeZhPortableLocale -Config $config | Out-Null
  if (-not (Test-Path -LiteralPath $config.launcherPath)) {
    Write-Host "zh-CN launcher not found. Refreshing user settings first." -ForegroundColor Yellow
    $code = Invoke-FomoPatcher -Config $config -PatchArgs @("--apply-user-settings")
    if ($code -ne 0) {
      throw "Could not create zh-CN launcher. Exit code: $code"
    }
  }

  Start-Process -FilePath "wscript.exe" -ArgumentList "`"$($config.launcherPath)`"" -WindowStyle Hidden
  Write-Host "Claude zh-CN started." -ForegroundColor Green
}

function Confirm-ClaudeZhManagerAction {
  param(
    [Parameter(Mandatory = $true)][string]$Token,
    [Parameter(Mandatory = $true)][string]$Message
  )

  Write-Host ""
  Write-Host $Message -ForegroundColor Yellow
  $answer = Read-Host "Type $Token to continue"
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
  Write-Host "Daily"
  Write-Host " 1. Start Claude zh-CN"
  Write-Host " 2. Diagnose current state"
  Write-Host " 3. Check official update"
  Write-Host " 4. One-click update and re-patch"
  Write-Host ""
  Write-Host "Repair"
  Write-Host " 5. Fix claude:// callback"
  Write-Host " 6. Install OAuth callback bridge"
  Write-Host " 7. Prepare login and start"
  Write-Host " 8. Force en-US resources to Chinese"
  Write-Host " 9. Re-inject remote claude.ai translation"
  Write-Host "10. Manually submit claude:// callback"
  Write-Host ""
  Write-Host "Translation"
  Write-Host "11. Scan untranslated text"
  Write-Host "12. Apply local translation overrides"
  Write-Host "13. Generate coverage report"
  Write-Host ""
  Write-Host "Backup"
  Write-Host "14. Show latest update backup"
  Write-Host "15. Roll back to latest update backup"
  Write-Host ""
  Write-Host " 0. Exit"
  Write-Host ""

  $choice = Read-Host "Select"

  try {
    if ($choice -eq "0") { exit 0 }
    if ($choice -eq "1") { Start-ClaudeZh; Pause-ClaudeZhMenu; continue }
    if ($choice -eq "2") { & (Join-Path $PSScriptRoot "diagnose.ps1"); Pause-ClaudeZhMenu; continue }
    if ($choice -eq "3") { & (Join-Path $PSScriptRoot "update-and-patch.ps1") -CheckOnly; Pause-ClaudeZhMenu; continue }
    if ($choice -eq "4") {
      if (Confirm-ClaudeZhManagerAction -Token "UPDATE" -Message "This will close Claude, update/rebuild the app, re-apply patches, and create a backup.") {
        & (Join-Path $PSScriptRoot "update-and-patch.ps1") -Force -CloseClaude
      } else {
        Write-Host "Update canceled." -ForegroundColor Yellow
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
      Write-Host "If remote page overrides changed, select 9 to re-inject remote translation." -ForegroundColor Yellow
      Pause-ClaudeZhMenu
      continue
    }
    if ($choice -eq "13") { & (Join-Path $PSScriptRoot "scan-untranslated.ps1"); & (Join-Path $PSScriptRoot "diagnose.ps1"); Pause-ClaudeZhMenu; continue }

    if ($choice -eq "14") {
      $latest = Get-ClaudeZhLatestUpdateBackup -Config $config
      if ($null -eq $latest) {
        Write-Host "No update backup found." -ForegroundColor Yellow
      } else {
        Write-Host "Latest backup: $($latest.FullName)" -ForegroundColor Green
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

    Write-Host "Unknown option: $choice" -ForegroundColor Red
    Pause-ClaudeZhMenu
  } catch {
    Write-Host ""
    Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
    Pause-ClaudeZhMenu
  }
}
