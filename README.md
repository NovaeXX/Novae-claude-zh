# Claude zh-CN Manager

Windows 版 Claude Desktop 中文化管理项目。它面向希望在本机长期维护 zh-CN 体验的用户，提供一键部署、本地资源汉化、远程页面 DOM 汉化、OAuth 登录回调桥接、更新重建、诊断和回滚能力。

## 使用方法

### 1. 一键部署

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1
```

部署向导会完成：

- 创建本机配置 `config\paths.local.json`
- 创建 `backups/`、`reports/`、`downloads/`、`logs/`
- 检查 Python、补丁脚本、Claude 目录、启动器和用户数据目录
- 创建或刷新桌面与开始菜单里的 `Claude zh-CN` 快捷方式
- 运行诊断，告诉你当前环境是否可以继续

### 2. Google 登录用户继续执行

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1 -InstallCallbackBridge
```

如果你使用 Google 登录，推荐在一键部署后继续执行这条命令。它会安装登录回调桥接器，把浏览器完成登录后的 `claude://` 回调交给当前项目配置的 Claude zh-CN。

### 3. 首次登录前准备

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\prepare-login.ps1
```

这条命令不是每天启动都必须执行，但首次 Google 登录前强烈推荐执行。它会关闭当前 Claude 进程、确认 zh-CN 配置、写入当前项目的 OAuth 回调桥接器，并启动 Claude zh-CN。它只做启动前和启动后的一次性校验，不会在登录期间常驻守护。

### 4. 日常启动

部署完成后，如果桌面或开始菜单里已经出现 `Claude zh-CN`，后续可以直接双击它启动应用。它会使用项目配置里的汉化版 Claude 和独立用户数据目录。

如果没有看到桌面快捷方式，可以继续用管理器启动：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\claude-zh-manager.ps1
```

管理器里可以启动 Claude zh-CN、检查状态、更新并重新汉化、重新注入远程页面汉化和回滚备份。

如需跳过快捷方式创建，可以运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1 -SkipShortcuts
```

## 推荐流程

首次使用：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1 -InstallCallbackBridge
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\prepare-login.ps1
```

日常使用：

1. 直接双击桌面或开始菜单里的 `Claude zh-CN`
2. 如需检查状态或更新，打开管理器：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\claude-zh-manager.ps1
```

## 项目能力

Claude Desktop 的界面文字来自多个地方：本地资源文件、桌面壳、远程 `claude.ai` 页面，以及账号状态相关的动态文本。本项目把这些来源收敛到一套可维护流程里。

核心能力：

- 本地 `zh-CN` 资源覆盖与增量维护
- 远程 `claude.ai` 页面运行时 DOM 汉化
- 当前用户 `claude://` OAuth 登录回调桥接
- 官方更新后的重新构建与重新汉化
- 本机诊断报告与最近备份回滚
- 待翻译文本扫描与 `overrides/` 增量维护

## 配置说明

本机配置文件：

```text
config\paths.local.json
```

这个文件不会提交到 GitHub。它保存你的本机路径，包括：

- `projectRoot`：项目目录
- `pythonExe`：Python 路径
- `patchToolRoot`：补丁工具目录
- `patchScript`：补丁脚本路径
- `portableClaudeDir`：便携版 Claude 目录
- `portableUserDataDir`：Claude zh-CN 用户数据目录
- `launcherPath`：Claude zh-CN 启动器路径
- `overridesDir`：本地增量翻译目录
- `backupDir`：备份目录

示例配置：

```text
config\paths.example.json
```

## 翻译维护

正式翻译增量放在：

```text
overrides/
```

常用文件：

- `frontend-zh-CN.override.json`：前端资源增量
- `desktop-zh-CN.override.json`：桌面外壳资源增量
- `statsig-zh-CN.override.json`：功能开关相关文案
- `remote-dom-zh-CN.override.json`：远程页面精确文本
- `remote-dom-fragments-zh-CN.override.json`：远程页面片段文本

扫描待翻译文本：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\scan-untranslated.ps1
```

## 项目结构

```text
config/        本机配置示例
docs/          产品规格和实现计划
language-pack/ 汉化包清单
overrides/     本地增量翻译
reports/       本机诊断输出，不提交
backups/       本机备份，不提交
scripts/       管理、部署、诊断、更新、回滚脚本
```
