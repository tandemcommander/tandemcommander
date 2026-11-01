# Quickstart - validating feature 380

1. Build: `.\build.cmd` (PowerShell, repository root) → `BUILD SUCCEEDED`.
2. Encoding guard: `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
3. Probe on the hidden desktop (PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\380-regedt-full-path-cut\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\380-regedt-full-path-cut\probe\regpath380_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: SHORT, LONG, CJK RUN rows PASS, every END row PASS, registry restored identical,
   fixture key removed. Before the fix (`result_before.txt`): LONG and CJK FAIL.
4. Inventory: `grep -n "WStrToU8" src/plugins/regedt/*.cpp` - the four sites of research R1-R4 test
   the result.
