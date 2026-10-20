# Quickstart: validating 254

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`.
3. Probe (hidden desktop; registry backed up and restored by the probe):

   ```
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\254-renamer-regex-letters\probe\log_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\254-renamer-regex-letters\probe\ren_regex_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile specs\254-renamer-regex-letters\probe\result_after.txt"
   ```

   Expected: every RUN and END row PASS (19 + 19), registry restored identical.
4. Regressions: 210's `ren_search_probe.ps1` (16 / 0), 196 `ren_cs_probe.ps1`, 199
   `ren_83_probe.ps1`, 206 `ren_dir83_probe.ps1`, 207 `ren_long_probe.ps1`, 208
   `ren_case_probe.ps1`, 209 `ren_subdir_probe.ps1` - all PASS.
5. Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
