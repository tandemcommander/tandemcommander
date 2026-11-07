# Quickstart - 410-ftp-alias-refresh

1. `.\build.cmd` -> `BUILD SUCCEEDED`.
2. `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`.
3. Probe (hidden desktop, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\410-ftp-alias-refresh\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\410-ftp-alias-refresh\probe\ftp410_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: REFRESH-ALIAS, REFRESH-SAME, REFRESH-ELSE, CACHE-ALIAS, CACHE-SAME all PASS
   (at 2ce004b9: REFRESH-ALIAS and CACHE-ALIAS FAIL), registry restored and identical.
4. Regression: `specs\341-ftp-upload-cache-alias\probe\ftp341_probe.ps1` -> 12 / 0.
