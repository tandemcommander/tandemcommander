# Quickstart - 396-tar-dotdot-name

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (the `TestTarDotDot396` checks and the corrected `TarNorm309` pin).
3. Probe (hidden desktop, PowerShell, from the repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\396-tar-dotdot-name\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\396-tar-dotdot-name\probe\dotdot_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS (6 RUN + 6 END), registry restored and identical. Before the fix: 7 / 5.
4. Regression probes: 306 (`pax306_probe.ps1`), 308 (`unp308_probe.ps1`), 309 (`link309_probe.ps1`),
   395 (`cpiosolo_probe.ps1`) - the same results as recorded in their fix-logs.
