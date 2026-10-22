# Quickstart - validating 298-mask-group-long-mask

1. Build: PowerShell `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (block `TestMaskGroupSplit298`: 300 / 1000 / 3000-byte single masks whole, guard bytes intact, results equal
   the reference copy of the old algorithm for every mask up to 259 bytes).
3. Probe (hidden desktop, registry backed up and restored):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\298-mask-group-long-mask\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\298-mask-group-long-mask\probe\mask298_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`
   Expected: SHORT, MULTI, M300, M1000 all PASS (before: M300 and M1000 FAIL - crash at start).
4. Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
