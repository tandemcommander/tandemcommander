# Quickstart - feature 394

1. Build: `.\build.cmd` (PowerShell) -> `BUILD SUCCEEDED`.
2. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `0 failed`.
3. Probe (hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\394-cpio-empty-name-link\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\394-cpio-empty-name-link\probe\cpioempty_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every RUN row PASS (before: PASS 11 / FAIL 9), registry restored + identical.
4. Regressions: the probes of features 306, 308, 309, 310, 321 (tar and unpack) and 393, each with
   its recorded result.
