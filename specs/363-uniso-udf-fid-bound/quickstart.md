# Quickstart - 363-uniso-udf-fid-bound

Prerequisites: VS 2022, Python, WSL Ubuntu (genisoimage is fetched by 330's `mkimg330.sh` into `~/tc-genisoimage`).

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestIsoUdfFid_363`).
3. Probe (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\363-uniso-udf-fid-bound\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\363-uniso-udf-fid-bound\probe\iso363_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: `Rows: PASS 20, FAIL 0, NOT DRIVEN 0`, registry restored and identical. Before (443ee778): 12 / 8.
4. Regressions: the probes of 330, 361 and 362 the same way -> 0 FAIL.
