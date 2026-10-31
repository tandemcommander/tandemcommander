# Quickstart - validating 348-ftp-lock-user-port

Prerequisites: Python 3 on PATH, a Debug x64 build (`.\build.cmd`), no running
`tandemcommander.exe`, ports 2148 / 2149 free.

Run (PowerShell, repository root, hidden desktop):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\348-ftp-lock-user-port\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\348-ftp-lock-user-port\probe\ftp348_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

Expected: `Rows: PASS 10, FAIL 0` - OTHER-USER, OTHER-PORT, ALL-OTHER: 1 STOR hold.txt, 0 while
another was in flight, upload 2 refused by the lock ("Target File Is Locked By Another
Operation"), server file 'UP1'; ALIAS-LOCK and SAME-LOCK PASS; registry restored + identical.
Before the fix: PASS 7, FAIL 3 (`probe/result_main.txt`).

Regressions: 341's `ftp341_probe.ps1` (12 / 0), 345's `ftp345_probe.ps1` (16 / 0), 347's
`ftp347_probe.ps1` (6 / 0) - same command shape, their own folders.
