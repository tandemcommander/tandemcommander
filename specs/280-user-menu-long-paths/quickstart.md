# Quickstart - validating 280

1. Build: `.\build.cmd` (PowerShell, repository root) - `BUILD SUCCEEDED`.
2. Rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` - last line
   `saltests: <n> checks, 0 failed` (includes `TestUserMenuValue280`).
3. Probe (hidden desktop, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\280-user-menu-long-paths\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\280-user-menu-long-paths\probe\um280_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: `Rows: PASS 30, FAIL 0` (before: 15 / 5 - FPRCUT, FPRLONG, MIXDIRECT, LISTFULL,
   CMPLONG), registry restored and identical.
4. Regressions: the probes of 226, 229 and 234 (`specs/226-*/probe/um226_probe.ps1`,
   `specs/229-*/probe/um229_probe.ps1`, `specs/234-*/probe/um234_probe.ps1`) keep their results.
5. A person: the Find window's User Menu with a result in a 260+ byte folder ("too long name",
   nothing runs) - the Find route is a popup menu, not driven on the hidden desktop.
