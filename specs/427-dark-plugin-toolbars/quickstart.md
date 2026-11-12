# Quickstart - validating 427

1. `build.cmd` → `BUILD SUCCEEDED`; `saltests.exe` → `0 failed` (the `ThemeDarkAdaptBitmap` check).
2. Close every Tandem Commander instance (the probe refuses otherwise), then from the repository root:

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\427-dark-plugin-toolbars\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\427-dark-plugin-toolbars\probe\dark427_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Repo . -Label after"
   ```

   Rows (Dark and Default): `PV-TOOLBAR` (glyph pixels darker than the strip), `FC-TOOLBAR`,
   `FC-GREY` (light-grey pixels outside the text views), `PV-LABELS`, `RN-LABELS` (contrast >= 4.5),
   `DEFAULT-SAME` (Default captures equal to the before run); `registry restored+identical: True`.
3. Before / after: the same probe on a build of `main` (`-Label before`).
