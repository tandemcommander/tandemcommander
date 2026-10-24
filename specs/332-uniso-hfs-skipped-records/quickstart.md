# Quickstart - validating 332-uniso-hfs-skipped-records

Prerequisites: a Debug build (`build.cmd`), WSL Ubuntu (the probe fetches xorriso / genisoimage into
`~/tc-xorriso`, `~/tc-genisoimage` once), Python 3 on the PATH.

1. Unit rules (PowerShell):
   `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestHfsRecordClass332` among them).
2. Probe (PowerShell, hidden desktop):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\332-uniso-hfs-skipped-records\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\332-uniso-hfs-skipped-records\probe\iso332_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`
   Expected: H-OK, H-TYPE, H-KEY, H-LONG, H-SHORT, U-OK, U-FILE all PASS (before the fix the four
   damaged H rows FAIL: image deleted); registry restored and identical.
3. Regression probes: `specs/322-*/probe/iso322_probe.ps1`, `328`, `329`, `330` - their earlier results.
