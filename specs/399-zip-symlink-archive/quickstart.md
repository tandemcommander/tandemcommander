# Quickstart - validating 399-zip-symlink-archive

Prerequisites: symbolic links can be made without elevation (Developer Mode); no other
`tandemcommander.exe` running.

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestSafeReplace399`: the pure rule, path cleaning, a real link replace: the target file updated,
   the link still a link).
3. Probe (hidden desktop, registry backed up and restored by the probe):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\399-zip-symlink-archive\probe\result_after_run.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\399-zip-symlink-archive\probe\zipsymlink_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after -OutFile specs\399-zip-symlink-archive\probe\result_after.txt"
   ```

   Expected: `Rows: PASS 18, FAIL 0` - the four link rows now update `real\a.zip`, the link kept,
   nothing new; the controls as before (before: 14 / 4).
4. Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
