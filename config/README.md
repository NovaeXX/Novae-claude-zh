# config

`paths.local.json` stores machine-specific paths and should not be committed.

Setup:

```powershell
Copy-Item .\config\paths.example.json .\config\paths.local.json
notepad .\config\paths.local.json
```

Update the copied file to match your local Python, FOMO source, portable Claude, user data, launcher, overrides, and backup directories.
