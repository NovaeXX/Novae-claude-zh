# Claude zh-CN Manager

这是 Claude Desktop Windows 汉化管理器项目，用于在 FOMO 基础汉化之上维护本地增量翻译、远程页面 DOM 汉化、登录回调修复、更新和回滚流程。

## 当前目标

- 保留 FOMO 项目的基础翻译资源和补丁逻辑。
- 在 FOMO 基础上维护本地增量翻译。
- 让官方更新后可以一键重新下载、重建、汉化、注入远程页面翻译。
- 修复 `claude://` 登录回调，避免登录后打开未汉化窗口。
- 采集仍显示英文的文本，生成待翻译清单。
- 更新前备份关键文件，失败时可以回滚。

## 主入口

以下命令默认在本项目根目录执行，也就是包含 `scripts/`、`config/`、`overrides/` 的目录。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\claude-zh-manager.ps1
```

管理器菜单分为四组：

- 日常使用：启动、诊断、检查更新、一键更新并重新汉化。
- 修复工具：登录回调、OAuth 桥接、en-US 影子资源、远程页面汉化注入。
- 翻译维护：扫描待翻译文本、应用本地增量翻译、生成覆盖报告。
- 备份回滚：查看最近备份、回滚到最近一次更新备份。

## 关键路径

路径配置在：

```text
config\paths.local.json
```

首次使用先复制示例配置：

```powershell
Copy-Item .\config\paths.example.json .\config\paths.local.json
notepad .\config\paths.local.json
```

`paths.local.json` 只保存本机路径，不应提交到公开仓库。

## 翻译维护

正式增量翻译放在：

```text
overrides
```

远程主页面、设置页、弹窗里的少量英文，优先加入：

```text
overrides\remote-dom-zh-CN.override.json
```

如果原文经常被链接、加粗、换行拆开，加入片段词库：

```text
overrides\remote-dom-fragments-zh-CN.override.json
```

然后重新运行远程页面汉化注入：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\patch-remote-dom-translation.ps1 -CloseClaude
```

扫描待翻译文本：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\scan-untranslated.ps1
```

生成的报告在：

```text
reports
```

`scan-untranslated.ps1` 是维护者工具，不是普通用户发布版流程。普通用户只需要通过管理器执行更新和重新汉化。

## 发布清单

汉化包清单在：

```text
language-pack\manifest.json
```

它记录当前汉化包版本、目标 Claude 版本、基础翻译来源、增量词库和远程 DOM 补丁能力。

## 迁移为独立目录

如果项目暂时放在其它工作区里，可以导出为独立目录：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\export-standalone-project.ps1 -TargetDir 'D:\Projects\claude_zh'
```

导出脚本会复制公开项目文件，并把本机 `config\paths.local.json` 中的 `projectRoot`、`overridesDir`、`backupDir` 改成目标目录。它不会复制 `backups` 里的账号数据备份、`reports` 的诊断 JSON、下载缓存或 OAuth 注册表导出。

## 更新与回滚

一键更新并重新汉化会先备份关键文件，再执行更新和补丁。

如果更新后不可用，可以从管理器选择“回滚到最近一次更新备份”，或直接运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\rollback-last-backup.ps1
```

回滚会覆盖当前汉化版的 `Claude.exe`、`app.asar` 和关键语言资源，但不会删除账号数据或聊天记录。

## 发布安全

不要提交以下内容：

- `config\paths.local.json`：包含本机路径和用户名。
- `backups\`、`reports\`、`logs\`、`downloads\`：可能包含本机路径、诊断信息或下载缓存。
- 任何完整 `claude://` OAuth 回调 URL：它可能包含一次性登录凭据。

公开发布前建议运行：

```powershell
git status --short
rg -n "C:\\Users|claude://|Bearer|Authorization|api[_-]?key|secret|token" .
```
