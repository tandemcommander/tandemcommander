# Quickstart - validating 274

1. Build: `.\build.cmd` (PowerShell, repository root) - `BUILD SUCCEEDED`.
2. Regression rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` - `0 failed`.
3. Probe on the hidden desktop (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\274-createdir-long-folder\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\274-createdir-long-folder\probe\createdir274_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: rows SHORT, REL, CJK, U255, U256, LIMIT all PASS (12 rows with END rows), registry
   restored and identical, fixture removed. Before the fix: 8 PASS / 4 FAIL
   (`probe/result_before.txt`).
4. By hand (optional): F7 in a folder deeper than 260 bytes, type a name - the folder appears.
