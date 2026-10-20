# Quickstart - validating 270-mask-filter-label-fits

Prerequisites: a Debug x64 build (`build.cmd`), no other `tandemcommander.exe` running.

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\270-mask-filter-label-fits\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\270-mask-filter-label-fits\probe\mask270_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
```

Expected: every row PASS (`vol` NOT DRIVEN when the probe runs elevated); the last line reports the
registry restored and identical. Before the fix (11e20a84): `sel-mask`, `unsel-mask`, `conv-mask`,
`flt`, `flt-unused`, `vol`, `hp-label` FAIL.

Regression: feature 251's probe (`specs/251-dialog-text-fits/probe/dlg251_probe.ps1`) 42 / 0.
