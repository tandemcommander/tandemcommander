# Quickstart - validating 423

1. Build: `.\build.cmd full` (UI strings changed) -> `BUILD SUCCEEDED`.
2. Unit rules: `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `0 failed`
   (`TestTabStrip423`: style mapping, Light DimText contrast >= 7:1 and lighter than text, Dark /
   High Contrast unchanged).
3. Probe (hidden desktop, PowerShell):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\423-square-panel-tabs\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\423-square-panel-tabs\probe\tabs423_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   Rows: DEFAULT (no value -> square corners in Light and Dark, both panels), UNKNOWN (value 7 ->
   square, value kept after Save Configuration), ROUNDED (value 1 -> the 404 corners and feet),
   HOVER (square hover rectangle), PAGE (the Appearance page: Square checked by default; choosing
   Rounded + OK repaints rounded without a restart and stores 1; Square + OK back to 0), TITLE
   (Light inactive title >= 7:1; Dark unchanged), LAYOUT (the page's controls inside 231 du, no
   overlap).
4. Regression: `tabs404_probe` and `tabs413_probe` with `Panel Tab Style` = 1 (they test the
   rounded look) -> as before 423.
5. A person (release checklist): look at both styles in Light and Dark with a real mouse hover.
