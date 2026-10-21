# Quickstart - validating 292

1. Build: PowerShell `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Pure rule: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (`TestRegKeyId292`).
3. GUI (hidden desktop, registry backed up and restored by the probe):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\292-regedt-alias-move-self\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\292-regedt-alias-move-self\probe\alias292_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile specs\292-regedt-alias-move-self\probe\alias292_after.txt"
   ```

   Expected: every row PASS (ALIASMOVE, ALIASCOPY, ALIASINTO, ALIASVALUE, HKCRMOVE refused with the
   fixture unchanged; ALIASRENAME, ALIASOTHER, MOVE, MOVESELF, SAMEMOVE as before), the registry
   restored identical. The same probe with `-Lang czech` checks the translated messages.
4. Before the fix (`-Expect before`, measured at 9781daee): 18 PASS / 9 FAIL - the data-loss rows
   lose the key or the value.
