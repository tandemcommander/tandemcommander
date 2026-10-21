# Quickstart: validating 279

Prerequisites: Debug x64 build (`.\build.cmd`), Python with paramiko, Docker Desktop with the
container `tandem-sftp` running (OpenSSH, localhost:2222, user `tctest`).

1. Rule harness: `src\plugins\sftp\test\build_and_run.cmd` -> `N passed, 0 failed`.
2. Feature probe (hidden desktop, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\279-sftp-drop-folder-again\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\279-sftp-drop-folder-again\probe\sftp279_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Rows (see the probe header): DROPDIR, DROPDIR2, DROPAGAIN, DROPHOLE, DROPEMPTY, DROPHOLE2
   (drop test server); OSSHCTL, OSSHLINK, OSSHLINK2 (OpenSSH). Expected: every row PASS, the
   registry restored and identical.
3. Regressions: 258's probe without its row DROPDIR2 (its expectation is the old limit) and
   133's probe on the container: the same counts as before (258: 18 / 0 without DROPDIR2's two
   rows; 133: 76 / 0).
4. Before: the feature probe on the build of 3541e7ad - DROPDIR2, DROPAGAIN FAIL.
