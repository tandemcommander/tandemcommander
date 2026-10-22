# Quickstart - validating 303-ftp-upload-case-only

Prerequisites: Python (for `ftpmini.py`), the Debug x64 build, no running `tandemcommander.exe`.

1. Build: PowerShell `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> last line
   `saltests: <n> checks, 0 failed` (includes `TestFtpCaseOnlyName303`).
3. Probe (hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\303-ftp-upload-case-only\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\303-ftp-upload-case-only\probe\ftp303_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: CASE-UP, CASE-CZ, CASE-NEW, CASE-OVR rows PASS, END rows PASS, registry restored and
   identical (before the fix: CASE-UP / CASE-CZ / CASE-OVR FAIL, `result_before.txt`).
4. Regressions: `specs\288-ftp-per-server-encoding\probe\ftp288_probe.ps1` and
   `specs\224-ftp-utf8-server-names\probe\ftp224_probe.ps1` the same way - no new FAIL.
