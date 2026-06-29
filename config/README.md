# config

`paths.local.json` stores machine-specific paths and should not be committed.

Setup:

```powershell
Copy-Item .\config\paths.example.json .\config\paths.local.json
notepad .\config\paths.local.json
```

Update the copied file to match your local Python, patch tool, portable Claude, user data, launcher, overrides, and backup directories.

The public example uses these field names:

- `patchToolRoot`
- `patchScript`
