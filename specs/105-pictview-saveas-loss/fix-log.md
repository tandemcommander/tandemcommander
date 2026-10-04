# Fix log: feature 105 - PictView Save As never loses the file it replaces

Branch `105-pictview-saveas-loss`, from `104-plugin-unicode-names` (6d22c02f). Decisions by the
author (the maintainer asked for autonomy): `spec.md` *Clarifications*. Measurements behind
every decision: `research.md`. Pre-change build: `build\tandemcommander\Debug_x64_pre105`.
Not committed (the coordinator commits after an independent review).

## Measured first - the premise

Right, and wider (`research.md` section 0): on the build before, **Save As saved nothing at
all** (every one of the 14 offered types: "Unable to save the image. Error: This operation is
not supported by the built-in image engine."), and an existing target was **deleted before**
that failure - every format, also in a folder that denies creating files and when the save was
canceled. The engine's `PVIsOutCombSupported` stub said "supported" to everything, so the dialog
offered formats, depths and compressions nothing could write. Not lost before: a file another
program holds open, the shown image (both "in use"), a read-only file (Windows' own Save dialog
refuses it - PictView's read-only question is unreachable through the dialog).

## T003 - S1: the rule (`src/common/salsafereplace.h`, new, header-only, wide API)

| Piece | What it does |
|---|---|
| `SalBuildTempNextToW` (pure) | `<folder of the target>\<prefix>XXXX.tmp` |
| `SalCreateTempNextToW` | creates it `CREATE_NEW` (any length, `\\?\`), returns it open (read/write, not shared); a taken name is skipped, any other error is returned (read-only folder: 5, missing folder: 3) |
| `SalPathIsGoneW` | "gone" only for not-found errors - an entry whose attributes cannot be read counts as present (review of the own diff: "gone" leads to moving the new file in) |
| `SalReplaceFailureNext` (pure) | after a failed `ReplaceFileW`: target there + temp there -> keep the target, except "not supported" errors (`ERROR_NOT_SUPPORTED`, `INVALID_FUNCTION`, `INVALID_PARAMETER`, `CALL_NOT_IMPLEMENTED`) -> fallback rename; target gone + temp there -> move the temp in; both gone -> report |
| `SalReplaceWithTempW(target, temp, targetExisted, clearReadOnly, &err)` | new target: `MoveFileExW` **without** replace (a file that appeared meanwhile is never overwritten unasked). Existing: clear read-only only if agreed, `ReplaceFileW(IGNORE_MERGE_ERRORS | IGNORE_ACL_ERRORS)` (attributes, ACL, creation time kept), fallback `MoveFileExW(REPLACE_EXISTING)`; on failure the read-only attribute is put back. Results: done / failed-kept (caller deletes the temp) / left-at-temp (the target is gone and the new file could not take its name: keep and name it) / both gone |

Listed in `saltests.vcxproj`.

## T004 - S2: the engine (`wicengine.{h,cpp}`)

- `WicPlanOutput(format, compression, colors, color model)`: the table of what is offered and
  what it becomes (WIC container, pixel format, palette, TIFF option) - BMP: 16/256 colors (optimal
  palette), 256 gray (8bppIndexed + gray palette: the BMP encoder has no 8bppGray), 15/16-bit
  (555/565), 24-bit; PNG: 16/256 (indexed), gray (8bppGray), 24-bit, bilevel (BlackWhite); JPEG:
  gray, 24-bit; GIF: 16/256/gray/bilevel all as 8bppIndexed; TIFF: as PNG, compressions none/LZW/
  Deflate/PackBits/Default (= LZW), CCITT G3/G4 only bilevel. No 32-bit (alpha is flattened).
- `PVIsOutCombSupported` answers from that table (was: 0 = "supported" for everything).
- `WicEncodeImageToFile(handle, frame, file handle, params, progress, ...)`:
  - `CWicDibSource` - an `IWICBitmapSource` over the frame the viewer holds (32bpp BGRX, after
    the viewer's own rotations), no copy; flips, then the 90-degree clockwise turn, inverted
    colors computed per pixel; every 16 rows the progress hook (Esc -> `ERROR_CANCELLED` ->
    `PVC_CANCELED`). Row count for progress includes the palette builder's extra pass.
  - palette (`InitializeFromBitmap` / `FixedBW` / `FixedGray256`), `IWICFormatConverter` (error
    diffusion for reduced colors), encoder options (`ImageQuality`, `JpegYCrCbSubsampling`:
    1:1:1 -> 4:4:4, 2:1:1 -> 4:2:2; `TiffCompressionMethod`), `SetResolution`, `SetPixelFormat`
    must return exactly the planned format (else `PVC_UNSUP_OUT_PARAMS` - never write something
    other than offered), `SetPalette`, the comment, `WriteSource`, `Commit`.
  - Comment as UTF-8: JPEG COM, GIF comment extension, TIFF ImageDescription get the bytes
    (`VT_LPSTR`); PNG `tEXt` for ASCII, `iTXt` (keyword "Comment", UTF-8 by the PNG rules)
    otherwise. **`VT_LPWSTR` is converted to the code page by the tEXt and TIFF writers** -
    the first build used it and wrote `?` (probe rows `cmt-png`, `cmt-tif` caught it; `m105c`
    measured the bytes).
  - `CWicHandleStream` - an `IStream` over the caller's file handle; the first failing system
    call's error is kept (`PVC_WRITING_ERROR` + that error -> the user sees "disk full", ...).
  - Every COM object released on every path; a failure leaves the file content undefined (the
    caller discards the temporary file).
- `WicDetachSource`: decodes the current frame if needed, releases the decoder (and its file);
  the image then behaves as an attached bitmap (one frame, drawn from memory).
- `PVSaveImage` keeps refusing file output, so the wallpaper commands and print are unchanged.
- One engine text added, English like the others: `PVC_WRITING_ERROR` "The image could not be
  written." (shown only when no system error explains the failure).

## T005 - S3: Save As (`saveas.cpp`, `renderer.h`, `pictview.cpp`)

- **Type list**: `BuildSaveFilter` keeps the language's entries whose format
  (`FormatOfPattern`, the rule of `GetFormatInfo`) `WicCanEncodeFormat`; `keptFull` maps the
  dialog's index to the whole list, in which `Filter Color`/`Filter Mono` stay stored; a stored
  entry that is gone shows Windows Bitmap. Nothing to offer -> message, nothing touched.
- **Existence**: `GetFileAttributesExW` - opens nothing. A folder of that name: "already exists"
  (OK = new name). Read-only: the read-only question only (as before); its *Yes* is remembered
  as `clearReadOnly` (cleared only inside the replace). Otherwise "replace?". **Nothing is
  deleted here any more.** Backstop: a format the encoders cannot write is refused here.
- **`SaveImageSafe`**: parameters as `SaveImage` computed them (gray flag, flips XOR the
  viewer's mirror - the old code un-mirrored the window as a side effect, this one does not),
  `SalCreateTempNextToW(target, "pv")` (failure = "Unable to save the image. Error: <system
  text>", nothing touched), progress bar + wait cursor, encode, `FlushFileBuffers`, close; if the
  target is the shown file (`IsShownFile`: same name, or the file system's identity -
  `salsamefile.h`; a "maybe" counts) `WicDetachSource`; `SalReplaceWithTempW`; on any failure
  the temporary file is deleted - except left-at-temp, which keeps it and puts its name into the
  message.
- **Messages**: `IDS_SAVEERROR` with the system's text (UTF-8 from `GetErrorText`) or the
  engine's, composed in UTF-16 (`FormatNameMessageU8` now accepts the template's `%hs`);
  cancel -> `IDS_CANCELED_BY_USER` (now true: nothing was created or changed).
- **Shown file**: after the replace (done or not) the window opens the file again
  (`OpenFile(FileName)`).
- **Dialog**: GIF *Interlaced*/*GIF89a* and TIFF *Make strips*/*Strip size* disabled (no encoder
  counterpart); the comment is read with `GetDlgItemTextW` into UTF-8
  (`SAVEAS_MAX_COMMENT_BYTES` = 3 x 64).
- **Found and fixed in the touched function**: the suggested name was `_tcscpy`'d from the shown
  file's name into `fileName[MAX_PATH]` - a name component of more than 259 bytes of UTF-8 (87+
  CJK characters) overran the stack, every release. Now copied only when it fits.
- `pictview.cpp`: *File > Save As...* restored in the viewer's menu (`IDS_MENU_FILE_SAVEAS`, all
  languages translated); the toolbar button not (its layout is configuration).

## T006 - S4: the other routes

- `thumbs.cpp` *Regenerate thumbnail*: `DeleteFileU8(image)` + unchecked `MoveFileU8(tmp,
  image)` replaced by `ReplaceFileU8` (`SalReplaceWithTempW`): one step, the original kept on
  failure; the read-only question/`All` logic kept, but the agreed clearing happens inside the
  replace (put back if it fails) and read-only is the reason only until it has been tried
  without it (with *All*, a failure for another reason used to loop forever). Left-at-temp keeps the new file and names it.
  `MoveFileU8` removed. Unreachable on both builds (no scaled-JPEG encoder) - not driven.
- `render1.cpp` *Rename* overwrite branch: `DeleteFileW(target)` + `SalMoveFile` replaced by
  `MoveFileExW(REPLACE_EXISTING)`, the target's read-only attribute put back on failure.
  Unreachable on both builds (the shown file is held open: the first rename fails with 32 - 103)
  - not driven.

## T007 - S5: saltests `TestSafeReplace105`

Pure: `SalReplaceFailureNext` (12 cases), `SalBuildTempNextToW` (folder, none, `\\?\` + non-ASCII).
Real NTFS files: two temporary files differ, same folder, empty, open; a missing folder -> 3;
new target; a file that appeared meanwhile is kept (183) and the temp stays for the caller;
hidden target replaced and still hidden; read-only not agreed -> 5, kept, still read-only;
agreed -> replaced; read-only and held open without `FILE_SHARE_DELETE` (as the WIC decoder) ->
32, content and read-only attribute as before; temp missing -> kept; target vanished -> the
new file takes its name; a folder of the target's name is never replaced; another hard link
keeps the old content; a path over MAX_PATH; `SalPathIsGoneW` (only "not found" is "gone").
**saltests 13,487 -> 13,555, 0 failed.**

## T008 - S6: probe `probe/saveas_probe.ps1` (hidden desktop)

Hidden desktop, English UI forced (`Set-Config`), Czech Windows. Source: a 40 x 30 24-bit BMP
with a known gradient; every saved file decoded by GDI+ (not the program's WIC code) and its
header read by hand; every row checks that no `pv*.tmp` is left. Results committed:
`probe/saveas_result.txt` (this build) and `probe/saveas_result_pre105.txt`.

| Rows | This build | Debug_x64_pre105 |
|---|---|---|
| `offer` | 5 types (BMP, GIF, JPEG, PNG, TIFF); per type only the depths/compressions the table offers | 14 types |
| `new-*` (5 formats) | valid, BMP/PNG/TIFF pixel-exact, JPEG mean diff 1.4, GIF 13.4 | "Unable to save", no file |
| `over-*` (5) | replaced by a valid image | **file DELETED** (5 x LOSS) |
| depths/compressions (16 rows) | header as chosen: BMP 4/8/8-gray/16 555/16 565 bit, PNG 4/8 indexed and 8 gray, GIF 16 and gray, JPEG gray, TIFF tag 259 = 1/5/8/32773, TIFF 4-bit palette and 8-bit gray | no file |
| `jpg-q`, `jpg-sub` | quality 10: 696 bytes < 95: 993 bytes; SOF luma sampling 0x11 / 0x21 | no file |
| `cmt-*` (4) | the comment's UTF-8 bytes in the file | no file |
| `rot90`, `fliph` | pixel-exact | no file |
| `name-*` (Cyrillic, CJK, emoji, CJK over an existing file) | valid | no file; the existing one **DELETED** |
| `ro` | Windows' dialog refuses the read-only file; unchanged | the same |
| `locked` | "Unable to save the image. Error: (32) ..." - byte-identical | not lost either (the old check failed with 32 first; row FAIL only because the old box is the bare Czech system text) |
| `acl` (folder denies creating files) | "Error: (5) Access is denied" - byte-identical | **DELETED** |
| `cancel` (6000 x 4000, Esc) | "canceled" - byte-identical | no cancel; **DELETED** |
| `shown` (over itself, rotation 90; then a second save) | 30 x 40, and the window shows the saved image | "(32) in use", nothing saved |
| total | **56 PASS / 0 FAIL / 4 NOT DRIVEN, 0 files lost** | 7 PASS / 49 FAIL / 4 NOT DRIVEN, **8 files lost** |

Registry restored and identical in every run (SHA-256 `1AB614304771DBE0...`). Probe history,
kept honest: run 1 had 11 FAIL - probe expectations (the dialog keeps the previous compression
when the type changes; the Windows GIF encoder writes a local, not global, color table; the read-
only rows - Windows' dialog refuses such a file), **and two real defects: `cmt-png`, `cmt-tif`**
(the comment written as `?`, fixed in the engine). Run 2: 2 FAIL (the probe chose the depth
before the compression; the compression choice resets the depth). Run 3 on the final binary:
56/0.

NOT DRIVEN (in the result file): a full disk (needs a small volume - admin); a file system
without `ReplaceFileW` and a target vanishing between the question and the replace (saltests);
"2 colors"/CCITT (cannot be chosen - see *Recorded*); Regenerate thumbnail and Rename overwrite
(unreachable on both builds).

## T009 - Gates

| Gate | Result |
|---|---|
| Debug build (`build.cmd`) | exit 0, no warning in the touched files |
| Release (`build.cmd full release`) | exit 0; 20 plug-ins, 189 language modules, runtime closure OK |
| saltests | **13,555 / 0** (13,487 before; `TestSafeReplace105` +68) |
| `tools/check_encoding.py --strict` | TOTAL: 0 |
| clang-format | the new/changed code formatted (the touched files have no violations beyond the pre-existing ones in `render1.cpp` and the include-comment block of `saltests.cpp`) |
| Probe 105 | 56 / 0 / 4 NOT DRIVEN, 0 lost (pre-105: 7 / 49 / 4, 8 lost) |
| 104 `plugnames_probe.ps1 -Only pv-copyto,pv-saveas` (`probe/regress_plugnames_105.txt`) | 4 / 0 as before; its FINDING row now reads "exist.bmp rewritten" (was "DELETED") and the voilà save says "Image saved successfully" |
| 088 `viewers_probe.ps1` (`probe/regress_viewers088_105.txt`) | 7 / 3 - **identical on the pre-105 build** (`regress_viewers088_pre105.txt`): the PictView rows P3, P5, N1a pass on both; P1 (Code Viewer), P2 (Markdown Viewer) time out after 35 s and N3 gets the Code Viewer's unload question on both builds - WebView2 viewers on the hidden desktop, not PictView, not this change (088 recorded 10/10 on the visible desktop) |
| 103 `samefile_probe.ps1 -Expect103` (`probe/regress_samefile_105.txt`) | 62 / 0 as before (its PictView rename route stays NOT DRIVEN by design - the error 32 finding) |
| Registry | restored and identical after every run, SHA-256 `1AB614304771DBE0...` |
| Line endings / BOM | every touched file keeps its form (BOM where it had one, CRLF); new header BOM + CRLF; specs LF without BOM |

## T010 - independent review: ACCEPT

The reviewer re-ran the probe (56 / 0 / 4, 0 files lost) and drove its own cases on the hidden
desktop and directly against `salsafereplace.h` (NTFS and SMB `\\localhost\C$`): an alternate
data stream survives; a hard link (count 2) - the target name gets the new image, the other
name keeps the old content; hidden + system attributes kept; a target held open with
read + delete sharing is replaced; a temp held by a third party -> 32, target kept; a folder at
the target name -> 5, untouched; 3,000 and then all 65,536 `pvXXXX.tmp` names taken by the
user - every user file intact; a symbolic link as the target -> 1464, link and file unchanged;
changes while the "replace?" question is open (read-only set, target deleted, replaced by a
folder, locked) - kept or created as appropriate; a shown name of 100 CJK characters saves
(the build before: Debug assertion, then a crash report - the overflow fix confirmed).
Comments decoded independently (PIL): PNG `iTXt` well formed, ASCII in `tEXt`, GIF and JPEG
round-trip. `ReplaceFileW` errors 1175/1176/1177 handled (code reading); COM released on every
path; a stored type index now filtered out falls back to BMP.

Applied: the CHANGELOG sentence about a read-only file "after its own question" removed - the
Save dialog refuses read-only files before PictView sees them (row `ro`, research 0.2).

Recorded (NITs, no data risk):
- Saving onto a symbolic link always fails with 1464 ("not supported for symbolic links") -
  safe, but saving onto a linked file is now impossible.
- A replaced read-only file (after the user agreed) is not read-only afterwards (0x20) - as
  before; deliberate: the user chose to replace it.
- TIFF tag 270 receives UTF-8 bytes in an ASCII-typed tag (spec-following readers show
  mojibake for non-ASCII comments); the JPEG COM segment ends with a NUL byte.
- The dialog's name buffer is 260 UTF-8 bytes: saving onto a name of 260+ bytes (also over a
  shown 100-CJK-character file) is refused by Windows ("file name too long"); nothing is lost.
- If a scanner holds the temp file without delete sharing, the cleanup fails and a
  `pv*.tmp` stays (debug trace only).
- After saving over the shown image the reload resets the viewer's mirror and zoom (also when
  the replace failed).
- **088 viewers probe, 3 failures** (Code Viewer / Markdown Viewer close by the Restart
  Manager): not a regression of 089-105. The 088 code rebuilt from its records commit
  (`a39df9b6`) fails identically on the hidden desktop (P1/P2 `ERROR_FAIL_SHUTDOWN` after
  35 s, N3 marked FAIL only because two system windows `UAC_InputIndicatorOverlayWnd` appear);
  088's 10/10 ran on the visible desktop before the hidden-desktop launcher existed. Hidden
  desktop vs. a WebView2 runtime update since 2026-10-01 not separated (would need the
  visible desktop).

## Recorded, not changed

- **PictView's Rename of the shown image fails with 32** (recorded by 103, unchanged). The way to
  fix it now exists - `WicDetachSource` (release the decoder, rename, reopen), as Save As does for
  the shown file. Queued in NEXT-WORK (small, no data at risk).
- **Every PNG/TIFF/ICO source asks "the alpha channel will be lost"** before the Save As dialog,
  and **"2 colors" (so also the CCITT TIFF compressions) is never offered**: the WIC engine
  reports every image as 32-bit (`FillInfo`, feature 006), so the dialog's "is it 32-bit" and
  "is it bilevel" rules (Open Salamander's) answer the same for every image. Harmless (one
  question with "don't show again"; the 1-bit encoder paths were measured, `research.md` 2).
- **Windows' Save dialog refuses a read-only file** before PictView sees the name - PictView's own
  read-only question (and the agreed clearing, now done inside the replace and undone on
  failure) is reachable only if the attribute appears between the dialog and the check.
- **The wallpaper commands cannot work**: `PVSaveImage` still writes no file (deliberately - not
  the Save As route), and their target `%WINDIR%\PictView_Wallpaper.bmp` is not writable for a
  user; they fail before writing anything ("Unable to save the image"), as before.
- **Regenerate thumbnail cannot work** (no scaled-JPEG encoder; WIC never sets `PVFF_EXIF`) -
  recorded by 104; its replace step is safe now.
- A second viewer window showing the same file keeps it open: Save As onto it from the first
  window is refused "in use" (nothing lost; by design).
- An in-viewer rotation is lost when the background color changes (`WicSetBkHandle` re-decodes
  the frame) - pre-existing; Save As writes what is displayed, so the two stay consistent.
- A PNG comment outside ASCII goes into an `iTXt` chunk (UTF-8 by the PNG rules); readers that
  only know `tEXt` do not show it. The comment field still holds 63 characters.
- `PRIVACY.md`: *Temporary files* now says that Save As writes `pvXXXX.tmp` in the target's
  folder first (a crash during the save can leave it there); validity line dated 2026-10-04.
  Nothing else PictView stores changed.

## CLAUDE.md "Recent Changes" entry

```
- 105-pictview-saveas-loss: **PictView's Save As saves, and never loses the file it
  replaces.** Measured first: worse than the 104 record - since feature 006 Save As saved
  *nothing* (14 types offered, every one "Unable to save the image": the WIC engine stubbed file
  output and its `PVIsOutCombSupported` said "supported" to everything), and an existing target
  was **deleted before** that failure (every format; also in a folder that denies creating
  files, also on Esc). Not lost before: a file held open elsewhere, the shown image ("in use");
  a read-only file never reaches PictView (Windows' Save dialog refuses it).
  - **Rule** (`src/common/salsafereplace.h`, header-only, wide): write `pvXXXX.tmp` next to the
    target (`SalCreateTempNextToW`, CREATE_NEW, any length), flush, close, then
    `SalReplaceWithTempW`: `ReplaceFileW` (attributes/ACL kept; fails with 5/32/2 leaving both
    files intact - measured), `MoveFileExW(REPLACE_EXISTING)` only for "not supported", a new
    name `MoveFileExW` without replace; a failure keeps the target (read-only put back) and the
    caller deletes the temp - except when the target is already gone: the new file is moved in
    or kept and named. "Gone" means not-found only (`SalPathIsGoneW`). **New code that replaces
    a user's file MUST use it.**
  - **Engine** (`wicengine.cpp`): `WicPlanOutput` table (BMP 16/256/gray/555/565/24, PNG and
    TIFF 16/256/gray/24 + bilevel, JPEG gray/24, GIF 16/256/gray as 8bppIndexed; TIFF
    none/LZW/Deflate/PackBits/Default=LZW, CCITT bilevel only), real `PVIsOutCombSupported`,
    `WicEncodeImageToFile` (a no-copy `IWICBitmapSource` over the shown DIB - flips, then the
    clockwise turn, progress/Esc every 16 rows; palette, converter, options, a file-handle
    `IStream` that keeps the first system error), `WicDetachSource` (the decoder holds the shown
    file without `FILE_SHARE_DELETE`: released after the new file is complete, the window reloads).
    `PVSaveImage` file output stays refused (wallpaper unchanged). Comments are UTF-8:
    `VT_LPWSTR` is converted to the code page by the PNG tEXt and TIFF writers (`?`, measured),
    so JPEG/GIF/TIFF get the UTF-8 bytes and PNG `tEXt` (ASCII) or `iTXt`.
  - **Dialog**: the language's type list filtered to BMP/GIF/JPEG/PNG/TIFF (no string change; the
    stored index stays a whole-list index); GIF interlace/89a and TIFF strips disabled (no
    encoder counterpart); *File > Save As* back in the menu; the suggested name no longer
    overflows a 260-byte stack buffer (every release, 87+ CJK characters).
  - Same one-step replace for *Regenerate thumbnail* and the *Rename* overwrite (both
    unreachable). No new string, no interface change (107), no registry change; `PRIVACY.md`
    mentions the `pvXXXX.tmp`. Probe `probe/saveas_probe.ps1` (hidden desktop, GDI+ decode,
    headers read by hand): 56 PASS / 0 FAIL / 4 NOT DRIVEN, 0 files
    lost (the build before: 7 / 49 / 4, 8 existing files deleted). saltests 13,487 -> 13,555.
    Records: `specs/105-pictview-saveas-loss/fix-log.md`.
```
