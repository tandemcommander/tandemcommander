# Research for feature 105: PictView Save As deletes the file it replaces

Branch `105-pictview-saveas-loss` (from `104-plugin-unicode-names`, HEAD 6d22c02f), 2026-10-04.
Machine: Windows 11 10.0.26200, ACP 1250, Czech Windows UI, user not elevated. Pre-change build
preserved as `build\tandemcommander\Debug_x64_pre105`. Scratch measurement programs (not in the
repository, session scratchpad): `m105.cpp` (encoder pixel formats and options, TIFF compression
tags, comments, the replace primitives), `m105b.cpp` (palettes, GIF/BMP/PNG/TIFF bit depths,
DPI), `m105c.cpp` (the bytes a comment becomes). The committed probe
`probe/saveas_probe.ps1` drives the program on the hidden desktop.

The defect (found by 104, `specs/NEXT-WORK.md` item 5, sub-item 5 queue, entry 1): PictView's
*Save As* onto an existing file asks "replace?", deletes the file on *Yes*, then fails with
"Unable to save the image" - the WIC engine of feature 006 cannot write images.

## 0. Headline

1. **The premise is right, and the defect is wider: Save As has never saved anything since
   feature 006.** On the build before this feature every one of the 14 types the dialog offers
   for a color image (CEL, IFF, GIF, JPEG, PNM, PNG, SGI, Sun Raster, Targa, TIFF, Utah RLE,
   SKA, BMP, PCX) ends with "Unable to save the image. Error: This operation is not supported
   by the built-in image engine." A new name creates nothing. An existing name is **deleted
   first** - in every format (probe rows `over-*` on the pre-105 build: all five files gone),
   also inside a folder that denies creating files (row `acl`: deleting needs no right to
   create, so the old code deleted and then could not write) and in the cancel case (row
   `cancel`). Cause, in `saveas.cpp`: the existence check opened the target, the answer *Yes*
   ran `DeleteFileW`, and only then `SaveImage` -> `PVSaveImage`, which the engine stubs
   (`WicSaveImage` accepts only the raw in-memory output of the panel thumbnails) - and
   `PVIsOutCombSupported` returned 0 = "supported" for everything, so the dialog offered every
   format, depth and compression.
2. **Not lost on the build before** (for the record): a file another program holds open (the
   old existence check opened it with share mode 0 and failed with 32, the delete failed too)
   and the image shown in the window (the WIC decoder holds it open; "in use"). A read-only
   file never reaches PictView: **Windows' own Save dialog refuses it** ("This file is set to
   read-only. Try again with a different file name.", measured on both builds) - PictView's
   read-only question is unreachable through the dialog.
3. **Windows writes five of the formats**: the built-in WIC encoders are BMP, PNG, JPEG, GIF,
   TIFF (plus JPEG XR, HEIF, DDS - never offered by the dialog). Measured what each accepts
   (section 2); the dialog's options map onto them except GIF interlacing/GIF87a and TIFF strips.
4. **`ReplaceFileW` keeps the target intact on every failure measured** (read-only 5, held open
   32, missing 2) and keeps its attributes; without a backup name its one dangerous failure
   (`ERROR_UNABLE_TO_MOVE_REPLACEMENT`) leaves the target gone - handled by moving the new file
   in (section 4).
5. **Other write routes** (section 3): two more "delete, then write" sites - *Regenerate
   thumbnail* and the overwrite branch of PictView's *Rename* - both unreachable on either
   build; fixed anyway (same rule). Wallpaper fails before writing. Nothing else in PictView
   writes over a file.

## 1. The Save As flow on the build before (saveas.cpp, 6d22c02f)

| Step | Code | Effect |
|---|---|---|
| dialog | `SaveAsDialogU8` (104) with `IDS_SAVEASFILTERCOLOR` (14 types) / `MONO` (17) | every type offered; `FillTypeFmt` asks `PVIsOutCombSupported` per depth/compression - the stub returns 0 ("supported") for all |
| existence | `CreateFileW(GENERIC_READ|GENERIC_WRITE, share 0, OPEN_EXISTING)` | exists -> "replace?"; `ERROR_ACCESS_DENIED` + read-only -> the read-only question, then `ClearReadOnlyAttr` |
| **delete** | `DeleteFileW(target)` on *Yes* | **the file is gone** (failure -> error box, OK = new name) |
| write | `SaveImage` -> `PVW32DLL.PVSaveImage(file name)` | `WicSaveImage`: not `PVSF_USERDEFINED_OUTPUT` -> `PVC_UNSUP_OUT_PARAMS` |
| report | `IDS_SAVEERROR` + `PVGetErrorText` | "Unable to save the image. Error: This operation is not supported by the built-in image engine." |

Reachability: the File menu item and the toolbar button were removed by 006 (T024: "Save As has
no engine backing"), but the accelerator **Ctrl+S** (`pictview.rc2`) and `CMD_SAVEAS` stayed;
capture/clipboard/scan images reach it through `CMD_INTERNAL_SAVEAS` too.

## 2. What the Windows encoders write (m105, m105b, m105c)

Requested pixel format -> what `IWICBitmapFrameEncode::SetPixelFormat` returns ("=" accepted):

| Encoder | BlackWhite | 1bppIdx | 4bppIdx | 8bppIdx | 8bppGray | 555 | 565 | 24bppBGR | 32bppBGR |
|---|---|---|---|---|---|---|---|---|---|
| BMP | 1bppIdx | = | = | = | 8bppIdx | = | = | = | = |
| PNG | = | = | = | = | = | 24bpp | 24bpp | = | 24bpp |
| JPEG | 8bppGray | 24bpp | 24bpp | 24bpp | = | 24bpp | 24bpp | = | 24bpp |
| GIF | 8bppIdx | 8bppIdx | 8bppIdx | = | 8bppIdx | 8bppIdx | 8bppIdx | 8bppIdx | 8bppIdx |
| TIFF | = | = | = | = | = | 24bpp | 24bpp | = | 24bpp |

Options (`IPropertyBag2`): BMP `EnableV5Header32bppBGRA`; PNG `InterlaceOption`, `FilterOption`;
JPEG `ImageQuality`, `JpegYCrCbSubsampling` (and tables); GIF none; TIFF
`TiffCompressionMethod`, `CompressionQuality`.

TIFF `TiffCompressionMethod` -> tag 259 written: DontCare 5 (LZW), None 1, CCITT3 3, CCITT4 4,
LZW 5, RLE **32773 (PackBits)**, ZIP 8 (Deflate), LZWHDifferencing 5. CCITT turns any input into
BlackWhite (so it is offered only with 2 colors).

JPEG subsampling option: 3 = 4:4:4 (SOF luma sampling 0x11), 2 = 4:2:2 (0x21); quality changes
the size (probe `jpg-q`: 10 -> 696 bytes, 95 -> 993 bytes for 40 x 30).

GIF: always `GIF89a`, a 2- or 16-entry palette goes into 8bppIndexed (local color table of 4 /
16 entries), no DPI (96 read back), no interlace option. Palettes: `InitializeFromBitmap(n)`,
`InitializePredefined(FixedBW / FixedGray256)` work with every encoder above; BMP 1/4/8-bit and
gray, PNG/TIFF BlackWhite/4/8-bit/gray, JPEG gray all decode back with the expected size.

Comments - the bytes in the file for "Koment" + U+00E1 U+0159 + " " + U+65E5 U+672C:

| Query | VT_LPSTR (UTF-8 given) | VT_LPWSTR |
|---|---|---|
| JPEG `/com/TextEntry` | the UTF-8 bytes | E_INVALIDARG |
| GIF `/commentext/TextEntry` | the UTF-8 bytes | E_INVALIDARG |
| PNG `/tEXt/{str=Comment}` | the UTF-8 bytes | **code page: `E1 F8 20 3F 3F`** (the CJK as `?`) |
| PNG `/iTXt/TextEntry` (+ `/iTXt/Keyword`) | E_INVALIDARG | **UTF-8** (the iTXt rule) |
| TIFF `/ifd/{ushort=270}` | the UTF-8 bytes | **code page** (`?`) |

(The first measurement printed the read-back through a console and looked like UTF-8 - the byte
dump `m105c` corrected it; the first build of the fix wrote PNG/TIFF comments as `?`, caught by
probe rows `cmt-png`/`cmt-tif`.) Decision: UTF-8 bytes for JPEG, GIF, TIFF; PNG `tEXt` when the
comment is ASCII, else `iTXt` (UTF-8 by the PNG rules).

## 3. Every PictView route that writes a file

| Route | Code | Writes over an existing file? | Pre-105 | 105 |
|---|---|---|---|---|
| Save As (Ctrl+S, `CMD_SAVEAS`, `CMD_INTERNAL_SAVEAS` for capture/clipboard/scan) | `saveas.cpp OnFileSaveAs` | **yes: delete, then write (always failed)** | loss | temp + replace; encoders |
| Wallpaper (center/tile/stretch) | `render2.cpp SaveWallpaper` -> `SaveImage(%WINDIR%\PictView_Wallpaper.bmp)` | would (the engine writes in place) | fails before writing (`PVC_UNSUP_OUT_PARAMS`); `%WINDIR%` is not writable for a user anyway | unchanged (recorded) |
| Regenerate thumbnail (plug-in menu) | `thumbs.cpp UpdateThumbnails`: EXIF.DLL writes `pvXXXX.tmp`, then **`DeleteFile(image)` + unchecked `MoveFile(tmp, image)`**; `FL_OVERWRITE_RO_ALL` + a non-read-only failure looped forever | yes | unreachable: `PVSaveImage` refuses the scaled JPEG thumbnail (and WIC never sets `PVFF_EXIF`) - "Unable to save" per file | one-step replace (`SalReplaceWithTempW`), no endless retry |
| Rename, overwrite branch | `render1.cpp RenameFileInternal`: **`DeleteFileW(target)` + `SalMoveFile`** | yes (another file the user agreed to replace) | unreachable: the viewed file is held open, the first rename fails with 32 (103's finding) | `MoveFileExW(REPLACE_EXISTING)`, read-only restored on failure |
| Copy To | `dialogs.cpp` `SHFileOperationW` | the shell's own overwrite handling | - | unchanged |
| Delete | recycle bin / `SHFileOperationW` | - | - | unchanged |
| Copy (clipboard), print, rotate, mirror, crop (removed), paste/capture/scan | memory only | no | - | unchanged |
| `salpvenv.exe` | not built, not shipped (104) | - | - | - |

Core-facing: the plug-in has no other save command (menu: paste, capture, regenerate
thumbnail, scan).

## 4. The replace primitives (m105, NTFS %TEMP%)

| Case | `ReplaceFileW(target, temp)` | `MoveFileExW(temp, target, REPLACE)` |
|---|---|---|
| plain, target hidden | ok, target keeps `HIDDEN|ARCHIVE` | - |
| target read-only | 5, both intact | 5, both intact |
| target missing | 2, temp intact | - |
| target open `FILE_SHARE_READ` | 32, both intact | 5 |
| target open `READ|DELETE` share | ok | - |
| target held by a WIC decoder (`CreateDecoderFromFilename`) | 32, both intact | 5 |
| ... after the decoder is released | ok | - |
| backup name given / existing | ok, the old content at the backup name (overwritten) | - |

A WIC decoder opens its file readable for others (`FILE_SHARE_READ`), not deletable: opening
`DELETE` fails with 32. So the shown image's file cannot be replaced while its decoder lives.

## 5. Decisions

- Write into `pvXXXX.tmp` (CREATE_NEW, the target's folder, wide `\\?\` path - no MAX_PATH
  limit of the core's `SalGetTempFileName`), flush, close, then replace. Existence is checked
  with `GetFileAttributesExW` (opens nothing, so a file held by another program is asked about
  and then reported "in use" instead of deleted).
- Filter the language's type list instead of changing the 8 translations; keep the stored index
  in whole-list terms (no registry change, the same meaning for older builds).
- The shown file: release the decoder only after the new file is complete, then replace, then
  open the file again (`OpenFile(FileName)`), whatever the result.
- No new UI string (one English engine text "The image could not be written." beside the other
  engine texts); the system's error text says why a step failed.
