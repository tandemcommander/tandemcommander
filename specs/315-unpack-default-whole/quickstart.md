# Quickstart - feature 315

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`.
3. Probe (hidden desktop, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\315-unpack-default-whole\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\315-unpack-default-whole\probe\unpack315_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS (other-ascii, other-cjk, alt-ascii, alt-cjk, subdir, src-long, ctl,
   ctl-alt, ctl-subdir); registry restored and identical.
4. Regression: 299's probe `specs\299-unpack-dialog-text-fits\probe\unpack299_probe.ps1` -> 12 / 0.
