# Quickstart - validating 406

1. `.\build.cmd` -> `BUILD SUCCEEDED`.
2. `& build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `saltests: <n> checks, 0 failed`
   (`TestRegHkcrHalf390`, `TestRegHkcrBoth406`).
3. Probe, hidden desktop, not elevated (English, then `-Lang czech`):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\406-regedt-hkcr-both-halves\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\406-regedt-hkcr-both-halves\probe\hkcr406_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile specs\406-regedt-hkcr-both-halves\probe\hkcr406_after.txt"
   ```

   Expected: BOTHMOVE / BOTHSKIP first box names `HKEY_LOCAL_MACHINE\Software\Classes\<X>\<S>` with
   (5); BOTHSHADOW with (50); both halves unchanged; the copy equals the merged view; BOTHSELF refused;
   registry restored identical. Before the fix: 6 PASS / 7 FAIL.
4. Regression probes: `specs\390-regedt-hkcr-move-user\probe\hkcr390_probe.ps1` (10 / 0),
   292 `alias292_probe.ps1` (33 / 0), 294 `above294_probe.ps1` (24 / 0), 296 `link296_probe.ps1`
   (47 / 0), 297 `link297_probe.ps1` (40 / 0).
5. Owed to a person (elevated): Move of a both-halves scratch key really removes both halves; a hidden
   machine value refuses the machine's half with (50).
