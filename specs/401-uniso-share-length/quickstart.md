# Quickstart - validating 401-uniso-share-length

1. Build: `.\build.cmd` (PowerShell, repository root) → `BUILD SUCCEEDED`.
2. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` → `saltests: <n> checks, 0 failed`.
3. Probe (hidden desktop, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\401-uniso-share-length\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\401-uniso-share-length\probe\iso401_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: `Rows: PASS 10, FAIL 0` (before: PASS 6, FAIL 4), registry restored and identical.
4. Regressions: `specs\328-uniso-refused-entry\probe\iso328_probe.ps1` (20 / 0) and
   `specs\400-uniso-walk-after-unreadable\probe\iso400_probe.ps1` (48 / 0), same way.
