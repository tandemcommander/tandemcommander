# Quickstart: validating feature 127

Prerequisites: no `tandemcommander.exe` running; Debug tree from `build.cmd full` (language modules).

```powershell
python tools\check_encoding.py --rule mixed-composition          # TOTAL: 0
python specs\127-mixed-template-texts\probe\scan_mixed.py --core  # the inventory, for triage

powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_on_hidden_desktop.ps1 -Log $env:TEMP\tc127.log -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\tandemcommander\specs\127-mixed-template-texts\probe\mixed_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile E:\Projects\tandemcommander\specs\127-mixed-template-texts\probe\mixed_result.txt"
```

Expected: `FAIL 0`. The control (`-Expect before` on `Debug_x64_v019`) fails LOG, STATUS, BOX.

By hand (Czech): Alt+F7 over a folder with a subfolder you may not list
(`icacls <dir> /deny "%USERDOMAIN%\%USERNAME%:(RD)"`), Find Now, open the log - the row reads
`Chyba při čtení adresáře: (5) Přístup byl odepřen.`
