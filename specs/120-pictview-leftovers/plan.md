# Implementation Plan: PictView's leftovers of 105 and 111 (feature 120)

**Branch**: `120-pictview-leftovers` (from `119-packing-leftovers`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Content |
|---|---|
| S0 measure | Pre-change build preserved (`Debug_x64_pre120`). Inventory of the consumers of the engine's rows (code reading). Harness `probe/pixharness/` - the plug-in's `wicengine.cpp` + `PixelAccess.cpp` compiled into a console program twice (working tree / git revision), 9 Pillow fixtures, every pixel and every histogram count compared; a turn + new background color. Scratch program (session scratch) for what the Windows GIF encoder writes for comments and whether it takes XMP |
| S1 reader | `src/common/salpvpixel.h` (pure): bits per pixel of a row format, palette index / direct color of pixel x, histogram row and add, the shown-to-row mapping (mirror). `PixelAccess.cpp` rewritten on it, bounded by `WicGetRowsSize` (new, `wicengine.{h,cpp}`) |
| S2 pipette glue | `render1.cpp`: `GetRGBAtCursor` maps the shown position through the mirror; `ClientToPicture` and the tooltip compute in 64 bits; `statsbar.cpp` shows nothing when nothing was read |
| S3 rename target | `render1.cpp` `RenameFileInternal` (the Yes branch of the overwrite question): `ReleaseShownFile(target, own FALSE)` before the replacing `MoveFileExW`, `RetakeShownFile(sfaReplaced / sfaSame)` after; `renderer.h` `sfaReplaced` (= the `sfaUnknown` rule: re-attach when the window's own path still holds the released file, else open its name again) |
| S4 rotation | `wicengine.cpp`: `CWicImage::Turns`; `RotateDib` split out of `WicChangeImage`; `WicSetBkHandle` decodes a turned frame again at once and turns it (`RedecodeTurned`; on failure the old image stays) |
| S5 GIF | decision recorded in the `wicengine.cpp` comment (no code change) |
| S6 tests | saltests `TestPvPixel120`; harness on both builds; probe `probe/pv120_probe.ps1` written (GUI runs owed); strict guard; Debug + full Release builds; records |

No plug-in interface change (107), no registry format change, no new string.
