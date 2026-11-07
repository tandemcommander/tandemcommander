# Quickstart - validating 413

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `0 failed`
   (`TestTabStrip413`: the clamped lefts, the multiples, the scrolled run, the fill rule).
3. Probe (PowerShell, hidden desktop):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\413-tab-drag-first-place\probe\run_after.log -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\413-tab-drag-first-place\probe\tabs413_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after -OutFile specs\413-tab-drag-first-place\probe\result_after.txt"`
   -> every row PASS except `MOUSE REAL` (NOT DRIVEN); before: FIRST / SCROLLED and
   LOOK-DARK-INACTIVE fail.
4. Regression: `tabs404_probe` (dark inactive against the 413 baseline) and `tabs405_probe` pass.
5. By hand (release checklist): drag a tab to the left end with a real mouse in both panels; look
   at both themes side by side.
