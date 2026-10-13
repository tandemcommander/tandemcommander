# Quickstart: validating feature 128

```powershell
build\tandemcommander\Debug_x64\saltests\saltests.exe     # all checks pass (TestShellLink128 among them)

powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_on_hidden_desktop.ps1 -Log $env:TEMP\tc128.log -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\tandemcommander\specs\128-shortcut-target-unicode\probe\lnk_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile E:\Projects\tandemcommander\specs\128-shortcut-target-unicode\probe\lnk_result.txt"
```

Expected: `PASS 18, FAIL 0`; the control (`-Expect before` on `Debug_x64_v019`) fails 7 rows.

By hand: in Windows Explorer create a shortcut to a folder such as `D:\Účetnictví`; in the
program press Enter on it (and double-click it) - the panel shows the folder.
