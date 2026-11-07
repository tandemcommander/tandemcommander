# Quickstart - validating feature 407

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestFindSort407`).
3. Probe on the hidden desktop:

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\407-find-sort-toggle\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\407-find-sort-toggle\probe\find_sort_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: rows `menu-time`, `click-date`, `click-other`, `click-size`, `new-search`, `attr` RUN
   PASS, every END PASS, the registry restored and identical (before the fix: 6 RUN rows FAIL).
4. By hand (optional): Ctrl+F, search a folder with sub-folders, click Date twice - the order
   reverses and the arrow points down; Find again - no arrow.
