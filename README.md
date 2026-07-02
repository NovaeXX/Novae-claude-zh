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
- 运行诊断，告诉你当前环境是否可以继续

如果希望部署时同步安装登录回调桥接器：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1 -InstallCallbackBridge
```

登录回调桥接器会写入当前 Windows 用户的 `claude://` 协议处理器。作用是：浏览器完成 Claude 登录后，把回调交给当前项目配置的 Claude zh-CN。

### 2. 启动管理器

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\claude-zh-manager.ps1
```

管理器里可以执行：

- 启动 Claude zh-CN
- 诊断当前状态
- 检查官方更新
- 一键更新并重新汉化
- 安装或校验登录回调桥接器
- 重新注入远程页面汉化
- 扫描待翻译文本
- 回滚到最近备份

### 3. 登录前准备

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\prepare-login.ps1
```

这个命令会关闭当前 Claude 进程、确认 zh-CN 配置、写入当前项目的 OAuth 回调桥接器，并启动 Claude zh-CN。它只做启动前和启动后的一次性校验，不会在登录期间常驻守护。

### 4. 常用命令

诊断当前状态：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\diagnose.ps1
```

安装登录回调桥接器：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-oauth-callback-bridge.ps1
```

重新注入远程页面汉化：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\patch-remote-dom-translation.ps1 -CloseClaude
```

回滚到最近一次备份：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\rollback-last-backup.ps1
```

### 获取项目文件

如果你还没有项目目录，可以用 Git 克隆：

```powershell
cd D:\Projects
git clone https://github.com/NovaeXX/Novae-claude-zh.git
cd Novae-claude-zh
```

`D:\Projects` 可以换成你自己的项目目录。不会使用 Git 的用户，也可以在 GitHub 页面下载源码压缩包，解压后在项目目录里运行上面的部署命令。

## 项目能力

Claude Desktop 的界面文字来自多个地方：本地资源文件、桌面壳、远程 `claude.ai` 页面，以及账号状态相关的动态文本。本项目把这些来源收敛到一套可维护流程里。

核心能力：

- 本地 `zh-CN` 资源覆盖与增量维护
- 远程 `claude.ai` 页面运行时 DOM 汉化
- 当前用户 `claude://` OAuth 登录回调桥接
- 官方更新后的重新构建与重新汉化
- 本机诊断报告与最近备份回滚
- 待翻译文本扫描与 `overrides/` 增量维护

## 推荐流程

首次使用：

1. 运行 `scripts\setup.ps1`
2. 按提示填写或确认本机路径
3. 运行诊断
4. 安装登录回调桥接器
5. 运行 `scripts\prepare-login.ps1`
6. 在打开的 Claude zh-CN 窗口完成浏览器登录

日常使用：

1. 打开管理器
2. 启动 Claude zh-CN
3. 如有官方更新，执行“一键更新并重新汉化”
4. 如有新增英文文本，先诊断，再扫描待翻译文本或重新注入远程页面汉化

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
docs/          产品规格和实现计划
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
