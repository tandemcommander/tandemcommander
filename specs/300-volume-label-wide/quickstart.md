# Quickstart - validating 300-volume-label-wide

All commands from the repository root.

1. Build (PowerShell): `.\build.cmd` → `BUILD SUCCEEDED`.
2. Import table (PowerShell, dumpbin of VS 2022 `Hostx64\x64`):
   `dumpbin /imports build\tandemcommander\Debug_x64\tandemcommander.exe | Select-String VolumeLabel`
   → only `SetVolumeLabelW` (before: `SetVolumeLabelA`).
3. Checker (Bash): `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`;
   `python tools/check_encoding.py --rule ansi-api-on-utf8-path` → `TOTAL: 39`, no
   `SetVolumeLabel` line. Negative control: the same report run over a tree where the call is
   `SetVolumeLabel(volumePathWithBackslash, newName)` lists it (see `fix-log.md` for the method).
4. `saltests` (PowerShell): `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` →
   `saltests: <n> checks, 0 failed`.
5. Probe (PowerShell, hidden desktop):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\300-volume-label-wide\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\300-volume-label-wide\probe\vol300_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`
   → rows `vol-fail`, `vol-same`, `vol-long` PASS (unelevated), registry restored identical.
6. Person step (not a run): on a USB stick (or a VHD, elevated), Drive Information, label
   `Zálohy`, OK → Explorer shows `Zálohy`; open Drive Information again → the field shows
   `Zálohy`.
