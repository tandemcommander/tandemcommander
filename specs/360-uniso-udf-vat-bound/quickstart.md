# Quickstart - validating 360-uniso-udf-vat-bound

Prerequisites: WSL Ubuntu (mkudffs fetched once by `specs/356-uniso-udf-rest/probe/mkudf356.sh`), Python,
the Debug x64 build.

1. Build and unit rules (PowerShell, repository root):

   ```text
   .\build.cmd                                                          → BUILD SUCCEEDED
   & "build\tandemcommander\Debug_x64\saltests\saltests.exe"            → saltests: <n> checks, 0 failed
   ```

2. The probe (hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\360-uniso-udf-vat-bound\probe\run_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\360-uniso-udf-vat-bound\probe\iso360_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after -OutFile specs\360-uniso-udf-vat-bound\probe\result_after.txt"
   ```

   Expected: every RUN and END row PASS (before: 9 RUN rows FAIL - `probe/result_before.txt`); the registry
   restored and identical.

3. Regressions: `specs/358-uniso-udf-vat-missing/probe/iso358_probe.ps1` (52 / 0) and
   `specs/359-uniso-udf-vat-cut/probe/iso359_probe.ps1` (its recorded result).
