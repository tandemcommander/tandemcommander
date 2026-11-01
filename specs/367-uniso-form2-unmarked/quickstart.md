# Quickstart - 367-uniso-form2-unmarked

Prerequisites: the real vcdimager 2.0.1 output in `%TEMP%\rev335c\data` (`vcd.bin`, `svcd.bin`, `v.mpg`,
`s.mpg`; kept in WSL `~/rev335c` since 335), Python, the Debug x64 build.

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`; `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `0 failed`.
2. Images: `python -I specs/367-uniso-form2-unmarked/probe/img367.py %TEMP%\rev335c\data %TEMP%\tc367img`.
3. Probe (hidden desktop, PowerShell):
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log <log> -CommandLine "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File specs\367-uniso-form2-unmarked\probe\iso367_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -ImgDir %TEMP%\tc367img -Lib specs\098-long-path-overruns\probe\fix_probe_lib.ps1 -Label after"`
   -> every row PASS, registry restored + identical.
4. Expected: C-NOXA / C-MIXED AVSEQ01.DAT 690,228 bytes containing `v.mpg`; C-F1SUB AVSEQ02.DAT 689,952 bytes;
   images deleted as for a real Video CD; the control rows as on main; the damaged-sector row keeps the image.
5. Negative control: the same probe with main's `uniso.spl` - the 367 rows fail.
