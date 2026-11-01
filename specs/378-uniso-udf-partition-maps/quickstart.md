# Quickstart - 378-uniso-udf-partition-maps

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestIsoUdfMaps_378`).
3. Probe (Tandem Commander closed; hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\378-uniso-udf-partition-maps\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\378-uniso-udf-partition-maps\probe\iso378_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS (C-U201, C-U250 a.txt deleted; C-B201 both folders, kept; R-COUNT, R-LEN0,
   R-TABLE, R-RUN, R-MANY nothing, a window, kept; R-BCOUNT only the ISO 9660 folder, a window, kept);
   registry restored and identical.
4. Regressions: `iso356_probe.ps1`, `iso358_probe.ps1`, `iso361_probe.ps1`, `iso377_probe.ps1` as recorded.
