# Implementation Plan: PictView works on the image it shows (feature 111)

**Branch**: `111-pictview-shown-image` (from `110-zip-plugin-name-matching`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Content |
|---|---|
| S0 measure | Pre-change build preserved (`Debug_x64_pre111`). Scratch program `m111.cpp` (session scratch): what the WIC decoders report for 22 fixtures (pixel format, bits, transparency, palette size / gray), what the encoders write for comments (JPEG COM, GIF, TIFF tag 270, XMP paths, the photo policies) and what the Windows property system reads back. The probe on the build before (`probe/shown_result_pre111.txt`); the wallpaper path by code reading only |
| S1 engine | `wicengine.{h,cpp}`: `WicDetachSource` remembers frame count / frames; `WicReattachSource` (new decoder on the current name, same container and frame count, the image in memory untouched); `WicGetSourceFormat` (`SourceFormatOf` per frame, alpha use recorded at decode - `CompositeOverBackground` returns it); TIFF comment outside ASCII also as XMP `dc:description`; `JpegDropCommentNul` after the commit. Pure rules in `src/common/salpvsource.h` (palette colors, the alpha question, the COM segment's NUL) |
| S2 release/retake | `render1.cpp`, `renderer.h`, `pictview.{h,cpp}`: `ReleaseShownFile` / `RetakeShownFile` (this window + `WM_USER_RELEASEFILE` / `WM_USER_RETAKEFILE` to the other viewer windows, snapshot of `ViewerWindowQueue`, `SendMessageTimeout` 5 s, message data copied per window and never freed after a time-out); Rename and Delete use them; `OnRetakeFile` re-attaches, reloads keeping the zoom, or titles `<Deleted>` |
| S3 Save As | `saveas.cpp`: `SaveImageSafe` -> `EncodeReplaceSafe` (shared with the wallpaper) releases every window before the replace and retakes after (changed / same); alpha question, mono list and default depth from `WicGetSourceFormat`; title and Image Information from `GetSourceImageInfo` |
| S4 wallpaper | `render2.cpp`: `SaveWallpaperFile` (BMP 24-bit into `%LOCALAPPDATA%\Tandem Commander`), `SetAsWallpaper` with wide registry access and `SPI_SETDESKWALLPAPER` with an explicit path; the dry-run seam `TC_PICTVIEW_WALLPAPER_DRYRUN` in the only two writing functions (`WpRegWrite`, `WpApply`) |
| S5 tests | saltests `TestPvSource111`; probe `probe/shown_probe.ps1` + `pilcheck.py` + `mkfix111.py` (hidden desktop) on both builds; regressions 105, 103, 104, 088; Release build; records (fix-log, NEXT-WORK, CHANGELOG, PRIVACY.md) |

No plug-in interface change (107), no configuration format change, no new UI string.
