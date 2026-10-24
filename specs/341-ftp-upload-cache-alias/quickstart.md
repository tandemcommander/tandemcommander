# Quickstart - feature 341

Prerequisites: Python (for `ftpmini_hide.py`), the Debug x64 build.

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` ->
   `saltests: <n> checks, 0 failed` (no new rule in this feature).
3. Probe (hidden desktop, PowerShell, from the repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\341-ftp-upload-cache-alias\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\341-ftp-upload-cache-alias\probe\ftp341_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: ALIAS-REN, ALIAS-UP, SAME-REN, MULTI-REN, SEED-ALIAS, SEED-SAME ROW and END PASS
   (12 / 0); on `main` ALIAS-REN and ALIAS-UP FAIL (`probe/result_main.txt`); with the fan-out
   disabled ALIAS-REN, ALIAS-UP, MULTI-REN, SEED-ALIAS FAIL (`probe/result_negative.txt`); with the
   panel-listing check disabled SEED-ALIAS FAIL (`probe/result_negative_seed.txt`). MULTI-REN needs a second server on
   127.0.0.2 serving the same folder (`probe/ftpmini_at.py`, started by the probe).
4. Regression: feature 323's `ftp302_probe.ps1` -> 16 / 0.
