# config

`paths.local.json` 保存本机路径，只属于当前机器，不应提交到 Git。

首次部署优先运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1
```

如果需要手动创建配置，可以复制示例文件：

```powershell
Copy-Item .\config\paths.example.json .\config\paths.local.json
notepad .\config\paths.local.json
```

需要按本机环境确认的字段：

- `pythonExe`
- `patchToolRoot`
- `patchScript`
- `portableClaudeDir`
- `portableUserDataDir`
- `launcherPath`
- `overridesDir`
- `backupDir`
