# Quickstart - 268-damaged-list-entries

Prerequisites: a configuration exists (`HKCU\Software\Tandem Commander`); no `tandemcommander.exe`
runs. The probe backs up the key, writes its own lists, and restores and verifies the key.

1. Build: PowerShell `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Probe (PowerShell, hidden desktop):

   ```
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\268-damaged-list-entries\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\268-damaged-list-entries\probe\dmg268_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: `Rows: PASS 48, FAIL 0`, `registry restored+identical: True`. Before the fix:
   PASS 30, FAIL 18 (`probe/result_before.txt`).
3. Regression: `saltests.exe` -> `0 failed`; `python tools/check_encoding.py --strict` ->
   `TOTAL: 0 finding(s)`.
