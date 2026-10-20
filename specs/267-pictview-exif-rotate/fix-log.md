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

See spec *Clarifications*: JPEG only; the standard meaning of all eight values; the "changed after
the camera" rule kept; Update Thumbnail keeps 132's file check.
