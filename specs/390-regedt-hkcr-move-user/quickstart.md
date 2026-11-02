# Quickstart - validating 390

1. Build: `.\build.cmd` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`
   (includes `TestRegHkcrHalf390`).
3. Probe (hidden desktop, not elevated):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\390-regedt-hkcr-move-user\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\390-regedt-hkcr-move-user\probe\hkcr390_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile specs\390-regedt-hkcr-move-user\probe\hkcr390_after.txt"
   ```

   Expected: MACHUSER / MACHUSERU TEXT + STATE PASS (the box names
   `HKEY_LOCAL_MACHINE\Software\Classes\<X>\<sub>`, the user's copy equals the machine key, the machine
   key unchanged), USERMOVE / USERCLS PASS, every END PASS, registry restored identical.
   Before the fix (129136b4): MACHUSER / MACHUSERU FAIL with "boxes: none".
4. Regression: the probes of 292 (`alias292_probe.ps1`), 294, 296, 297 keep 0 FAIL.
5. Elevated Move (owed to a person): as administrator, move a scratch machine-only HKCR key into
   `\HKEY_CURRENT_USER\Software\Classes\` - it ends in the user's half and is gone from the machine's.
