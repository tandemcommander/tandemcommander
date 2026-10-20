# Research - 267-pictview-exif-rotate

## R1 Where to decide "the file has an Exif block"

- **Decision**: in the WIC engine, at open, for a JPEG only: `GetMetadataQueryReader` of frame 0
  and `GetMetadataByName(L"/app1/ifd")` succeeds -> `CWicImage::HasExif = TRUE`; `FillInfo`
  reports `PVFF_EXIF`. The flag lives in the image, so `PVGetImageInfo` after a turn, mirror or
  crop keeps reporting it.
- **Rationale**: every consumer already asks `pvii.Flags & PVFF_EXIF` (menu / toolbar enabler,
  the command, auto-rotation) - the engine telling the truth fixes all three at once, as the old
  engine did; the decoder holds the parsed APP segments, so there is no second read of the file
  (FR-010). The renderer's `pvii` is refreshed from the engine after every turn (`PVGetImageInfo`),
  so a flag set by the renderer alone would be lost.
- **Measured** (`probe/real267.py` own walker vs `probe/real267_wic.ps1`, the same WIC query
  language through WPF; files `probe/real_own.txt`, `probe/real_wic.txt`): 91 JPEGs of the public
  collection `ianare/exif-samples` - Exif presence (82 with, 9 without, 7 of them "invalid"
  files) and the orientation agree for **91 of 91**. An XMP-only APP1 is not `/app1/ifd`
  (fixture `xmp.jpg`).
- **Alternatives**: a file check like 132's `ThumbFileHasExif` in the renderer (reads 1 MB of the
  file again per opened picture, and the flag would vanish at the next `PVGetImageInfo`).

## R2 Reading the orientation

- **Decision**: `WicGetExifOrientation` (`/app1/ifd/{ushort=274}`, IFD0 only; 0 when absent or
  outside 1..8) on the viewer's engine handle.
- **Rationale**: the old route passed the viewer's UTF-8 `FileName` to EXIF.DLL's code-page
  `EXIFGetOrientationInfo` (CLAUDE.md: never an `A` path from a UTF-8 name - a name outside the
  code page would silently not turn); libexif's walk also let a later IFD's (thumbnail's) tag
  win. The engine already has the file open. Panel thumbnails use the same function since 064,
  so viewer and thumbnail agree.
- **Alternatives**: a wide twin of `EXIFGetOrientationInfo` (point 4 of the related item; an
  EXIF.DLL export change for a value the engine already has).

## R3 The recorded pixel size (PixelX/YDimension)

- **Decision**: not consulted (spec Clarifications).
- **Measured**: in the real set, `landscape_5..8` and `portrait_2..4` (standard orientation
  samples) record a portrait size - the old exception ("recorded width < height -> do not turn")
  would show 7 of the 14 samples wrong. One Kodak file records the size with a count of 2 (WIC
  returns a vector) - no longer relevant.

## R4 Orientation -> commands

- **Decision** (`src/common/salexiforient.h`): the viewer turns first, then mirrors (its rotate
  command flips its direction when a mirror is active, so the turn must come first):

  | Value | Turn | Mirror | Meaning (Exif / TIFF) |
  |---|---|---|---|
  | 1 | - | - | as stored |
  | 2 | - | left-right | mirrored horizontally |
  | 3 | - | left-right + top-bottom (= 180) | turned 180 |
  | 4 | - | top-bottom | mirrored vertically |
  | 5 | clockwise | left-right | transposed |
  | 6 | clockwise | - | turned 90 clockwise |
  | 7 | clockwise | top-bottom | transversed |
  | 8 | counter-clockwise | - | turned 90 counter-clockwise |
  | other | - | - | as stored |

  Verified by composing the operations on a 2 x 3 grid in `saltests` against the standard's
  definition (row 0 / column 0 placement), and in the probe against Pillow's `exif_transpose`.
- **Old table**: 4 mirrored left-right (wrong), 5 and 7 turned without the mirror ("and mirror ?").
- 3 is posted as `CMD_ROTATE180` (the viewer implements it as both mirrors).

## R5 Update Thumbnail

- **Decision**: `thumbs.cpp` asks `!ThumbFileHasExif(path)` alone - the decision stays exactly
  132's (FR-008); the engine flag would have skipped the file check for files WIC flags.

## R6 What the Exif window lists

- The window still reads the tags through EXIF.DLL (`EXIFGetInfoW`, wide since 142). libexif's
  loader gives up at an unknown block before the Exif one (132: APP12 "Ducky", APP14 "Adobe") -
  such a file gets the command and an empty or partial list. Limit, recorded; not changed here.
