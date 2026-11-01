# Quickstart - feature 370

Prerequisites: WSL Ubuntu with genisoimage (feature 334's `mkimg334.sh`), Python, the Debug x64 build.

1. `.\build.cmd` (`full` after the `.slt` refresh) -> `BUILD SUCCEEDED`.
2. `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`.
3. Probe (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\370-nrg-info-sessions\probe\result_after_log.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\370-nrg-info-sessions\probe\iso370_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after -OutFile E:\Projects\tandemcommander\specs\370-nrg-info-sessions\probe\result_after.txt"
   ```

   Expected: 16 of 16 rows PASS (8 images x RUN + END); skeletons
   F-FIT `N2 S1 n1 T1 S2 n1 T2`, F-ZERO `N2 S1 n0 S2 n2 T1 T2`, S-OVER `N2 S1 n1 T1 S2 n1 T2`,
   S-SHORT `N1 S1 n1 T1 U T2`, S-NONE `N0 U T1 T2`, S-NEG `N2 S1 n2 T1 T2 S2 n0`,
   S-NEGEND `N2 S1 n1 T1 S2 n1 T2`, S-EXTRA3 `N2 S1 n1 T1 S2 n1 T2 U T3`. Registry restored identical.
   Before the fix (2c1c1279): PASS 6 / FAIL 10.
4. Regression: feature 340's probe (`specs/340-nrg-session-count/probe/iso340_probe.ps1`) still 14 / 14 PASS
   (the listing is not touched).
