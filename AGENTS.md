# AGENTS.md

## 项目定位

这是一个 Windows 版 Claude Desktop zh-CN 汉化管理项目。目标是维护本地资源汉化、远程页面 DOM 汉化、登录回调桥接、更新重建和回滚流程。

## 工作原则

- 优先保护用户隐私，不提交本机路径、诊断报告、备份、日志、下载缓存或 OAuth 回调 URL。
- 优先保持普通用户可执行的 PowerShell 流程，不把部署依赖在某个 AI 平台专属能力上。
- 优先使用现有脚本和配置结构，避免无关重构。
- 修改脚本前先运行 `git status --short --branch --ignored`。
- 提交前检查暂存文件，确保没有本机文件混入。

## 常用入口

首次部署：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1
```

安装登录回调桥接器：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-oauth-callback-bridge.ps1
```

启动管理器：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\claude-zh-manager.ps1
```

诊断：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\diagnose.ps1
```

## 发布前检查

```powershell
git status --short --branch --ignored
git diff --check
git diff --cached --name-only
rg -n "C:\\Users|Bearer|Authorization|api[_-]?key|secret|token|sk-[A-Za-z0-9]" .
```

允许被忽略但不能提交的本机文件包括：

```text
config/paths.local.json
reports/*.json
backups/**
downloads/**
logs/**
```

## 修改建议

- 用户文档优先讲“这是什么、为什么要做、影响哪里、不做会怎样”。
- 脚本输出要说明风险边界，尤其是写注册表、覆盖应用文件、回滚等动作。
- 新增部署能力时，优先扩展 `scripts/setup.ps1`，不要创建多套并行安装流程。
- 新增翻译时，优先放入 `overrides/`，不要直接修改运行时生成文件。
