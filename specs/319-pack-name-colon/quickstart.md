# Quickstart - 319-pack-name-colon

Prerequisites: Windows 11 x64, VS 2022, Python; no other `tandemcommander.exe` running.

1. Build: `.\build.cmd` (PowerShell, repository root) → `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` →
   `saltests: <n> checks, 0 failed` (includes `TestPackName319`).
3. Probe (hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\319-pack-name-colon\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\319-pack-name-colon\probe\pack319_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
   ```

   Expected: every row PASS - the colon rows show "The path specified is invalid." and the dialog
   again with nothing new or changed (streams included); the controls pack as before; the registry
   restored and identical. Before the fix: 6 FAIL (`probe/result_before.txt`).
4. Regression: 318's probe (`specs/318-pack-name-trailing-dot/probe/pack318_probe.ps1`) all PASS.
5. By hand (optional): Alt+F5 on a folder, type `report:zip`, OK → the message, the dialog again;
   no file `report` appears in the panel.
