# Claude zh-CN Manager

Windows 版 Claude Desktop 中文化管理项目。它面向希望在本机长期维护 zh-CN 体验的用户，提供一键部署、本地资源汉化、远程页面 DOM 汉化、OAuth 登录回调桥接、更新重建、诊断和回滚能力。


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
