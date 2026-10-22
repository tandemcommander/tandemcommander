# Quickstart: validating 305

1. Build: `.\build.cmd` (PowerShell) → `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` →
   `saltests: <n> checks, 0 failed` and the line `saltests 305: ...` naming at least one volume
   without 8.3 names and the cut reproduced (the raw answer) 3 times.
3. Measurement: `probe/measure_core.cpp` rebuilt against the changed header, run with a base on a
   volume without 8.3 names → 260 / 261 / 300 / 400 whole and existing (before: 259 units, cut);
   RAWPATH refused; `SalFolderShortcutTargetU8` too long for `MAX_PATH`, whole for
   `SAL_MAX_PATH_UTF8`.
4. GUI probe (hidden desktop):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\305-core-shortcut-target-cut\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\305-core-shortcut-target-cut\probe\lnk305_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -MkLnk <mklnk305.exe>"`
   → Enter and Go to Shortcut Target on a 300-unit-target shortcut end in the whole target
   folder; registry restored and identical.
5. Negative control: the rule made to return the answer as it is → saltests fails the 305 rows.
