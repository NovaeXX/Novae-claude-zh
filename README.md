# Claude zh-CN Manager

Claude zh-CN Manager 是一个面向 Windows 用户的 Claude Desktop 汉化维护项目。它围绕 Claude Desktop 的本地资源、远程页面、登录回调、更新重建和回滚流程，提供一套可长期维护的中文化管理方案。

这个项目的目标不是重新做一个 Claude，也不是修改 Anthropic 服务端能力，而是把“能用但分散的汉化脚本”整理成一套可重复、可诊断、可回滚的本地管理流程。

## 项目背景

Claude Desktop 的 Windows 客户端由两部分内容组成：

- 本地客户端资源：菜单、窗口、配置、部分提示文案。
- 远程 `claude.ai` 页面：登录后的主界面、设置页、弹窗、账号相关状态。

这意味着只替换本地语言文件，通常不能覆盖所有界面。用户常见体验是：启动窗口部分中文，但登录后主界面、设置页或弹窗仍然出现英文。

同时，Claude Desktop 官方更新频繁。每次更新都可能覆盖本地资源、启动器、`app.asar`、语言入口或登录回调配置。如果没有固定流程，汉化状态很容易在更新后失效。

## 用户痛点

从实际使用角度看，主要痛点有五类：

1. 登录后回到英文窗口
   - 浏览器完成登录后会触发 `claude://` 回调。
   - 如果回调指向官方版或旧路径，用户会回到未汉化窗口。
   - 结果是“登录前看起来正常，登录后又变英文”。

2. 官方更新后汉化被覆盖
   - 更新可能替换 `Claude.exe`、`app.asar` 和语言资源。
   - 用户需要重新下载、重建、补丁、注入远程页面翻译。
   - 手动处理容易漏步骤，也难判断失败点。

3. 页面文字来源不统一
   - 一部分文字来自本地 JSON。
   - 一部分文字写在客户端代码里。
   - 一部分文字来自远程网页。
   - 一部分文字根据账号、地区、订阅状态动态出现。

4. 剩余英文难以持续维护
   - 官方新增功能后，经常会出现新的英文文案。
   - 如果没有采集机制，维护者只能靠肉眼截图补翻译。
   - 容易遗漏设置页、弹窗、错误提示等低频场景。

5. 出错后缺少安全回退
   - 汉化涉及本地应用文件和注册表回调。
   - 如果没有更新前备份，出错后很难恢复到上一个可用状态。

## 这个项目解决什么

Claude zh-CN Manager 主要解决以下问题：

- 统一入口：用一个管理器菜单承载启动、诊断、更新、修复、扫描、回滚。
- 登录回调修复：把 `claude://` 回调转交给当前汉化版，避免登录后打开错误窗口。
- 本地增量翻译：维护本项目自己的补充词库，覆盖官方新增或遗漏的文案。
- 远程页面汉化：对登录后的 `claude.ai` 页面进行运行时 DOM 翻译。
- 待翻译采集：记录仍显示英文的文本，形成后续翻译清单。
- 更新后重建：官方更新后重新应用基础汉化、本地增量和远程页面注入。
- 备份与回滚：关键操作前备份，失败时可以恢复到最近可用版本。

## 适合谁使用

适合：

- 使用 Windows 版 Claude Desktop，并希望尽量保持中文界面的用户。
- 能接受 PowerShell 脚本操作的用户。
- 需要在官方更新后继续维护汉化状态的用户。
- 想基于现有汉化包继续补充翻译的维护者。

不适合：

- 只想安装一个完全无感的一键图形化软件的用户。
- 不希望任何脚本修改本地 Claude 文件或注册表回调的用户。
- 需要跨平台支持 macOS、Linux 的用户。
- 期望所有远程动态文案即时自动完美翻译的用户。

## 工作原理

项目分为五层：

1. 管理入口
   - `scripts/claude-zh-manager.ps1`
   - 提供菜单式入口，减少用户记命令的成本。

2. 路径配置
   - `config/paths.local.json`
   - 保存本机路径，例如补丁工具、便携版 Claude、用户数据目录和启动器路径。
   - 这个文件只属于本机，不应该提交到公开仓库。

3. 基础补丁与资源构建
   - 负责准备便携版 Claude、语言资源和必要的客户端补丁。
   - 这是项目能在官方更新后重新恢复中文界面的基础能力。

4. 本地增量翻译
   - `overrides/`
   - 存放本项目确认过的新增翻译。
   - 更新后最后应用，避免被基础资源覆盖。

5. 远程页面运行时翻译
   - 对 `claude.ai` 页面中可见文本进行替换。
   - 支持精确文本、短语、片段和属性翻译。
   - 能记录未命中的英文文本，方便后续补充。

## 快速开始

### 1. 准备环境

建议先准备：

- Windows 10 或 Windows 11。
- Git，用来克隆和更新本项目。
- PowerShell 5.1 或更新版本。
- Python，用来执行补丁和资源处理脚本。
- 一个可用的 Claude Desktop Windows 安装或便携版目录。

如果你不熟悉这些工具，可以先确认命令是否可用：

```powershell
git --version
python --version
powershell -Version
```

### 2. 从 GitHub 克隆项目

```powershell
cd D:\Projects
git clone https://github.com/NovaeXX/Novae-claude-zh.git
cd Novae-claude-zh
```

如果你想放到其它目录，把 `D:\Projects` 换成自己的项目目录即可。

### 3. 创建本机配置

复制示例配置：

```powershell
Copy-Item .\config\paths.example.json .\config\paths.local.json
notepad .\config\paths.local.json
```

`paths.local.json` 是你的本机配置，里面会包含本机路径和用户名，不要上传到 GitHub。

你需要按本机环境修改：

- 项目根目录：当前克隆下来的项目目录。
- Python 路径：本机 Python 可执行文件。
- 补丁工具目录：本机用于构建和修补 Claude 的工具目录。
- 补丁脚本路径：本机用于执行补丁的脚本文件。
- 便携版 Claude 目录：实际要被汉化和启动的 Claude 目录。
- 用户数据目录：汉化版 Claude 使用的独立数据目录。
- 启动器路径：Claude zh-CN 的启动脚本或快捷入口。
- 增量翻译目录：本项目 `overrides` 目录。
- 备份目录：本项目 `backups` 目录。

### 4. 第一次诊断

先不要直接更新或修补，先运行诊断：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\diagnose.ps1
```

重点看：

- `Claude.exe` 是否存在。
- 启动器是否存在。
- 用户数据目录是否正确。
- `Locale config` 是否为 `zh-CN`。
- `claude:// callback` 是否指向本项目脚本。

### 5. 安装登录回调桥接器

如果诊断显示 `claude://` 没有指向本项目，运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-oauth-callback-bridge.ps1
```

这一步会修改当前 Windows 用户的 `claude://` 协议处理器。它的作用是：浏览器登录 Claude 后，把回调交给当前汉化版窗口，而不是打开官方版或旧路径。

### 6. 启动管理器

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\claude-zh-manager.ps1
```

然后按菜单完成：

1. 检查状态。
2. 强制中文资源入口。
3. 重新注入远程页面汉化。
4. 启动 Claude zh-CN。
5. 浏览器登录并确认回到汉化窗口。

### 7. 后续更新项目

以后要更新本项目代码，可以在项目目录执行：

```powershell
git pull
```

如果你改过 `overrides/` 里的翻译文件，更新前建议先提交或备份自己的改动，避免合并时难以判断差异。

## 推荐使用流程

### 首次使用

1. 配置 `config\paths.local.json`。
2. 打开管理器。
3. 先运行“诊断当前状态”。
4. 修复或安装 OAuth 回调桥接器。
5. 强制 `zh-CN` 语言配置。
6. 重新注入远程页面汉化。
7. 启动 Claude zh-CN。
8. 浏览器登录后确认仍回到汉化窗口。

### 日常启动

优先从管理器启动：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\claude-zh-manager.ps1
```

然后选择“启动 Claude zh-CN”。

这样做的好处是：启动路径、用户数据目录、语言配置和回调状态更容易保持一致。

### 登录异常时

如果登录后打开了英文窗口，优先处理 `claude://` 回调：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-oauth-callback-bridge.ps1
```

然后诊断：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\diagnose.ps1
```

诊断里看到以下状态，说明回调已指向本项目桥接器：

```text
Status: local OAuth bridge is installed.
```

### 官方更新后

推荐流程：

1. 关闭 Claude。
2. 打开管理器。
3. 选择“检查官方更新”。
4. 如有更新，选择“一键更新并重新汉化”。
5. 更新后运行诊断。
6. 启动 Claude zh-CN 验证主界面、设置页和弹窗。

更新流程会尽量先备份再修改，避免旧版本直接丢失。

## 管理器菜单说明

管理器菜单分为四组：

- 日常使用
  - 启动 Claude zh-CN。
  - 诊断当前状态。
  - 检查官方更新。
  - 一键更新并重新汉化。

- 修复工具
  - 修复登录回调。
  - 安装 OAuth 回调桥接器。
  - 强制英文入口加载中文资源。
  - 重新注入远程页面汉化。

- 翻译维护
  - 扫描待翻译文本。
  - 应用本地增量翻译。
  - 生成汉化覆盖报告。

- 备份回滚
  - 查看最近备份。
  - 回滚到上一个可用汉化版。

## 翻译维护流程

正式增量翻译放在：

```text
overrides
```

常用文件：

- `overrides/frontend-zh-CN.override.json`
  - 处理前端资源里的新增或修正文案。

- `overrides/desktop-zh-CN.override.json`
  - 处理桌面壳层资源。

- `overrides/statsig-zh-CN.override.json`
  - 处理实验配置、功能开关相关文案。

- `overrides/remote-dom-zh-CN.override.json`
  - 处理远程页面中的精确可见文本。

- `overrides/remote-dom-fragments-zh-CN.override.json`
  - 处理被链接、加粗、换行拆开的片段文本。

扫描待翻译文本：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\scan-untranslated.ps1
```

重新注入远程页面汉化：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\patch-remote-dom-translation.ps1 -CloseClaude
```

维护建议：

- 不要把品牌名、模型名、快捷键、代码片段强行翻译。
- 新增翻译先确认含义，再加入 override。
- 遇到同一英文在不同上下文含义不同，优先保守处理。
- 低频弹窗和错误提示建议通过诊断报告补充。

## 更新与回滚

一键更新并重新汉化会先备份关键文件，再执行更新和补丁。

如果更新后不可用，可以从管理器选择“回滚到最近一次更新备份”，或直接运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\rollback-last-backup.ps1
```

回滚会覆盖当前汉化版中的关键应用文件，例如：

- `Claude.exe`
- `resources\app.asar`
- 关键语言资源 JSON

回滚不会主动删除账号数据或聊天记录。

## 安全边界

本项目会操作本机 Claude Desktop 相关文件和当前用户的 `claude://` 注册表回调。使用前请理解这些边界：

- 会修改便携版 Claude 的应用文件。
- 会写入当前 Windows 用户的 `claude://` 协议处理器。
- 会读取和写入汉化版用户数据目录中的配置文件。
- 会在 `backups/` 和 `reports/` 里生成本机诊断或备份文件。

不要公开提交：

- `config\paths.local.json`
- `backups\`
- `reports\`
- `logs\`
- `downloads\`
- 完整 `claude://` OAuth 回调 URL
- Claude 账号、cookie、token、API key 或授权头

公开发布前建议检查：

```powershell
git status --short --ignored
rg -n "C:\\Users|claude://|Bearer|Authorization|api[_-]?key|secret|token" .
```

## 常见问题

### 为什么登录后还是英文？

优先检查 `claude://` 回调是否指向本项目的桥接脚本：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\diagnose.ps1
```

如果回调还指向官方版或旧目录，运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-oauth-callback-bridge.ps1
```

### 为什么设置页还有少量英文？

这通常是远程页面或动态服务端文案。先扫描待翻译文本，再把确认过的翻译加入 `overrides/remote-dom-zh-CN.override.json` 或片段词库。

### 为什么诊断输出有乱码？

部分外部脚本或终端编码可能不是 UTF-8。优先看本项目诊断报告中的结构化字段，例如路径、回调状态、语言配置和覆盖率。

### 可以直接删除 backups 或 reports 吗？

可以清理本机旧数据，但不要把这些目录里的真实内容提交到公开仓库。`backups/` 可能包含回调历史或应用备份，`reports/` 可能包含本机路径。

## 项目文件说明

```text
config/
  paths.example.json      示例配置
  paths.local.json        本机配置，不应提交

docs/
  claude-zh-manager-v1-spec.md
  implementation-plan.md

language-pack/
  manifest.json           汉化包版本、目标版本和能力清单

overrides/
  *.override.json         本地增量翻译

scripts/
  claude-zh-manager.ps1   管理器入口
  diagnose.ps1            诊断当前状态
  update-and-patch.ps1    更新并重新汉化
  install-oauth-callback-bridge.ps1
                          安装登录回调桥接器
  patch-remote-dom-translation.ps1
                          注入远程页面汉化
  rollback-last-backup.ps1
                          回滚到最近备份
```

## 版本信息

当前汉化包清单：

```text
language-pack\manifest.json
```

它记录：

- 汉化包版本
- 目标 Claude Desktop 版本
- 本地增量翻译文件
- 远程 DOM 翻译能力

## 贡献建议

提交翻译或脚本改动前，请先确认：

- 是否影响登录、启动、更新、回滚这些核心流程。
- 是否会把本机路径、诊断报告、账号数据带进提交。
- 是否有明确的验证方式。
- 是否能在出错后回到上一个可用状态。

建议优先提交：

- 明确可验证的新增翻译。
- 登录回调、诊断、回滚相关的稳定性修复。
- 文档中能降低误操作的说明。
- 安全边界和故障排查补充。

不建议提交：

- 未确认上下文的批量机器翻译。
- 包含本机路径或账号信息的日志。
- 会删除用户数据的脚本改动。
- 无备份机制的高风险补丁。
