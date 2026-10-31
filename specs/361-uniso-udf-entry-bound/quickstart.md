# Quickstart - 361-uniso-udf-entry-bound

1. Build: PowerShell `.\build.cmd` → `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` → `saltests: <n> checks, 0 failed`
   (group `TestIsoUdfEntry_361`).
3. Probe (hidden desktop, WSL Ubuntu for the seed images):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\361-uniso-udf-entry-bound\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\361-uniso-udf-entry-bound\probe\iso361_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every damaged row PASS (program answers, image kept, the expected box), every control row PASS
   (all files extracted, image deleted). Before the fix: the type-5 rows hang (END FAIL), the L_EA row a bug
   report.
4. Regressions: `specs\330-iso-unreadable-folder\probe\iso330_probe.ps1` (30 / 0) and
   `specs\360-uniso-udf-vat-bound\probe\iso360_probe.ps1` (50 / 0).
5. Encoding guard: `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
