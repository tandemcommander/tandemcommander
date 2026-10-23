# Quickstart - validating 323-ftp-upload-cache-args

Prerequisites: Debug x64 build (`build.cmd`), Python on PATH (for the test servers), no running
`tandemcommander.exe`.

1. Build: PowerShell `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rule: PowerShell `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` ->
   `saltests: <n> checks, 0 failed`.
3. Probe on the hidden desktop (PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\323-ftp-upload-cache-args\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\323-ftp-upload-cache-args\probe\ftp302_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: rows MKD-ABS, REN-UP, MKD-REN, REN-PATH, MKD-HID, MKD-CASE PASS, every `END` row
   PASS, registry restored + identical. Negative controls: on `main` MKD-ABS and REN-UP fail; with
   302's state (argument fix + review 1) MKD-HID and MKD-CASE fail.
4. Regressions: `specs\288-ftp-per-server-encoding\probe\ftp288_probe.ps1` -> 20 / 0 as recorded
   by 288.
5. Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
