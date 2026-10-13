# Quickstart: checking feature 131

```powershell
build\tandemcommander\Debug_x64\saltests\saltests.exe
src\plugins\sftp\test\build_and_run.cmd          # 85 passed, 0 failed

$p = 'powershell -NoProfile -ExecutionPolicy Bypass -File specs\131-plugin-defect-batch\probe\batch131_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe'
powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_on_hidden_desktop.ps1 -CommandLine $p
```

Expected: `PASS 2, FAIL 0` (on 0.1.9 the program crashes and writes a bug report - delete it
from `%LOCALAPPDATA%\Tandem Commander` afterwards).

By hand: Change Directory to `ftp://a%sb/` - one error box with the host as typed.

The rows that need a server, a volume or a special file are listed in `fix-log.md`, section 5,
with the steps in `items/*.md`.
