# Quickstart - 365

Prerequisites: WSL Ubuntu (genisoimage is fetched into `~/tc-genisoimage` by the seed script), Python 3,
the Debug x64 build.

1. `.\build.cmd` -> `BUILD SUCCEEDED`.
2. `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestNrgEtn365`, `TestIsoCcdToc365`).
3. Probe on the hidden desktop (PowerShell, from the repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\365-nrg-ccd-track-tables\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\365-nrg-ccd-track-tables\probe\iso365_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: `Rows: PASS 18, FAIL 0` (before: 12 / 6), registry restored and identical.
4. Regressions: `specs\352-uniso-ccd-session-bounds\probe\iso352_probe.ps1` (R-ABS now fails its old
   "kept" expectation by design - both sessions extracted, image deleted; every other row PASS),
   `351`, `334`, `335`, `353` probes as recorded.
