# Quickstart - validate 397

1. Build: `.\build.cmd` (PowerShell, repository root) → `BUILD SUCCEEDED`.
2. Unit rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` → `saltests: <n> checks, 0 failed`
   (`TestHexFieldTidy397`, see [contracts/hex-field-tidy.md](contracts/hex-field-tidy.md)).
3. Probe (hidden desktop, registry backed up and restored by the probe):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\397-hex-find-quoted\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\397-hex-find-quoted\probe\hex397_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: `grep-type`, `grep-group`, `grep-mid`, `view-type` PASS (before: 3 FAIL).
4. Regression: `specs\311-find-containing-cut\probe\grep311_probe.ps1` the same way → 26 PASS / 0 FAIL.
