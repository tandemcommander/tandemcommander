# Quickstart - validating 325-tar-listed-hard-links

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestTarLink325`).
3. Probe (hidden desktop, Python 3 with `tarfile`):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\325-tar-listed-hard-links\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\325-tar-listed-hard-links\probe\link325_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`
   -> every row PASS (before: 7 FAIL - `probe/result_before.txt`).
4. Regression probes: `specs\309-tar-link-members\probe\link309_probe.ps1` (16 / 0),
   `specs\308-pax-deep-unpack\probe\unp308_probe.ps1` (12 / 0), `specs\306-tar-pax-headers\probe\pax306_probe.ps1`
   (30 / 0), the 321 probes - unchanged results.
5. By hand (optional): make a tar with `tar -cf t.tar a.txt sub` where `sub\b.txt` is a hard link of
   `a.txt` (`fsutil hardlink create`), open `t.tar\sub` in the panel: `b.txt` is listed with the size
   of `a.txt`; Copy it alone to a folder: its content is that of `a.txt`.
