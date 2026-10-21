# Quickstart - validating 277-ftp-pwd-path-cut

Prerequisites: Python 3 (for `ftpmini.py`), the Debug x64 build.

1. `build.cmd` (PowerShell) - `BUILD SUCCEEDED`.
2. `build\tandemcommander\Debug_x64\saltests\saltests.exe` - `saltests: <n> checks, 0 failed`
   (includes `TestFtpPwdReply277`).
3. Probe (PowerShell, hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\277-ftp-pwd-path-cut\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\277-ftp-pwd-path-cut\probe\ftp277_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: AIX, CP, R301 refused (local lnk\x.txt missing, a working-path error), R300 and CTL
   download the right file; END rows PASS; registry restored and identical.
4. Regressions: `specs/215-ftp-long-name-command/probe/ftp215_probe.ps1` and
   `specs/233-ftp-long-server-paths/probe/ftp233_probe.ps1` give their recorded results.
