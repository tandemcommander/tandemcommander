# Quickstart - validating 340-nrg-session-count

Prerequisites: WSL Ubuntu (genisoimage is fetched into `~/tc-genisoimage` once by 334's `mkimg334.sh`),
Python, the Debug x64 build.

1. `.\build.cmd` -> `BUILD SUCCEEDED`.
2. `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestIsoSessionTracks_340`).
3. Probe (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\340-nrg-session-count\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\340-nrg-session-count\probe\iso340_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: PASS 14, FAIL 0 (7 rows, each with an END and a RUN line); registry restored, identical.
   Before the fix: PASS 5, FAIL 9 (`result_before.txt`).
4. Regression: 334's `iso334_probe.ps1` and 335's `iso335_probe.ps1` as their fix-logs ran them - the
   same results as their last runs (334: 23 / 1 since 335's intended S-RAW change; 335: 32 / 0).
