# Quickstart - 339-uniso-hfs-fork-content

Prerequisites: WSL Ubuntu (332's `mkimg332.sh` fetches xorriso into `~/tc-xorriso` once), Python, no running
`tandemcommander.exe`.

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`; after the strings are added and
   translated `.\build.cmd full`.
2. Rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestHfsFileContent339`).
3. Probe (PowerShell):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\339-uniso-hfs-fork-content\probe\result_after.txt -CommandLine "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File specs\339-uniso-hfs-fork-content\probe\iso339_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`
   -> every row PASS (H-RSRC, H-COMP, H-COMPIN, H-FLAG, H-SKIPALL, H-CANCEL: image kept, side.txt not written,
   the box as expected; H-OK, H-NOMODE, H-BOTH: every file, image deleted), registry restored identical.
4. Regression: `specs\332-uniso-hfs-skipped-records\probe\iso332_probe.ps1` and
   `specs\333-uniso-hfs-part-missing\probe\iso333_probe.ps1` keep 16 / 0 and 20 / 0.
