# Quickstart - validating 369-nrg-sinf-chunk-size

Prerequisites: WSL Ubuntu with genisoimage (334's `mkimg334.sh`), Python, a Debug x64 build.

1. `.\build.cmd` -> `BUILD SUCCEEDED`.
2. `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestNrgSinf369` included).
3. Probe on the hidden desktop (PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\369-nrg-sinf-chunk-size\probe\result_after_log.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\369-nrg-sinf-chunk-size\probe\iso369_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after -OutFile specs\369-nrg-sinf-chunk-size\probe\result_after.txt"
   ```

   Expected: PASS 10, FAIL 0 (before: 6 / 4) - F-FIT both sessions, image deleted; S-SINF8 /
   S-SINF8TAIL / S-SINF2 `b.txt`, image kept, no box; S-SINF0 both sessions, image kept, no box.
4. Regressions: `specs\340-nrg-session-count\probe\iso340_probe.ps1` (14 / 0),
   `specs\350-*\probe` (its recorded result), `specs\365-nrg-ccd-track-tables\probe\iso365_probe.ps1`
   (22 / 0).
