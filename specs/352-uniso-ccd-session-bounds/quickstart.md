# Quickstart - 352

1. Build: `.\build.cmd` (PowerShell) -> `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestIsoCcdBounds_352`).
3. Probe (WSL Ubuntu needed for the seeds), PowerShell from the repository root:

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\352-uniso-ccd-session-bounds\probe\result_after_debug.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\352-uniso-ccd-session-bounds\probe\iso352_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: 22 PASS / 0 FAIL (R-TWOSEC added by review 1) (main: 8 / 10 before C-NOCCD was added). The controls C-M1 / C-M1M1 extract and delete; R-S0,
   R-S200, R-S257, R-MODEX, R-DUP show "Bad format of .CCD file" and keep the image; R-ABS, R-SPLIT
   keep the image without that box; C-NOCCD (no `.ccd`) shows "Missing .CCD file", extracts and deletes as before; no fatal window anywhere.
4. Regression: `specs\351-uniso-track-defaults\probe\iso351_probe.ps1` -> 10 / 0;
   `specs\334-uniso-session-missing\probe\iso334_probe.ps1` -> as recorded by 351 (23 / 1).
