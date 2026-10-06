# Research for feature 120: PictView's leftovers of 105 and 111

Branch `120-pictview-leftovers` (from `119-packing-leftovers`, HEAD 7d6ffeb6), 2026-10-06.
Machine: Windows 11 10.0.26200, ACP 1250, Pillow 12.1.1. Pre-change build preserved as
`build\tandemcommander\Debug_x64_pre120` (a copy of `Debug_x64` before the first build of this
feature, `Intermediate` folders removed; PictView unchanged since 111). **No GUI was run** (another
agent drives the hidden desktop; the maintainer uses the installed program) - the GUI probe is
written and owed (`quickstart.md`).

## 0. Headline

1. **The premise is right and the defect is larger than "3 bytes per pixel"**: the harness
   (`probe/pixharness/`, the plug-in's own `wicengine.cpp` + `PixelAccess.cpp` compiled from git
   HEAD) shows the pipette wrong for **3 of 4 pixels of every row** of every image (the WIC engine
   hands out 32-bit rows for every format, so also for 8-bit GIF, 16-color PNG, gray, bilevel), and
   **all five histogram channels wrong for every image**: 2,295 mismatching checks over 9 fixtures.
   The build of this feature: 0.
2. **Two more pipette defects** (code reading, every release): a mirrored image showed the color of
   the pixel opposite the cursor (the viewer mirrors when it draws, the rows are never mirrored);
   the window-to-image mapping overflowed 32 bits for a large image zoomed in (20,000 pixels at
   1600 %: 320,000 x 20,000) - another pixel, and the old reader had no bound (a read outside the
   rows was possible).
3. **105's record "the rotation is lost when the background color changes" is real and visible**:
   the harness turns an image and sets another background color; the build before then holds the
   UNTURNED image (37 x 5 instead of 5 x 37) while the viewer keeps the turned size (drawn
   squeezed, saved unturned, the pipette's rows of another size). Triggered by full screen with a
   different full-screen background color, or by changing the colors in the configuration.
4. **Rename onto a shown target**: code reading confirms 111's record - only the renamed file's
   windows are asked; the replacing `MoveFileExW` meets the target's decoder (no
   `FILE_SHARE_DELETE`) and fails - measured by the GUI run on the build before: error **5**
   (access denied), not the 32 the backlog said. Nothing is lost.
5. **GIF comment**: the Windows GIF encoder writes the bytes as given; there is no Unicode
   alternative in GIF (XMP refused - measured); Windows shows no GIF comment at all.

## 1. Who reads the engine's pixel buffer (code reading)

The WIC engine (feature 006) decodes every frame into a 32-bit top-down DIB, B G R X with X = 255
after compositing over the background (`CompositeOverBackground`), and reports `Colors =
PV_COLOR_TC32`, `BytesPerLine = width x 4` (`FillInfo`), `pLines[y] = DibBits + y x width x 4`
(`BuildLines`), `Palette = NULL` (`WicGetHandles2`).

| Consumer | How it reads | Result |
|---|---|---|
| pipette (status bar `statsbar.cpp`, tooltip `UpdatePipetteTooltip`) | `GetRGBAtCursor` (`PixelAccess.cpp`): 3 bytes per pixel for `Colors >= PV_COLOR_TC24` | **wrong** (pixel x read at byte 3x) |
| histogram (`CMD_IMG_HISTOGRAM` -> `CalculateHistogram`) | 3 bytes per pixel, `Width` pixels per row | **wrong** (misaligned, 3/4 of each row) |
| clipboard copy (`CMD_COPY`) | `PVDrawImage` into a bitmap (GDI) | correct |
| printing | `PVDrawImage` on the printer DC | correct |
| print preview (`print.cpp CreatePreview`) | `PVSaveImage` raw 32-bit with scaling / crop / flips | refused by the WIC engine (`PVC_UNSUP_OUT_PARAMS`, since 006/048) - the preview is empty (**found, recorded**) |
| panel thumbnails (`thumbs.cpp`) | `PVSaveImage` raw 32-bit rows, stride width x 4 | correct |
| Save As, wallpaper (`WicEncodeImageToFile`) | `IWICBitmapSource` over the DIB | correct |
| Image Information "memory" | `BytesPerLine x Height` | correct (the DIB's size) |

No other "get pixel" interface exists (grep `pLines`, `PVGetHandles2`, `GetRGBAtCursor`,
`CalculateHistogram`). The dormant `salpvenv` envelope (`BUILD_ENVELOPE`, not in the solution)
shares `PixelAccess.cpp`; its branches are kept compilable.

The histogram's own 15/16-bit decoding took red from the low five bits (blue) and blue from the
high ones - swapped; its palette branch counted every byte of `BytesPerLine` (the padding of a row
too) - neither reachable with the WIC engine (every row is 32-bit). Both go with the shared reader.

## 2. Harness (`probe/pixharness/`, `probe/pixharness_result.txt`)

`build_and_run.cmd [rev]` compiles `pixharness.cpp` + the plug-in's `PixelAccess.cpp` +
`wicengine.cpp` with the plug-in's Release settings, once from the working tree and once from git
`rev` (default HEAD = the build before), and runs `pixref.py`: Pillow fixtures (37 x 5 - a width
that is not a multiple of 4 - plus a 40 x 30 one-color image and a UTF-8 file name), every pixel
through `GetRGBAtCursor`, the five histogram channels through `CalculateHistogram`, then a turn
clockwise + a black background (`TURN`) and two more turns + white (`TURN3`), all against Pillow
(composited over the same background; alpha 0/255 only, so the composite is exact).

| Fixture | Old: pipette wrong | Old: histogram | Old: turn + background | New |
|---|---|---|---|---|
| rgb24.png, rgba_opaque.png, UTF-8 name | 180 / 185 | 5 channels wrong | 37x5 (want 5x37) | all exact |
| rgba_alpha.png | 165 / 185 | 5 wrong | 37x5 | all exact |
| pal8.gif, pal16.png, gray.png | 180 / 185 | 5 wrong | 37x5 | all exact |
| bilevel.png | 87 / 185 (only 0/255 values) | 5 wrong | 37x5 | all exact |
| one_color.png 40x30 | 900 / 1200 | 5 wrong | 40x30 (want 30x40) | all exact |
| total | **2,295 mismatching checks** | | | **0** |

Example (old, rgb24 pixel (1,0)): got (69, 101, 255), want (53, 69, 101) - the bytes of pixel 0's
red, then the unused 255 read as blue: another pixel, channels shifted.

## 3. GIF comment (scratch measurement, `gifcmt.cpp` in the session scratch)

| Written (`/commentext/TextEntry`, VT_LPSTR) | In the file |
|---|---|
| "Plain comment" | comment extension, one sub-block of 13 bytes, exactly the text |
| UTF-8 `Komentář 日本` | one sub-block of 17 bytes, the UTF-8 bytes, no NUL |
| 600 bytes | sub-blocks 255 + 255 + 90 |
| `line1\r\nline2` | the bytes as given |
| `/xmp/<xmpalt>dc:description/x-default`, `/xmp/dc:description` (VT_LPWSTR) | 0x88982F91 `WINCODEC_ERR_PROPERTYNOTSUPPORTED` |

Pillow returns the raw bytes (`info['comment']`). The Windows property system shows no GIF
comment (`System.Comment`, `System.Title`, `System.Subject`, `System.Keywords` empty for both
files). The dialog's field holds 63 characters (105), so at most 189 bytes.

## 4. Rename onto a shown target (code reading, `render1.cpp RenameFileInternal`)

`CMD_IMG_RENAME` releases every window showing the renamed file (111) before
`RenameFileInternal`; the first `SalMoveFile` fails "already exists"; 103's identity check finds
another file; the overwrite question; Yes -> `MoveFileExW(MOVEFILE_REPLACE_EXISTING)`. A window
showing the TARGET holds it open through its WIC decoder without `FILE_SHARE_DELETE` - the replace
fails (5, access denied - measured) and nothing changes. 111's protocol has what is needed: `ReleaseShownFile` with
`own = FALSE` asks only the other windows, the operation id keeps this release apart from the
source's (a window already released for the source answers 0), `RetakeShownFile` ends it.

What a target window shows afterwards: its name now holds the renamed file. 111 already decided
the same question twice - a Save As over a shown file reopens it in every window (`sfaChanged`),
and a take-back whose name holds other content opens it (`sfaSame` / `sfaUnknown`). So the target's
windows take the `sfaUnknown` rule (`sfaReplaced`): re-attach when the window's own path still holds
the released file (a hard link of the target survives the replace), else open the name again
keeping the zoom.

## 5. The rotation and the background color (code reading + harness)

`WicSetBkHandle` frees the DIB when the color changes (alpha was flattened against the old one);
the next draw decodes the frame again from the file - without the turns `WicChangeImage` had done
(the viewer's own rotations and the EXIF auto-rotation). The viewer keeps its turned size. Callers:
`OpenFile` (before any decode - no effect), full screen on/off (`pictview.cpp`, the window's /
full-screen "transparent" colors - equal by default, both `COLOR_WINDOW`), the configuration
change (`render1.cpp`). Fix: the engine counts the turns of the decoded frame (`Turns`, reset by a
fresh decode); a turned frame is decoded again at once and turned again (`RedecodeTurned`); on
failure the old image stays. Harness `TURN`/`TURN3`: exact.

## 6. Why the pipette is not driven on the hidden desktop

The status bar's pipette panel takes the position from `GetMessagePos()` and the tooltip from
`GetCursorPos()`: the real cursor of the session. A posted `WM_MOUSEMOVE` carries the real cursor
position too, `SetCursorPos` fails on a desktop that is not the input desktop, and moving the
maintainer's mouse is not acceptable. The probe's pipette rows therefore run only on the visible
desktop, with the maintainer's agreement (`-VisiblePipette`, `TC_PROBE_ALLOW_VISIBLE_DESKTOP=1`).
The reader itself is covered by the harness (the real engine's rows) and the mapping by saltests.
