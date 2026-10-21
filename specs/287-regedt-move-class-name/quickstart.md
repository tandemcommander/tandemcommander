# Quickstart: validating feature 287

Prerequisites: a Debug x64 build (`build.cmd`), no running `tandemcommander.exe`, PowerShell.

1. Build: `.\build.cmd` -> `BUILD SUCCEEDED`.
2. Probe, Czech (from the repository root, PowerShell tool):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\287-regedt-move-class-name\probe\result_after_czech.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\287-regedt-move-class-name\probe\move287_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Lang czech -OutFile specs\287-regedt-move-class-name\probe\move287_after_czech.txt"
   ```

   Expected: `Rows: PASS n, FAIL 0`, registry restored and identical.
3. The same with `-Lang english`.
4. Negative control: the same probe on the build without the fix (`-Expect before`): the CLASS
   question rows FAIL.
5. Regression: `specs\129-regedt-wide-inserts\probe\wide_probe.ps1` -> PASS 19, FAIL 0.

Row definitions: [contracts/probe-rows.md](contracts/probe-rows.md); fixture: [data-model.md](data-model.md).
