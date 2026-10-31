# Quickstart - validating 347-ftp-lock-two-names

Prerequisites: Debug x64 build (`.\build.cmd`), Python on PATH, no running tandemcommander.exe.

From the repository root, PowerShell:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\347-ftp-lock-two-names\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\347-ftp-lock-two-names\probe\ftp347_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

Expected: ALIAS-LOCK ROW PASS (0 overlapping STOR, upload 2's item "in use"), SAME-LOCK PASS,
OTHER-USER ROW PASS (facts only; still two overlapping STOR - outside the scope), every END PASS,
registry restored and identical. On `main` (794b3207): ALIAS-LOCK FAIL (`probe/result_main.txt`).

Regressions: `specs\341-ftp-upload-cache-alias\probe\ftp341_probe.ps1` (12 / 0) and
`specs\345-ftp-upload-cache-user-port\probe\ftp345_probe.ps1` (16 / 0), same command form.
