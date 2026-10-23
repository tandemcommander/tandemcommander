# Quickstart - validating feature 328

Prerequisites: WSL Ubuntu (the probe fetches genisoimage / xorriso without root), a Debug build.

1. `.\build.cmd` -> `BUILD SUCCEEDED`
2. `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `0 failed` (TestIsoNameFit328)
3. Probe (PowerShell, repository root):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\328-uniso-refused-entry\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\328-uniso-refused-entry\probe\iso328_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`
   -> `Rows: PASS 12, FAIL 0` (six RUN rows + six END rows)
4. Regressions: `specs\326-uniso-rrip-without-rr\probe\iso326_probe.ps1` (28 / 0, DEEP keeps
   `deep.txt`), `specs\327-uniso-safe-names\probe\iso327_probe.ps1` (77 / 0),
   `specs\322-uniso-hfs-btree-joliet\probe\iso322_probe.ps1` (18 / 0).
