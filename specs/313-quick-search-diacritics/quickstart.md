# Quickstart - validating 313

All commands from the repository root; PowerShell for the build, saltests and probes.

1. `.\build.cmd` -> `BUILD SUCCEEDED`.
2. `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (the `TestQuickFilter244` lines report the M1/M3 counts and the 313 folding block).
3. Probe, option on:
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\313-quick-search-diacritics\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\313-quick-search-diacritics\probe\qs313_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect after -Label after"`
   -> 0 FAIL; registry restored identical.
4. Probe, option off: the same with `-Expect off -FilterOption 0` -> D09 PASS, D10 equal to
   `result_off_before.txt`.
5. Feature 244 probe: `-Expect new` (all rows PASS) and `-Expect old -FilterOption 0`.
6. Timing: `build.cmd release` with `OPENSAL_BUILD_DIR` = a scratch folder, then the 244 probe
   `-Perf -Only P` on that build; compare with `probe/result_perf_before.txt`.
