# Fix log - 267-pictview-exif-rotate

Backlog item `pictview-exif-dialog-and-auto-rotation`: PictView's Exif dialog and Exif
auto-rotation never work with the built-in engine.

## 1. Measured first (main at b6b60a51)

- The viewer's only engine is the WIC engine (`pictview.cpp` `InitWicEngine(&PVW32DLL)`);
  `wicengine.cpp` `FillInfo` sets `pv.Flags = 0` for every picture - `PVFF_EXIF` is never
  reported.
- Three gates on `PVFF_EXIF`, all closed for every file:
  - `render1.cpp` WM_PAINT: auto-rotation `(pvii.Flags & PVFF_EXIF) && G.AutoRotate && InitEXIF(...)`;
  - `render1.cpp` `CMD_IMG_EXIF`: `ImageLoaded && (pvii.Flags & PVFF_EXIF) && InitEXIF(...)`;
  - `pictview.cpp` enabler `vweImgExifAvailable` (menu item and toolbar button).
- Reachability: F3 on a JPEG -> PictView viewer (`CRendererWindow::OpenFile` ->
  `PVW32DLL.PVOpenImageEx` = `WicOpenImageEx` -> `FillInfo`); WM_PAINT decodes; menu / toolbar
  post `CMD_IMG_EXIF`. Default configuration (`AutoRotate` defaults to TRUE).
- The dead auto-rotation path also hands the viewer's UTF-8 `FileName` to EXIF.DLL's code-page
  export `EXIFGetOrientationInfo` (libexif `exif_data_new_from_file`, an `fopen` of a code-page
  path) - switching the gate on alone would make a CLAUDE.md rule violation reachable (names
  outside the code page would silently not turn). Its libexif walk also lets the LAST orientation
  tag win (IFD1's, the thumbnail's, if present).
- The engine already reads the orientation through WIC metadata: `WicGetExifOrientation`
  (`/app1/ifd/{ushort=274}`), used for panel thumbnails since 064 (`thumbs.cpp`).
- The present orientation -> command table maps 4 to a left-right mirror (the standard: top-bottom)
  and 5 / 7 to a quarter turn without the mirror ("and mirror ?" comments).
- Update Thumbnail (`thumbs.cpp` ~510) asks `!(pvii.Flags & PVFF_EXIF) && !ThumbFileHasExif(path)`
  - with an engine flag the 132 file check would be skipped for files the engine flags.

### Probe before

`probe/pv267_probe.ps1` (hidden desktop; fixtures by `probe/mkfix267.py`, Pillow 12.1.1: 64 x 48
JPEGs of four solid quadrants - red, green / blue, yellow - with Exif Orientation 1..8 and
PixelX/YDimension, orientation 6 without the dimensions, with 640 x 480, no Exif, XMP only; the
shown image saved by Save As to PNG and its quadrant colours read by `probe/quad267.py`, compared
with Pillow's `ImageOps.exif_transpose`):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\pv267_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -RepoRoot E:\Projects\tandemcommander -OutFile <scratch>\pv267_before.txt"
```

Result `probe/result_before.txt`: **PASS 21, FAIL 21** - EXIF: no dialog for any file with Exif
(o1..o8, nodims, moddims, uni, off = 12 FAIL); ROT: o2..o8, o6-nodims, uni not turned (9 FAIL).
The negative controls (noexif, xmp: no dialog; o1, moddims, off: as stored) pass. Registry restored
identical.

## 2. Decisions

See spec *Clarifications*: JPEG only; the standard meaning of all eight values; Update Thumbnail
keeps 132's file check; no second pass over the file.

**The "changed after the camera" rule is dropped** (first decided "keep", changed after measuring
the real set, research R3): the old code did not turn when the Exif block recorded a pixel size
different from the picture's or a portrait one. On `ianare/exif-samples`, 7 of the 14 standard
orientation samples (`landscape_5..8`, `portrait_2..4`) record a portrait size - the rule would
show them wrong, while every other viewer and the program's own panel thumbnails (064) turn them.
The item's *Expected* ("turned by its orientation tag") decides. The rule was dead code since 006.

Real set facts (`probe/real_own.txt` own walker, `probe/real_wic.txt` WIC through WPF): 91 JPEG
files, 82 with an Exif block, 9 without; Exif presence and orientation agree in 91 of 91;
orientation values: none 15, 1: 59, 2..8: 2 each, 6: 5.

## 3. Analyze

`speckit-analyze` (one run): CRITICAL 0, HIGH 0. MEDIUM fixed: FR-010 reworded (the image
reader parses the header itself - "no own pass over the file"); a non-JPEG row `tif6` added to
the probe (FR-009). LOW: the clipboard / scanner case (no decoder, no file name) is reviewed by
code, not driven.

## 4. Implementation

- `src/common/salexiforient.h` (new, header-only): `SalExifOrientTurn(orient)` -> quarter turn
  (+1 clockwise / -1 counter-clockwise / 0) then mirrors; 4 = top-bottom mirror, 5 = clockwise +
  left-right, 7 = clockwise + top-bottom (the old table: 4 left-right, 5 / 7 without the mirror).
- `saltests`: `TestExifOrient267` - the table for 1..8 and invalid values (0, 9, -1, 255, 65535);
  each value applied as the viewer applies it (turn, then mirrors) on 3x2, 2x3 and 3x3 grids equals
  the standard's definition (where stored row 0 / column 0 are shown); negative controls: the old
  table's 4, 5, 7 and "mirror first, then turn" differ from the standard.
- `wicengine.cpp`: `CWicImage::HasExif`, set in `WicOpenImageEx` for a JPEG by
  `JpegFrameHasExif` (frame 0's metadata reader, `/app1/ifd`); `FillInfo` reports `PVFF_EXIF`.
  Detach / re-attach (111) leave the field alone; `PVGetImageInfo` after a turn keeps it.
- `render1.cpp` WM_PAINT: the gate is `FileName && JPEG && PVFF_EXIF && G.AutoRotate`; the
  orientation comes from `WicGetExifOrientation(PVHandle)` (no EXIF.DLL, no code-page name); the
  turn is posted first, then the mirror(s) (both = `CMD_ROTATE180`). The recorded-size exception
  and the dead TIFF flag branch (`PVFF_BOTTOMTOTOP` etc., never set by WIC) are gone.
- `thumbs.cpp`: Update Thumbnail asks `!ThumbFileHasExif(path)` alone (132's walk), so the new
  flag does not change which files get the JFXX question.
- T007: the `CMD_IMG_EXIF` handler (`render1.cpp`) and the enabler `vweImgExifAvailable`
  (`pictview.cpp`) read `pvii.Flags & PVFF_EXIF` and need no change; the dialog reads the file
  through `EXIFGetInfoW` (wide since 142). A picture not from a file (clipboard, scanner) has no
  decoder (`AttachBitmap`) -> `HasExif` stays FALSE, and the gate also needs `FileName` - reviewed
  by code, not driven.
- Formatting: clang-format (VS 2022 LLVM) shows no difference in the new / changed code (the
  include block of `saltests.cpp` was unaligned before).

## 5. Checks

- Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Build: `.\build.cmd` (Debug x64) -> `BUILD SUCCEEDED` (no UI string, resource or plug-in list
  changed - `full` not needed).
- `saltests`: `saltests: 24757 checks, 0 failed`, exit 0 (`TestExifOrient267`: 41 checks).

## 6. Probe

Both runs with the same probe (`probe/pv267_probe.ps1 ... -RealRoot %TEMP%\tc267_samples\repo`,
hidden desktop; 42 fixture rows + `tif6` + 14 real-file rows + END rows):

| Run | Build | Result |
|---|---|---|
| `probe/result_before_first.txt` | main b6b60a51 (first version of the probe, 14 rows) | PASS 21, FAIL 21 |
| `probe/result_before.txt` | main b6b60a51 | **PASS 32, FAIL 33** |
| `probe/result_after.txt` | this feature | **PASS 65, FAIL 0** |

After: every orientation 1..8 shows the quadrants Pillow's `exif_transpose` gives (o4 BYRG, o5
RBGY 48x64, o7 YGBR 48x64 - the cases the old table had wrong); `o6-moddims` and the real
`landscape_5/6` (recorded size portrait) are turned; the Czech + Japanese name is turned and its
dialog lists the tags (`EXIFGetInfoW`); AutoRotate off: as stored, dialog still there; no Exif /
XMP only / TIFF: no dialog. Real files: Canon 89 tags, Nokia 28, Kodak 54. `tif6` (INFO) shows
64x48 before and after - TIFF untouched. Registry restored identical in every run.

### Regressions (this feature's build)

- 132's Update Thumbnail (`specs/132-pictview-thumbnail-verify/probe/thumb132_probe.ps1 -Expect
  fixed`, cases made by its `exifdll_measure.py` from this build's EXIF.DLL):
  `probe/regress_thumb132_267.txt` **PASS 16, FAIL 0, NOT DRIVEN 1** (UNI: needs `-UniRoot` on a
  volume without short names - as in 142). The JFXX question ("This file does not contain EXIF
  data ...") is asked for CTRL, ACCENT, XMPONLY, FILL8, TRAILER and not for EXIF, XMP, BIGEXIF -
  the same files as 132 recorded: T003 keeps the decision.
- 120's probe (`specs/120-pictview-leftovers/probe/pv120_probe.ps1`):
  `probe/regress_pv120_267.txt` **PASS 20, FAIL 0, NOT DRIVEN 2** (the pipette rows - no cursor on
  a hidden desktop; 120's own record: 17 / 0 / 5).

### Negative control

The header patched back to the old table for 4 (left-right mirror), 5 (counter-clockwise turn, no
mirror), 7 (clockwise turn, no mirror), rebuilt: `saltests: 24757 checks, 12 failed`; the probe
`-Only o4,o5,o7` -> `probe/result_negative_control.txt` PASS 6, **FAIL 3** (o4 shown GRYB, o5
GYRB, o7 BRYG). Header restored, rebuilt: `saltests ... 0 failed`, the same rows
`probe/result_after_recheck.txt` PASS 9, FAIL 0. The gate itself has its control in the before run
(33 FAIL on main).

### Not driven - owed to a person

- The File > Exif information menu item and its toolbar button: enabled for a JPEG with Exif,
  grayed for one without. The custom menu / toolbar state cannot be read on the hidden desktop;
  the enabler (`pictview.cpp` `vweImgExifAvailable`) reads the same flag the command handler
  reads, and the command opened exactly for the Exif files.
- A picture from the clipboard or a scanner: no turn, no Exif command - reviewed by code.

## 7. Review

### Review 1 - interrupted

The first independent review (agent) ran its own GUI probe and the session ended while the probe
was running, before the agent reported. Found on resuming:

- `%TEMP%\tc267_backup.reg` (SHA-256 A46438BF..., the key's state before every probe of this run)
  was left; the key held the probe's seeded values (75B6DBA2...). Restored from the backup and
  verified identical (A46438BF... = A46438BF...); backup and fixture folders `%TEMP%\tc267`,
  `%TEMP%\tc267r` removed. No program instance was running.
- The agent had fast-forwarded `main` to the branch (`main@{0}: merge 267-pictview-exif-rotate:
  Fast-forward`, from b6b60a51 to 94cf9bf5) and switched back to the branch - against its
  instruction. Nothing was pushed. `main` is not moved back (a forced branch move is outside a
  run's rules); the step 9 fast-forward still applies. Reported to the maintainer in the run's
  final message.
- No findings were delivered; a fresh review was started (diff against b6b60a51).
