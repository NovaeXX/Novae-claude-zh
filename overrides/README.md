# 本地增量翻译

这里保存本项目确认过的本地补充翻译。

正式增量文件：

- `frontend-zh-CN.override.json`：本地前端资源增量。
- `desktop-zh-CN.override.json`：桌面外壳资源增量。
- `statsig-zh-CN.override.json`：statsig 文案增量。
- `remote-dom-zh-CN.override.json`：登录后远程 `claude.ai` 页面可见文本增量。
- `remote-dom-fragments-zh-CN.override.json`：远程页面片段级翻译，用于处理链接、换行、加粗导致的 DOM 拆分。
- `hardcoded-replacements.override.json`：硬编码替换规则记录，后续确认格式后再纳入自动流程。

生成文件：

- `pending-local-resources.json`：扫描出的本地资源待翻译文本。

`pending-*.json` 只是待处理清单，不会被当成正式翻译。确认中文后，把对应内容迁移到正式 override 文件。

合并顺序：

```text
官方英文资源 -> 基础中文资源 -> 本地增量中文资源
```

远程页面翻译需要重新运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\patch-remote-dom-translation.ps1 -CloseClaude
```
