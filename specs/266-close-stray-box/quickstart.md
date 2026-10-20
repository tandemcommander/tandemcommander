# Quickstart: validating 266

All commands from the repository root; build folder `build` unless `OPENSAL_BUILD_DIR` is set.

1. Encoding guard (Bash): `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
2. Build (PowerShell): `.\build.cmd` -> `BUILD SUCCEEDED`.
3. Unit rules (PowerShell): `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` ->
   `saltests: <n> checks, 0 failed` (no new checks; a regression check of the tree).
4. Disk Map regression (PowerShell, hidden desktop) - feature 143's probe, rows E4-E6:

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\266-close-stray-box\probe\result_143_E4-E6.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\143-diskmap-release-guard\probe\release_guard_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Only E4,E5,E6 -OutFile specs\266-close-stray-box\probe\result_143_E4-E6_rows.txt"
   ```

   Expected: every row PASS (E5: clean exit, file kept, the Debug note of the forced unload as
   before - part (1) keeps the force semantics).
5. Comparator stray box: NOT DRIVEN (research R2) - code review of `mainwnd.cpp` `WM_DESTROY`
   and `viewwnd3.cpp` `WM_USER_HANDLEFILEERROR`; the independent review checks it.
