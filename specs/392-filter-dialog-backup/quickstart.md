# Quickstart - validate feature 392

Prerequisites: a Debug x64 build (`.\build.cmd`), no other `tandemcommander.exe` running.

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\392-filter-dialog-backup\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\392-filter-dialog-backup\probe\flt392_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
```

Expected: `long-refused` PASS (the next dialog shows 300 of 300 bytes), `short-refused` PASS,
`long-valid` PASS, every END row PASS, registry restored and identical. Before the fix
(`result_before.txt`): `long-refused` FAIL with 259 bytes.
