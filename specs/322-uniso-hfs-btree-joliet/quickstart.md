# Quickstart - validating feature 322

1. Build: `.\build.cmd full` (a UI string is added) -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` ->
   `saltests: <n> checks, 0 failed` (includes `TestHfsCatalog322`).
3. Probe (hidden desktop, PowerShell tool):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\322-uniso-hfs-btree-joliet\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\322-uniso-hfs-btree-joliet\probe\iso322_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Rows (valid images only): Joliet ASCII, Joliet CJK, Rock Ridge, plain ISO 9660, HFS+-only list
   + extract, hybrid open. Needs WSL Ubuntu with `~/tc-xorriso`
   (`probe/mkimg322.sh` fetches it); without it the xorriso rows are NOT DRIVEN.
4. Regression: feature 223's `iso223_probe.ps1` 4 / 0.
