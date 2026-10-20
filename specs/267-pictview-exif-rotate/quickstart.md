# Quickstart - validating 267

Prerequisites: Debug x64 build (`build.cmd`), Python with Pillow, nothing of Tandem Commander
running. Optional: the public collection `ianare/exif-samples` cloned into its own folder, e.g.
`%TEMP%\tc267_samples\repo`.

1. Rule checks: `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> last line
   `saltests: <n> checks, 0 failed` (includes `TestExifOrient267`).
2. Probe (PowerShell, hidden desktop):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\267-pictview-exif-rotate\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\267-pictview-exif-rotate\probe\pv267_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -RealRoot %TEMP%\tc267_samples\repo -OutFile specs\267-pictview-exif-rotate\probe\pv267_after.txt"
   ```

   Expected: every row PASS (before: 21 FAIL of the 42 fixture rows); registry restored identical.
3. Real-file facts (no GUI): `python -I specs\267-pictview-exif-rotate\probe\real267.py <repo>` and
   `powershell -NoProfile -File specs\267-pictview-exif-rotate\probe\real267_wic.ps1 -Root <repo>`
   agree on Exif presence and orientation.
4. Regressions: `specs\120-pictview-leftovers\probe\pv120_probe.ps1` and
   `specs\132-pictview-thumbnail-verify\probe\thumb132_probe.ps1` - no new FAIL.
5. By a person (not drivable on the hidden desktop): the File > Exif information menu item and
   its toolbar button are enabled for a photo with Exif and grayed for one without.
