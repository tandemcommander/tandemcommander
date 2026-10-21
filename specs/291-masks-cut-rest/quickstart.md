# Quickstart - 291-masks-cut-rest

```powershell
.\build.cmd
& "build\tandemcommander\Debug_x64\saltests\saltests.exe"
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\291-masks-cut-rest\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\291-masks-cut-rest\probe\mask291_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
```

Expected: `Rows: PASS 34, FAIL 0, NOT DRIVEN 0`, registry restored identical. Regression: 270's
probe (24 / 0), 251's probe (42 / 0).

By hand (a person): type a long CJK mask list into Configuration > System > "Move following files to
the Recycle Bin" and press OK - "The path specified is too long."; rename a view (Configuration >
Views, F2) to 11 CJK letters - the same message, the old name stays.
