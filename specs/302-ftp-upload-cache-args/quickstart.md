# Quickstart - validating 302-ftp-upload-cache-args

Prerequisites: Debug x64 build (`build.cmd`), Python on PATH (for `ftpmini.py`), no running
`tandemcommander.exe`.

1. Build: PowerShell `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Probe on the hidden desktop (PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\302-ftp-upload-cache-args\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\302-ftp-upload-cache-args\probe\ftp302_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: `MKD-ABS` PASS (the second upload sends no `MKD new`, `f.txt` arrives in
   `/MKA/other/new`), `REN-UP` PASS (`b.txt` keeps its content), every `END` row PASS, registry
   restored + identical. Before the fix: `MKD-ABS` FAIL, `REN-UP` PASS (masked by the refresh).
3. Regressions: `ftp288_probe.ps1` (and 224 / 277 if time allows) as recorded in their features.
4. Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
