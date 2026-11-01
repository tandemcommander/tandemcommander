# Quickstart - validating 381

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (includes `TestCabName381`).
3. Scan: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`;
   `python tools/check_encoding.py --plugins` -> no `uncab/uncab.cpp` line.
4. Probe (hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\381-uncab-wtf8-name\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\381-uncab-wtf8-name\probe\cab381_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: 18 rows PASS (9 RUN + 9 END), registry restored and identical. Before the fix
   (`result_before.txt`): U-WTF8, U-WTF8L, L-WTF8, L-WTF8L FAIL.
