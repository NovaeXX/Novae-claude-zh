# Claude zh-CN Manager

Windows 版 Claude Desktop 中文化管理项目。它提供本地资源汉化、远程页面汉化、登录回调修复、更新后重新汉化和回滚能力。

## 使用方法

### 1. 克隆项目

```powershell
cd D:\Projects
git clone https://github.com/NovaeXX/Novae-claude-zh.git
cd Novae-claude-zh
```

也可以把 `D:\Projects` 换成你自己的项目目录。

### 2. 一键部署

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1
```

部署向导会完成：

- 创建本机配置 `config\paths.local.json`
- 创建 `backups/`、`reports/`、`downloads/`、`logs/`
- 检查 Python、补丁脚本、Claude 目录、启动器和用户数据目录
- 运行诊断，告诉你当前缺什么

如果你希望部署时同时修复登录回调：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1 -InstallCallbackBridge
```

这会写入当前 Windows 用户的 `claude://` 协议处理器。作用是：浏览器登录 Claude 后，回到当前汉化版窗口。

### 3. 启动管理器

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\claude-zh-manager.ps1
```

管理器里可以执行：

- 启动 Claude zh-CN
- 诊断当前状态
- 检查官方更新
- 一键更新并重新汉化
- 修复登录回调
- 重新注入远程页面汉化
- 扫描待翻译文本
- 回滚到最近备份

### 4. 常用命令

诊断当前状态：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\diagnose.ps1
```

安装登录回调桥接器：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-oauth-callback-bridge.ps1
```

登录后又打开新登录窗口时：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\prepare-login.ps1
```

重新注入远程页面汉化：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\patch-remote-dom-translation.ps1 -CloseClaude
```

回滚到最近一次备份：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\rollback-last-backup.ps1
```

## 项目解决什么问题

Claude Desktop 的文字来源不只在本地语言文件里。登录后的主界面、设置页、弹窗等内容有一部分来自远程 `claude.ai` 页面，所以只替换本地 JSON 往往不够。

本项目主要解决：

- 登录后回到英文窗口
- 官方更新后汉化失效
- 设置页、弹窗、远程页面仍有英文
- 新增英文文案难以持续维护
- 更新失败后缺少回滚入口

## 推荐流程

首次使用：

1. 运行 `scripts\setup.ps1`
2. 按提示填写或确认本机路径
3. 运行诊断
4. 安装登录回调桥接器
5. 启动 Claude zh-CN
6. 浏览器登录后确认回到汉化窗口

日常使用：

1. 打开管理器
2. 启动 Claude zh-CN
3. 如果官方更新，执行“一键更新并重新汉化”
4. 如果出现英文，先诊断，再补充翻译或重新注入远程页面汉化

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
- `portableUserDataDir`：汉化版用户数据目录
- `launcherPath`：Claude zh-CN 启动器路径
- `overridesDir`：本地增量翻译目录
- `backupDir`：备份目录

示例配置：

```text
config\paths.example.json
```

## 安全边界

本项目会操作本机 Claude Desktop 文件和当前用户的 `claude://` 登录回调。使用前请确认你理解这些影响。

不要上传或公开：

- `config\paths.local.json`
- `reports/*.json`
- `backups/**`
- `downloads/**`
- `logs/**`
- 完整 `claude://` OAuth 回调 URL
- Claude 账号、cookie、token、API key 或授权头

提交前建议检查：

```powershell
git status --short --branch --ignored
rg -n "C:\\Users|Bearer|Authorization|api[_-]?key|secret|token|sk-[A-Za-z0-9]" .
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
docs/          设计说明和实现计划
language-pack/ 汉化包清单
overrides/     本地增量翻译
reports/       本机诊断输出，不提交
backups/       本机备份，不提交
scripts/       管理、部署、诊断、更新、回滚脚本
```

## AI 助手协作

- Codex 用户：读取 `AGENTS.md`
- Claude Code 用户：读取 `CLAUDE.md`
- 普通用户：直接运行 `scripts\setup.ps1`

Skill 可以作为 AI 协作的增强，但不应该作为普通用户部署的前置条件。普通用户、Codex 用户、Claude Code 用户都应优先使用同一个部署脚本。
