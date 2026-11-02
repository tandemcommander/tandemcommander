# Quickstart - validating 402

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestIsoXboxEntry402`).
3. Probe on the hidden desktop:
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\402-uniso-xbox-name-bound\probe\result_after_run.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\402-uniso-xbox-name-bound\probe\iso402_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after -OutFile specs\402-uniso-xbox-name-bound\probe\result_after.txt"`
   -> `Rows: PASS 10, FAIL 0` (XD-NAME, XD-OVER1, XD-MAX, XD-SUB: one box, the readable files, image
   kept; XD-EDGE: zz listed, no window, image deleted); registry restored and identical.
4. Regressions: feature 400's `iso400_probe.ps1` (48 / 0, needs WSL Ubuntu for its RD / UD rows) and
   401's `iso401_probe.ps1` (10 / 0), the same way.
