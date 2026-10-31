# Quickstart - 357-uniso-other-layouts

Prerequisites: WSL Ubuntu (genisoimage is fetched into `~/tc-genisoimage` by 334's `mkimg334.sh`), Python,
`build.cmd` done, no `tandemcommander.exe` running.

1. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestIsoPlainLayouts_357`).
2. Probe (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\357-uniso-other-layouts\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\357-uniso-other-layouts\probe\iso357_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS (before: 44 / 16); registry restored and identical.
3. Regressions: the probes of 353, 354, 355 and 356 (`specs/35N-*/probe/iso35N_probe.ps1`) with their recorded
   results.
