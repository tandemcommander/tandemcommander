# Quickstart - validating feature 286

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestFolderShortcut286`: real folder shortcuts in `%TEMP%` - fits, too long, exact limit,
   long folder name, not a shortcut, no `target.lnk`, the old rule as a negative control).
3. Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
4. Probe (hidden desktop, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\286-folder-shortcut-browse\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\286-folder-shortcut-browse\probe\fsc286_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -FixtureBase E:\Projects\tandemcommander\build\probe286 -Label after"
   ```

   Expected: `pick-long` PASS (refused, field unchanged), `pick-ctl` PASS; the folder-shortcut
   route rows INFO (the tree does not list a folder shortcut in an ordinary folder); registry
   restored and identical.
5. Person: a network location whose target needs more than 259 bytes, picked in Configuration >
   Drives > browse -> "The path specified is too long.", the field unchanged (person-step item).
