# Quickstart: validating feature 261

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (the block "feature 261").
3. Probe (hidden desktop):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\261-case-twins-exact-match\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\261-case-twins-exact-match\probe\twin261_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`
   -> `Rows: PASS 14, FAIL 0` (before: 5 FAIL; `probe/result_before.txt`).
4. Regression: the same with `specs\232-compare-dirs-case-only-names\probe\cmp232_probe.ps1` -> 16 / 0.
5. By a person (no clipboard / configured User Menu on the hidden desktop): Ctrl+X on `A.txt` with
   both panels on one case-sensitive folder ghosts `A.txt` in both; a User Menu item with
   `$(CompareName2)` gets the other panel's exact twin.
