# Quickstart - validating 404

1. Build: `.\build.cmd full` (PowerShell, repository root) -> `BUILD SUCCEEDED`.
2. Unit rules: `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` -> `0 failed`.
3. Probe (hidden desktop, registry backed up and restored by the probe):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\404-panel-tabs-rounded-look\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\404-panel-tabs-rounded-look\probe\tabs404_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Rows: LOOK (10 captures vs `probe/evidence/variantF_*.png` (copied from the item, which is deleted at closing); before the change the
   `current_*` images are the control), MOUSE (drag order, cancel by capture loss, press on X without
   release, release on X, release off X), MENU (Move to Other Panel, New Tab as Other Panel, greyed
   rules through the posted commands, refused leave).
4. Regression: `tabs312_probe` -> 33 PASS.
5. By a person (release checklist): real-mouse hover and drag feel, Esc during a drag, Dark theme on
   screen, 125 % / 150 % DPI, High Contrast.
