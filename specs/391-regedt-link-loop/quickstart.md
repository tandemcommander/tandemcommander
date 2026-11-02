# Quickstart - validating 391-regedt-link-loop

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Unit rule: `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `saltests: <n> checks, 0 failed`.
3. Probe (PowerShell, repository root, nothing else running the program):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\391-regedt-link-loop\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\391-regedt-link-loop\probe\loop391_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile specs\391-regedt-link-loop\probe\loop391_after.txt"
   ```

   Expected: every row PASS (COPYSELF, COPYCANCEL, COPYANC, COPYCYCLE, COPYELSE, FINDSELF, FINDANC,
   FINDCYCLE, FINDELSE, END rows); the product's registry restored identical; also with `-Lang czech`.
4. Regressions: the probes of 292 (`alias292_probe.ps1`), 294 (`above294_probe.ps1`), 296
   (`link296_probe.ps1`), 297 (`link297_probe.ps1`), 390 (`hkcr390_probe.ps1`) - all PASS.

By hand (a person, optional): under `HKCU\Software\Test` create `A` with a value, and a link `A\L`
pointing at `\REGISTRY\USER\<SID>\Software\Test\A` (needs a tool that creates `REG_OPTION_CREATE_LINK`
keys); copy `A` in the Registry Editor: one "Can't copy a key to itself." box naming `A\L`; Find in
`Test` lists each key once.
