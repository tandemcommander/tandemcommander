# Quickstart - feature 341

Prerequisites: Python (for `ftpmini_hide.py`), the Debug x64 build.

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` ->
   `saltests: <n> checks, 0 failed` (includes `TestFtpServerIdent341`).
3. Probe (hidden desktop, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\341-ftp-upload-cache-alias\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\341-ftp-upload-cache-alias\probe\ftp341_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: ALIAS-REN, ALIAS-UP, SAME-REN ROW and END PASS (6 / 0); on `main` ALIAS-REN and
   ALIAS-UP FAIL (`probe/result_main.txt`).
4. Regression: feature 323's `ftp302_probe.ps1` -> 16 / 0.
