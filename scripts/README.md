# scripts

主入口：

```powershell
.\claude-zh-manager.ps1
```

常用脚本：

- `claude-zh-manager.ps1`：菜单式管理器入口。
- `diagnose.ps1`：检查路径、进程、登录回调、语言资源覆盖，并生成 `reports/latest-diagnose.json`。
- `update-and-patch.ps1`：检查/更新官方版本，应用 FOMO 汉化、本地增量、en-US 影子资源、远程页面汉化和 OAuth 桥接。
- `scan-untranslated.ps1`：扫描本地资源、运行时远程待翻译文本、日志英文片段，生成待翻译清单。
- `rollback-last-backup.ps1`：回滚到最近一次更新前备份。
- `export-standalone-project.ps1`：导出独立项目目录，复制公开项目文件并迁移本机 `paths.local.json`。
- `patch-remote-dom-translation.ps1`：向远程 `claude.ai` 页面 preload 注入运行时 DOM 汉化。
- `force-zh-cn-resources.ps1`：把 `en-US` 资源入口替换成中文资源，处理 Claude 把 locale 改回英文的情况。
- `install-oauth-callback-bridge.ps1`：把 `claude://` 指向本地桥接器，捕获脱敏诊断后转交汉化版。
- `manual-oauth-callback.ps1`：手动粘贴完整 `claude://` 回调 URL 并转交汉化版。
- `prepare-login.ps1`：关闭 Claude、强制 zh-CN、修复回调并启动汉化版。
- `repair-login-state.ps1`：更确定地重置登录前状态。
- `fix-oauth-callback.ps1`：备份并修复 `claude://` 回调到 FOMO 启动器。
- `uninstall-official-msix.ps1`：临时卸载官方 MSIX，用于排除官方版本接管回调。
- `lib/ClaudeZh.Common.ps1`：公共函数。

这些脚本默认复用 FOMO 的基础翻译和补丁逻辑，不直接修改 FOMO 源码。
