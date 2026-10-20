# Quickstart: validating 275

1. Build: `.\build.cmd` (Debug x64) -> `BUILD SUCCEEDED`.
2. `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `saltests: <n> checks, 0 failed`.
3. Probe on the hidden desktop (PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\275-arcmember-long-path\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\275-arcmember-long-path\probe\arcmember275_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: VIEWCAP, VIEWDEEP, 7Z, TAR open a viewer; EDITCAP packs the edit back under the whole
   name; OVERLIMIT shows "resulting filename is too long"; CTL opens a viewer. On the build before
   the change the first five rows FAIL (the 520-byte message) - the negative control.
4. Regressions: `specs/260-archive-cache-long-names/probe/cache260_probe.ps1` (ARCCAP now expects
   the viewer) and `specs/222-name-length-units/probe/editname222_probe.ps1` -> all PASS.
