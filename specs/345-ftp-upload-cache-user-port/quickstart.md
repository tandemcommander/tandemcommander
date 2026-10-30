# Quickstart - validating 345

Prerequisites: Debug x64 build (`build.cmd`), Python on PATH, no `tandemcommander.exe` running.

1. PowerShell, repository root:

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\345-ftp-upload-cache-user-port\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\345-ftp-upload-cache-user-port\probe\ftp345_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Expected: `Rows: PASS 16, FAIL 0` (8 ROW + 8 END), registry restored identical. On `main`
   before the fix: PASS 11, FAIL 5 (`probe/result_main.txt`).
2. Regressions: 341's `specs/341-ftp-upload-cache-alias/probe/ftp341_probe.ps1` (12 / 0) and
   323's `specs/323-ftp-upload-cache-args/probe/ftp302_probe.ps1` (16 / 0), the same way.
3. Negative control: the fix reverted in a copy of the sources -> the five rows FAIL again.
