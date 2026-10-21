# Quickstart: validating 290

1. Build: PowerShell `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks,
   0 failed` (TestPathTwins290, the extended `SalZipMemberIs` checks).
3. Probe (hidden desktop; registry backed up and restored by the probe):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\290-zip-add-case-twins\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\290-zip-add-case-twins\probe\zip290_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS (before: 6 FAIL - ZIP-ADDDIR, ZIP-ADDFILE, ZIP-ADDFOLDER, ZIP-NEWNAME,
   UNIX-ADDFILE, UNIX-ADDFOLDER).
4. Regression: 110's `specs/110-zip-plugin-name-matching/probe/zipname_probe.ps1` and 271's
   `specs/271-zip-case-twins/probe/zip271_probe.ps1` stay all PASS.
5. Negative control: the twin switch forced off in `MatchFiles` -> the six rows FAIL again.
