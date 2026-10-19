# Quickstart: validating 251

1. Build: `.\build.cmd` (PowerShell) - `BUILD SUCCEEDED`.
2. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` - `0 failed`, including
   the `SalWTextFitsU8` checks.
3. Probe (hidden desktop, registry backed up and restored by the probe):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\251-dialog-text-fits\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\251-dialog-text-fits\probe\dlg251_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every RUN row PASS (11 refusal rows + `mfl-ctl`), every END row PASS, registry
   restored identical. On the build before (`Debug_x64_pre251`) the refusal rows FAIL.
4. Regression: 214's `specs/214-copy-dialog-text-fits/probe/cm_text_probe.ps1` 4 / 0.
