# Quickstart - validating feature 306

1. Build: `build.cmd` (Debug x64) - `BUILD SUCCEEDED`.
2. Unit rules: `build\tandemcommander\Debug_x64\saltests\saltests.exe` - `0 failed`
   (TestPaxHeader306).
3. Probe (PowerShell, hidden desktop; needs Python on PATH):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\306-tar-pax-headers\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\306-tar-pax-headers\probe\pax306_probe.ps1 -Label after -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: every row PASS (before: 9 FAIL / 13 PASS, `probe/result_before.txt`).
4. Regression: the probes of 252 (`arc252_probe.ps1`), 273 (`arccase273_probe.ps1`) and 275
   (`arcmember275_probe.ps1`) keep their after results.
5. Negative control: the reader's PAX branch disabled - PAX rows FAIL again.
