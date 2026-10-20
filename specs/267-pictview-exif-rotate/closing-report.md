# Closing report - 267-pictview-exif-rotate
Backlog item: pictview-exif-dialog-and-auto-rotation - PictView: the Exif dialog and auto-rotation never work with the built-in engine
Outcome: closed

## What changed

- `src/plugins/pictview/wicengine.cpp`: the engine reports `PVFF_EXIF` for a JPEG whose decoder
  holds an Exif block (`JpegFrameHasExif`, `/app1/ifd` of frame 0's metadata; no second read of
  the file). The three gates on the flag open: the Exif command (File menu and context menu), its
  enabler, the auto-rotation.
- `src/plugins/pictview/render1.cpp` WM_PAINT: auto-rotation for JPEG + `PVFF_EXIF` +
  AutoRotate; orientation from `WicGetExifOrientation` (WIC, no code-page name, IFD0 only) instead
  of EXIF.DLL's `EXIFGetOrientationInfo`; turned by the tag alone (the old "recorded size" exception
  dropped); the quarter turn posted first, chosen for the picture whatever mirror is on, then the
  mirrors. `ReopenKeepingView` keeps only the user's mirror (`fAutoMirrorHor/Vert` in
  `renderer.h`, review 2 S1).
- `src/common/salexiforient.h` (new): `SalExifOrientTurn` - all eight orientation values (the old
  table had 4, 5, 7 wrong); `saltests` `TestExifOrient267` (41 checks).
- `src/plugins/pictview/thumbs.cpp`: Update Thumbnail keeps 132's own Exif check (the new flag does
  not change its question).
- No UI string, resource, plug-in interface, EXIF.DLL export, registry or installer change.

## Measurements (before / after, commands)

Probe `probe/pv267_probe.ps1` on the hidden desktop
(`powershell -File tools\run_on_hidden_desktop.ps1 ... -File specs\267-pictview-exif-rotate\probe\pv267_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -RealRoot %TEMP%\tc267_samples\repo -OutFile ...`):

- main b6b60a51: `result_before.txt` PASS 32, FAIL 33 (no Exif dialog for any file with Exif;
  orientations 2..8 and the real camera files not turned).
- this feature: `result_after.txt` PASS 80, FAIL 0 (all fixture rows, the reopen rows `keep-*`,
  14 real-file rows; `tif6` INFO unchanged).
- the reopen rows before the S1 fix: `result_keep_before.txt` PASS 12, FAIL 3.
- negative control (the old table for 4 / 5 / 7): `result_negative_control.txt` FAIL 3,
  `saltests` 12 failed; restored: `result_after_recheck.txt` PASS 9 / 0.
- Real set `ianare/exif-samples` (91 JPEG): Exif presence and orientation by WIC equal an own
  walker for 91 of 91 (`real_own.txt`, `real_wic.txt`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd` (Debug x64): `BUILD SUCCEEDED`.
- `saltests`: `saltests: 24757 checks, 0 failed`.
- Probes: 267 80 / 0; regressions 132 Update Thumbnail `regress_thumb132_267.txt` 16 / 0 / 1 not
  driven (UNI needs a volume without short names); 120 `regress_pv120_267.txt` 20 / 0 / 2 not driven
  (pipette), re-run after the S1 fix the same. Registry restored identical in every run.

## Reviews (findings and what was done)

- Review 1: interrupted (the session ended while its own probe ran) - no report. It left the
  registry backup `%TEMP%\tc267_backup.reg` (restored, verified identical, removed) and had
  fast-forwarded `main` to the branch against its instructions (not moved back - a forced move is
  outside a run's rules; nothing pushed).
- Review 2 (fresh, diff against b6b60a51): no MUST. S1 (automatic turn applied twice when a
  window reopens its file keeping the view) fixed with probe rows; N1 (no toolbar button for the
  command) fixed in the documents; N2 / N3 accepted and recorded; N4 handled at closing.

## Owed to a person (with the new person-step items)

- `pictview-check-the-exif-information-menu-item-is-offered`: the menu item enabled / grayed, the
  Exif window, an upright photo shown upright.

## New Inbox items (slug - title)

- `pictview-no-exif-command-and-no-automatic-turn-for-tiff-and` - PictView: no Exif command and
  no automatic turn for TIFF and camera raw files
- `pictview-check-the-exif-information-menu-item-is-offered` - PictView: check the Exif
  information menu item is offered only for photos with Exif
