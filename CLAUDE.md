# CLAUDE.md

## 项目定位

这是一个 Windows 版 Claude Desktop zh-CN 汉化管理项目，用于管理本地资源汉化、远程页面 DOM 汉化、登录回调桥接、更新重建和回滚。

## Claude Code 协作规则

- 不要提交 `config/paths.local.json`、`reports/*.json`、`backups/**`、`downloads/**`、`logs/**`。
- 不要输出或保存完整 `claude://` OAuth 回调 URL。
- 不要在未说明影响的情况下修改注册表、用户数据目录或 Claude 应用文件。
- 修改前运行 `git status --short --branch --ignored`。
- 提交前确认暂存区只包含本次任务相关文件。

## 推荐部署入口

普通用户、Codex 用户、Claude Code 用户都应优先使用同一个部署脚本：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1
```

如果用户明确允许写入 `claude://` 登录回调：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1 -InstallCallbackBridge
```

## 常用命令

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\diagnose.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\claude-zh-manager.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\patch-remote-dom-translation.ps1 -CloseClaude
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\rollback-last-backup.ps1
```

## 文档口径

- 对普通用户，优先解释页面哪里会变、登录路径怎么变、出错后怎么回滚。
- 对开发者，说明脚本入口、配置字段、文件边界和测试方式。
- 对安全问题，明确哪些文件只属于本机，不能上传到公开仓库。
