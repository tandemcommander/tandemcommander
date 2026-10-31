# Quickstart - 353-uniso-noccd-sessions

Prerequisites: WSL Ubuntu (genisoimage is fetched by 334's `mkimg334.sh`), Python, the Debug build.

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (group `TestIsoNoCcdRest_353`).
3. Probe (PowerShell, hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\353-uniso-noccd-sessions\probe\result_after_debug.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\353-uniso-noccd-sessions\probe\iso353_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: 12 PASS / 0 FAIL - R-NOCCD2 and R-REST17 kept; C-NOCCD, C-REST2, C-REST16, C-COOKED
   deleted; every END row clean; registry restored identical. Before the fix: 10 / 2.
4. Regressions: `specs\352-uniso-ccd-session-bounds\probe\iso352_probe.ps1` (22 / 0) and
   `specs\351-uniso-track-defaults\probe\iso351_probe.ps1` (10 / 0 Debug), same command shape.
