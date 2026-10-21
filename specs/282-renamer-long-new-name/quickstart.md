# Quickstart: validating 282

1. Build: `.\build.cmd` (PowerShell, repository root) - `BUILD SUCCEEDED`.
2. Probe (PowerShell, hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\282-renamer-long-new-name\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\282-renamer-long-new-name\probe\ren_longnew_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: `Rows: PASS 22, FAIL 0, NOT DRIVEN 0`, registry restored and identical (before the
   fix: 12 / 8).
3. Regressions: the probes of 199 (`ren_83_probe.ps1`), 206 (`ren_dir83_probe.ps1`), 207
   (`ren_long_probe.ps1`), 209 (`ren_subdir_probe.ps1`) - all PASS.
4. Manual look (optional): Batch Rename on a file of 90 CJK letters, New name `$(Name)b` - the
   preview shows the long new name, no warning icon.
