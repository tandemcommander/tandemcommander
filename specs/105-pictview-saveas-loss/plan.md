# Implementation Plan: PictView Save As never loses the file it replaces (feature 105)

**Branch**: `105-pictview-saveas-loss` (from `104-plugin-unicode-names`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Content |
|---|---|
| S0 measure | Pre-change build preserved (`Debug_x64_pre105`). Scratch programs (`m105.cpp`, `m105b.cpp`, session scratchpad): what each WIC encoder accepts (pixel formats, options, comments), `ReplaceFileW`/`MoveFileExW` against read-only, missing, held-open (share read / WIC decoder) targets. Sweep of every PictView write route. The probe on the build before (`probe/saveas_result_pre105.txt`) |
| S1 rule | `src/common/salsafereplace.h` (header-only, wide): `SalCreateTempNextToW` (CREATE_NEW `pvXXXX.tmp` in the target's folder, open), `SalReplaceWithTempW` (existing: clear read-only if agreed, `ReplaceFileW`, fallback `MoveFileExW(REPLACE_EXISTING)` for "not supported", target gone -> move the new file in or keep it; new: `MoveFileExW` without replace), pure `SalReplaceFailureNext`, `SalBuildTempNextToW` |
| S2 engine | `wicengine.cpp`: `WicPlanOutput` (the table: format x compression x colors -> WIC pixel format, palette, TIFF option), real `PVIsOutCombSupported`, `WicCanEncodeFormat`, `WicEncodeImageToFile` (a no-copy `IWICBitmapSource` over the shown DIB with flips/rotation/invert and progress/cancel; palette, format converter, encoder options, comment metadata; an `IStream` over the caller's file handle that keeps the first system error), `WicDetachSource`. `PVSaveImage` file output stays refused (wallpaper unchanged) |
| S3 Save As | `saveas.cpp`: the type list filtered to what the encoders write (stored index kept in whole-list terms), the existence check without opening or deleting, `SaveImageSafe` (temp -> encode -> flush -> [release the shown file's decoder] -> replace -> cleanup), messages with the system's reason, reload when the shown file was replaced; GIF/TIFF options without an encoder counterpart disabled; the comment read as UTF-16; the suggested name bounded. Menu item restored (`pictview.cpp`) |
| S4 other routes | `thumbs.cpp` Regenerate thumbnail: one-step replace (and no endless retry); `render1.cpp` Rename overwrite: `MoveFileExW(REPLACE_EXISTING)` instead of delete + rename |
| S5 tests | saltests `TestSafeReplace105`: the pure rules; real NTFS files: new, appeared meanwhile, hidden kept, read-only not agreed / agreed, held open without FILE_SHARE_DELETE, temp missing, target vanished, folder, hard link, over MAX_PATH |
| S6 probe | `probe/saveas_probe.ps1` (hidden desktop) on both builds; regressions 104 (PictView rows), 088 viewers, 103 samefile; Release build; records |

No plug-in interface change (107), no configuration format change, no new UI string.
