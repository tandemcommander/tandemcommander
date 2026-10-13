# Quickstart: validating feature 129

Prerequisites: no `tandemcommander.exe` running; Debug tree from `build.cmd full`.

```powershell
build\tandemcommander\Debug_x64\saltests\saltests.exe     # all checks pass (TestWideInserts129 among them)

powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_on_hidden_desktop.ps1 -Log $env:TEMP\tc129.log -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\tandemcommander\specs\129-regedt-wide-inserts\probe\wide_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile E:\Projects\tandemcommander\specs\129-regedt-wide-inserts\probe\wide_result_czech.txt"
```

Expected: `PASS 16, FAIL 0` (also with `-Lang english`); the control (`-Expect before` on
`Debug_x64_v019`) fails OPENKEY, VIEW CACHE, CREATE and SELF. Started from the PowerShell 7
tool, set the Windows PowerShell `PSModulePath` first (`Get-FileHash`).

By hand: create `HKCU\Software\Test\Klíč`; in the program go to `reg:\HKEY_CURRENT_USER\Software\Test`,
F5 on `Klíč`, target `\HKEY_CURRENT_USER\Software\Test\Cíl řx\New` - the question names
`...\Cíl řx`; answer No.
