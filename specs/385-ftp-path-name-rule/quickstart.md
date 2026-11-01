# Quickstart - validating 385

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestFtpServerPath385`: ASCII equivalence with the old rule, non-ASCII rows, contract rules).
3. Probe (hidden desktop):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\385-ftp-path-name-rule\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\385-ftp-path-name-rule\probe\ftp385_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile specs\385-ftp-path-name-rule\probe\result_after.txt"`
   -> CROSS and ASCII rows PASS (before the fix: CROSS FAIL - `STOR x.txt` without the question).
4. Regressions: probes 215, 224, 233, 277 as their fix-logs record them.
