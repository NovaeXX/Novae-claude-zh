# Security

本项目会操作 Claude Desktop 的本地应用文件、注册表协议回调和本机用户数据路径。公开发布、提交 issue 或分享日志前，请先确认没有泄露个人数据。

## 不要公开的信息

- 完整的 `claude://` OAuth 回调 URL。它可能包含一次性登录凭据。
- `config/paths.local.json`。它包含本机路径、用户名和安装目录。
- `backups/`、`reports/`、`logs/`、`downloads/` 中的原始文件。
- Claude 账号、订阅、组织、会话、cookie、token、API key 或授权头。

## 分享诊断信息

可以分享：

- 脚本名称和执行步骤。
- 已脱敏的错误消息。
- `diagnose.ps1` 输出中去掉本机用户名和绝对路径后的摘要。

不建议直接上传完整诊断 JSON。它可能包含本机路径、注册表回调和进程路径。

## 本地风险边界

- `update-and-patch.ps1` 会修改便携版 Claude 应用文件，并在修改前创建备份。
- `force-zh-cn-resources.ps1` 会覆盖便携版中的语言资源入口。
- `patch-remote-dom-translation.ps1` 会修改 `resources/app.asar` 并更新 `Claude.exe` 中的 ASAR 校验。
- `uninstall-official-msix.ps1` 会卸载当前用户的官方 Claude MSIX，应只用于排查官方版本接管登录回调的问题。

运行这些脚本前，请关闭 Claude，并确保 `config/paths.local.json` 指向的是你准备操作的便携版目录。
