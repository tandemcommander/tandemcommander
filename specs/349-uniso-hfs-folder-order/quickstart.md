# Quickstart - validating 349-uniso-hfs-folder-order

Prerequisites: WSL Ubuntu (xorriso fetched into `~/tc-xorriso` by the seed script), Python 3, the Debug
build.

1. `.\build.cmd` -> `BUILD SUCCEEDED`.
2. `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestHfsFolderOrder349`).
3. Probe (PowerShell, repository root):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\349-uniso-hfs-folder-order\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\349-uniso-hfs-folder-order\probe\iso349_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: H-OK, H-MOVE, H-LONG, H-CYCLE PASS (on `main`: H-MOVE, H-LONG, H-CYCLE FAIL), registry
   restored identical.
4. Regression: the probes of 322, 329, 332, 333, 339 keep their recorded results.
