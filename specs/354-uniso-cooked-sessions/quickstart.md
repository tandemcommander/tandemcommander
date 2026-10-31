# Quickstart - validating 354-uniso-cooked-sessions

Prerequisites: WSL Ubuntu (genisoimage is fetched by 334's `mkimg334.sh`, xorriso by
`probe/mkxorriso354.sh`, both without root), Python 3 on Windows.

1. Build: `.\build.cmd` → `BUILD SUCCEEDED`.
2. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` → `saltests: <n> checks, 0 failed`
   (`TestIsoCookedRest_354`).
3. Probe on the hidden desktop (PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\354-uniso-cooked-sessions\probe\result_after_debug.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\354-uniso-cooked-sessions\probe\iso354_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: 28 PASS / 0 FAIL (14 RUN rows + 14 END rows; see the probe's header). Before the fix:
   20 / 8 (`probe/result_before_debug.txt`).
4. Regressions: the probes of 353 (`iso353_probe.ps1`, 16 / 0), 352 and 334 the same way.
