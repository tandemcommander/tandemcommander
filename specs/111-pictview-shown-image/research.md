# Research for feature 111: PictView works on the image it shows

Branch `111-pictview-shown-image` (from `110-zip-plugin-name-matching`, HEAD 018ec169), 2026-10-05.
Machine: Windows 11 10.0.26200, ACP 1250, Czech Windows UI, user not elevated, the WebClient
service running. Pre-change build preserved as `build\tandemcommander\Debug_x64_pre111` (an
incremental build of HEAD first - up to date). Scratch measurement program `m111.cpp` (not in the
repository, `%TEMP%\tc111\m`): what the WIC decoders report for 22 fixtures, what the encoders
write for comments. The committed probe `probe/shown_probe.ps1` (+ `pilcheck.py`, `mkfix111.py`)
drives the program on the hidden desktop; `probe/shown_result_pre111.txt` is the build before.

## 0. Headline

1. **Every premise is right, and one more operation was broken: Delete.** On the build before,
   Rename of the shown image fails with 32 for every name (ASCII, Cyrillic, CJK; also onto a
   read-only file the user agreed to replace); **Delete** of the shown image shows the shell's
   "File in use" window and the file stays (not in the backlog); with a second viewer window on the
   same file Save As ("Unable to save the image. Error: (32)"), Rename and Delete all fail. Nothing
   was lost in any of these - they were refused.
2. **The engine's "32-bit for everything" decides three things wrongly**: the alpha question for an
   opaque 32-bit PNG, TIFF or ICO (and for every PNG/TIFF before the dialog), the dialog's default
   depth (24-bit TrueColor for a gray, a 16-color or a bilevel image) and the offers (no "2 colors",
   so no CCITT G3/G4 for a bilevel PNG or even a CCITT G4 TIFF source); and the title and Image
   Information say "16777216 colors" / "TrueColor 24Bit" for every image. The pipette and the
   histogram read the engine's rows by `PVImageInfo::Colors`, so the fix must not change that value
   (section 2).
3. **The wallpaper commands are worse than "cannot work"**: on the build before, Center/Tile/Stretch
   fail to write (`PVSaveImage` refuses file output; the target is `%WINDIR%`) and then - outside the
   `switch`, for every command - call `SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, NULL,
   SPIF_SENDCHANGE)`, documented as reverting to the default wallpaper; Restore and None write the
   `Wallpaper`/`Prev*` values with the code-page `RegSetValueEx` after reading them through the
   core's UTF-8 facade (a non-ASCII path is garbled by Restore). **Measured by reading the code
   only**: running any of the five commands of that build could change the maintainer's desktop
   (section 4).
4. **Comments**: the TIFF comment is UTF-8 in tag 270 only; the JPEG COM segment ends with 00 (both
   reproduced by the probe, read by hand and by Pillow). Windows itself writes UTF-8 into tag 270
   and reads it back as UTF-8 (measured, section 3).
5. **The 105 NIT is real**: after a failed Save As over the shown image the zoom (125 % -> 100 %)
   and the mirror are reset (the reload); after a successful one the zoom too.

## 1. The build before (probe `shown_result_pre111.txt`)

| Rows | Pre-111 |
|---|---|
| `ren-ascii`, `ren-cyr`, `ren-cjk` | "Error Renaming File (32) ... used by another process"; file unchanged |
| `ren-tgtro` (onto a read-only file, overwrite Yes) | the first rename already fails with 32 |
| `ren-locked`, `ren-tgtlocked` | refused (32), nothing changed - the same on both builds |
| `dav-fold`, `dav-plain` (WebDAV) | error 32 (103's finding) - 103's guard in `RenameFileInternal` never reached |
| `del-yes` | shell "Delete file? permanently" Yes -> OperationStatusWindow "Soubor je používán." (file in use); file stays |
| `del-no` | nothing changes (same on both builds) |
| `two-save` | "Unable to save the image. Error: (32)" |
| `two-ren`, `two-del` | 32 / "File in use" |
| `alpha-opq-png/tif/ico` | the alpha question asked |
| `alpha-real-png/tif` | asked (correct) |
| `depth-bl-png`, `depth-bl-tif` | TIFF depths 16/256/gray/24, default 24-bit; no CCITT |
| `depth-gray`, `depth-pal16`, `depth-bl-title` | default 24-bit; title "16777216 colors"; the gray PNG also asked the alpha question |
| `cmt-tif-u8` | tag 270 = UTF-8 + NUL, no XMP; Pillow shows `Koment\xc3\xa1...` |
| `cmt-jpg-u8`, `cmt-jpg-ascii` | COM = text + `00` |
| `view-fail` | zoom 125 -> 100, mirror lost after the failed replace |
| `view-ok` | zoom 125 -> 100 after the save (the mirrored image correctly in the file) |
| `wp-*` | NOT DRIVEN (section 4) |

## 2. What the decoders report (m111 `fmt`, fixtures by Pillow)

| Fixture | WIC pixel format | bpp | transparency | palette (n, gray, b/w, alpha) | pixels not opaque |
|---|---|---|---|---|---|
| bilevel.png | BlackWhite | 1 | 0 | - | 0 |
| bilevel_g4.tif | BlackWhite | 1 | 0 | - | 0 |
| bilevel.bmp | 1bppIndexed | 1 | 0 | 2, gray, b/w | 0 |
| bilevel.gif | 8bppIndexed | 8 | 0 | 256, gray (Pillow pads the table) | 0 |
| gray.png/.tif/.jpg | 8bppGray | 8 | 0 | - | 0 |
| pal16.png | 4bppIndexed | 4 | 0 | 16 | 0 |
| pal256.png/.gif | 8bppIndexed | 8 | 0 | 256 | 0 |
| pal_trns.png | 4bppIndexed | 4 | **0** | 16, **alpha 1** | 100 |
| rgb.png/.tif/.bmp/.jpg | 24bppBGR | 24 | 0 | - | 0 |
| rgba_opaque.bmp | 32bppBGR | 32 | 0 | - | 0 |
| rgba_opaque.png/.tif, icon_opaque.ico | 32bppBGRA | 32 | 1 | - | **0** |
| rgba_alpha.png/.tif, icon_alpha.ico | 32bppBGRA | 32 | 1 | - | 600 / 544 |

Consequences: `IWICPixelFormatInfo2::SupportsTransparency` is the alpha-channel test (0 for indexed
formats even with a transparent color, 0 for `32bppBGR`); the palette's size, not the pixel
format, gives the color count (a GIF's table may be padded - Pillow writes 256 entries for two
colors; a real two-color GIF table counts 2); "alpha really used" needs the pixels - the decode
already composites every pixel over the background, so `CompositeOverBackground` returns whether
one was not opaque, at no extra cost.

Consumers of `PVImageInfo::Colors` (grep): the title (`render1.cpp SetTitle`), Image Information
(`dialogs.cpp`, also `TotalBitDepth`), Save As (question, mono list, `FillTypeFmt`), the wallpaper
(`render2.cpp`), and **the pixel readers** `GetRGBAtCursor` / `CalculateHistogram`
(`PixelAccess.cpp`), which interpret the rows by it (palette index for <= 256, 2 bytes for 15/16-bit).
So `Colors` must keep describing the rows; the source format is a separate query.

## 3. Comments (m111 `cmt`; bytes read by hand; Windows property system; Pillow)

| Query / value | Written |
|---|---|
| JPEG `/com/TextEntry`, VT_LPSTR | `FF FE 00 14` + UTF-8 + **`00`** |
| JPEG `/com/TextEntry`, VT_BLOB | E_INVALIDARG |
| GIF `/commentext/TextEntry`, VT_LPSTR | the UTF-8 bytes, **no NUL** |
| TIFF `/ifd/{ushort=270}`, VT_LPSTR | tag 270, type ASCII, UTF-8 + NUL |
| TIFF `/ifd/xmp/dc:description`, VT_LPWSTR | `<dc:description>` as a simple property (not the lang-alt XMP defines) |
| TIFF `/ifd/xmp/dc:description/x-default` | WINCODEC_ERR_PROPERTYNOTFOUND |
| TIFF `/ifd/xmp/<xmpalt>dc:description/x-default`, VT_LPWSTR | **`<dc:description><rdf:Alt><rdf:li xml:lang="x-default">` text** - correct XMP; combines with tag 270 |
| TIFF policy `System.Title`, VT_LPWSTR | **tag 270 = UTF-8**, XMP dc:title + dc:description (lang-alt), XPTitle (UCS-2) |
| TIFF policy `System.Comment` | XPComment (tag 40092, UCS-2) only |
| TIFF policy `System.Subject` | nothing |

Read back by the Windows property system (`Shell.Application ... ExtendedProperty`): tag 270 UTF-8
only -> Title and Subject show the text correctly (Windows reads tag 270 as UTF-8); XMP only ->
Title correct, Subject empty; both -> both correct; ASCII -> both. Pillow decodes ASCII tags as
Latin-1, so it shows UTF-8 in tag 270 as `Koment\xc3\xa1\xc5\x99 ...`; its XMP is right.

Decision (spec Clarifications): ASCII stays ASCII in tag 270 only; other text = tag 270 UTF-8
(Windows' own practice, MWG) + XMP dc:description lang-alt. JPEG: drop the NUL after the commit
(one byte shift of the file behind COM; COM is in the first segments). GIF unchanged.

## 4. The wallpaper path (code reading; never driven)

Pre-111 `render2.cpp`: `SetAsWallpaper` opens `HKCU\Control Panel\Desktop`; Center/Tile/Stretch call
`SaveWallpaper(%WINDIR%\PictView_Wallpaper.bmp)` -> `SaveImage` -> `PVSaveImage` (the WIC engine
refuses file output: `PVC_UNSUP_OUT_PARAMS`) -> "Unable to save the image" box; Restore swaps
`Wallpaper*` with `Prev*`, None backs up and clears. `GetWallpaper` reads with
`SalamanderGeneral->SalRegQueryValueEx` (the core's facade: UTF-8 since feature 004), `SetWallpaper`
writes with `RegSetValueEx` (code page). After the `switch`, for **every** command (also after the
failed save), `SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, NULL, SPIF_SENDCHANGE)`. The
`SystemParametersInfo` reference: `pvParam` "" removes the wallpaper, NULL reverts to the default
wallpaper. Whatever Windows 11 does with NULL, the call changes (or reloads) the desktop of the
session - the probe must never run any wallpaper command of that build (the hidden desktop belongs
to the same window station and shares the user's wallpaper).

New path: the image in memory (what the window shows, mirror included) as a 24-bit BMP via the 105
encoder and safe replace into `%LOCALAPPDATA%\Tandem Commander\PictView_Wallpaper.bmp` (the folder
the crash reports use; created on demand); then the style values, the `Prev*` backup (only when the
current wallpaper is not ours - as before) and `SPI_SETDESKWALLPAPER` with the file's path and
`SPIF_UPDATEINIFILE | SPIF_SENDCHANGE` (Windows stores `Wallpaper` itself). Restore: `SPI` with the
backed-up path (or "" when there is none), None: `SPI` with "". BMP, not PNG/JPEG: no quality loss,
the fastest encoder, what the command always meant to write. The dry-run seam
(`TC_PICTVIEW_WALLPAPER_DRYRUN`) sits in the only two functions that write (`WpRegWrite`,
`WpApply`); the probe refuses to send a wallpaper command unless the seam's name is in
`pictview.spl`, and compares the real registry values and `SPI_GETDESKWALLPAPER` before and after.

## 5. Letting the shown file go - design notes

- 105's `WicDetachSource` releases the decoder; the image stays in memory. 111 adds the way back for
  unchanged content: `WicReattachSource` opens a new decoder on the file's current name and accepts
  it only if the container format and the frame count are those of the released one; the DIB (with
  the viewer's rotations) stays, so no reload, no flicker, zoom and mirror untouched.
- Every viewer window runs in its own thread (`ViewerThreadBody`). Other windows are found in
  `ViewerWindowQueue` (snapshot under its lock) and asked with `SendMessageTimeout(SMTO_NORMAL |
  SMTO_ABORTIFHUNG, 5 s)`: `SMTO_NORMAL` lets the asking thread answer the same request from another
  window meanwhile (no deadlock between two windows operating at once). A window that is loading
  (`Loading` - its decoder may be in use up the stack) answers "cannot" and keeps the file. Because a
  timed-out sent message can still be handled later, the message data (the path, the new name) is a
  heap copy per window that is freed only when the window answered.
- Identity: `IsShownFile` (105: 103's file id, "maybe" = yes) in each window.
- Not chosen: opening the file with `FILE_SHARE_DELETE`. It would let rename and replace succeed
  without any coordination, but a delete would leave a delete-pending name on FAT/exFAT and SMB until
  the viewer closes (POSIX delete semantics only on local NTFS), other programs could rename or delete
  the file under the viewer without it knowing, and the second window would keep showing the old
  content after a Save As from the first.

## 6. Other observations

- `GetRGBAtCursor` and `CalculateHistogram` read 3 bytes per pixel for `PV_COLOR_TC24`/`TC32`, but
  the WIC engine's rows are 4 bytes per pixel (BGRX): the pipette shows the color of another pixel
  (x*3/4) with shifted channels, and the histogram counts misaligned bytes and only 3/4 of each row
  - every release since 006 (code reading; display only, nothing written). Recorded (NEXT-WORK),
  not fixed here.
- The rename of the shown image onto ANOTHER file that a second window shows still fails "in use"
  (that window is not asked - it shows the target, not the file operated on); nothing is lost.
- The GIF comment extension is 7-bit ASCII by the GIF89a specification; 105 writes UTF-8 there (no
  standard alternative in GIF). Recorded.
