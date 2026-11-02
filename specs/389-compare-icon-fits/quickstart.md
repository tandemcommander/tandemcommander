# Quickstart - validating 389-compare-icon-fits

Prerequisites: a Debug x64 build (`.\build.cmd`), no other `tandemcommander.exe` running.

From the repository root, in PowerShell:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\389-compare-icon-fits\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\389-compare-icon-fits\probe\fit389_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
```

Expected: `Rows: PASS 10, FAIL 0` (5 RUN rows + 5 END rows); the registry restored and identical.
Before the fix: umc-name1, umc-name2, chi-file FAIL (see `fix-log.md`).

Regression: 291's `mask291_probe.ps1` (34 / 0) and 251's `dlg251_probe.ps1` (42 / 0).

By hand (a person, optional): Configuration > User Menu, an item, Change Icon, paste a path of more
than 86 CJK letters, press Tab - "The path specified is too long.", the text stays.
