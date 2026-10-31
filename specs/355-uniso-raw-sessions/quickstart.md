# Quickstart - 355-uniso-raw-sessions

Prerequisites: WSL Ubuntu with genisoimage (334's `mkimg334.sh`), Python 3.

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestIsoRawRest_355`).
3. Probe (PowerShell):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\355-uniso-raw-sessions\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\355-uniso-raw-sessions\probe\iso355_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`
   Expected: 40 PASS / 0 FAIL (20 rows, END + RUN each); before the fix 30 / 10.
4. Regressions: the probes of 354 (28 / 0), 353 (16 / 0), 352 (22 / 0), 334 (23 / 1, S-RAW as since 335).
