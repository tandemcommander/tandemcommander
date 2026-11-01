# Quickstart - 377

Prerequisites: Windows with IMAPI2FS (any Windows 11), Python 3, the Debug build.

1. Build: `.\build.cmd` → `BUILD SUCCEEDED`.
2. Probe (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\377-uniso-udf-metadata-order\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\377-uniso-udf-metadata-order\probe\iso377_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS (C-U250, C-U250SUB, C-U250SWAP, C-U201SUB, C-PLAIN, R-U250FAR), registry
   restored and identical.
3. Regressions: 356 (`iso356_probe.ps1`, N-U250 now fails as expected - its expectation was the old
   defect), 358, 361 - recorded results.
4. `saltests.exe` → `0 failed`; `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
