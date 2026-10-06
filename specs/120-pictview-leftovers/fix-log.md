# Fix log: feature 120 - PictView's leftovers of 105 and 111

Branch `120-pictview-leftovers`, from `119-packing-leftovers` (7d6ffeb6). Decisions by the author
(the maintainer asked for autonomy): `spec.md` *Clarifications*. Measurements behind every
decision: `research.md`. Pre-change build: `build\tandemcommander\Debug_x64_pre120`; this build
preserved for the GUI runs: `build\tandemcommander\Debug_x64_120`. Not committed (the coordinator
commits after an independent review). **No GUI was run**: another agent drives the hidden desktop
and the maintainer uses the installed program - the probe is written, its runs are owed
(`quickstart.md`).

## Measured first - the premises

All three are right, and the first is larger than recorded (`research.md` 0-2): the pipette was
wrong for 3 of 4 pixels of every row of EVERY image (the WIC engine hands out 32-bit rows for every
format - also 8-bit GIF, 16-color PNG, gray, bilevel), all five histogram channels were wrong for
every image; harness on the build before: 2,295 mismatching checks over 9 Pillow fixtures. Found on
the way (code reading): the pipette read the pixel opposite the cursor on a mirrored image, and the
window-to-image mapping overflowed 32 bits zoomed into a large image (no bound on the read). 105's
record "a rotation is lost when the background color changes" measured by the harness (37 x 5 left
after a turn instead of 5 x 37).

## T003 - one row reader (`src/common/salpvpixel.h` new, `PixelAccess.cpp`, `wicengine.{h,cpp}`)

- `SalPvRowBitsPerPixel` (TC32 32, TC24 24, HC15/16 16, palette 8/4/1, else 0), `SalPvRowIndex`,
  `SalPvRowColor` (the 15/16-bit decoding equals the old pipette's byte arithmetic - checked for
  every 97th word), `SalPvReadRowPixel`, `SalPvHistogramAdd` / `Row` / `Finish`, `SalPvShownToRow`.
- `PixelAccess.cpp`: both functions on the reader; never past the rows the engine holds
  (`WicGetRowsSize`, new); the histogram counts `Width` pixels per row (no padding), palette
  indexes added through the palette once, a non-row format refused (`PVC_UNSUP_COLOR_DEPTH`). The
  `BUILD_ENVELOPE` branches (the dormant `salpvenv`, not in the solution) stay compilable; the old
  `#pragma runtime_checks` is gone (explicit masked casts, nothing for /RTCc to report).
- Removed with the old code, not reachable with the WIC engine: the histogram's red/blue swap for
  15/16-bit rows and its counting of the padding bytes of palette rows.

## T004 - the pipette glue (`render1.cpp`, `statsbar.cpp`)

- `CRendererWindow::GetRGBAtCursor`: the shown position through the mirror (`SalPvShownToRow`
  with `fMirrorHor`/`fMirrorVert`) - the coordinates shown stay those of the shown image, as the
  selection's; outside the image: nothing.
- `ClientToPicture` and the tooltip's mapping in 64 bits.
- Status bar: the color panel is empty when nothing was read (it printed an uninitialized
  `RGBQUAD` before, guarded only by the caller's bounds).

## T005 - Rename onto a file another window shows (`render1.cpp`, `renderer.h`)

In `RenameFileInternal`, the Yes branch of the overwrite question: `ReleaseShownFile(wTgtPath, own
FALSE)` just before the replacing `MoveFileExW`, `RetakeShownFile(&tgtRel, replaced ? sfaReplaced :
sfaSame)` right after it (the move's error kept for the message). New `sfaReplaced` = the
`sfaUnknown` rule: a window whose own path still holds the file it let go (a hard link of the
target) re-attaches it, any other opens its name again keeping the zoom. 111's operation ids keep
this release apart from the source's (a window already let go for the source answers 0). A window
that is loading, encoding or printing answers 2 and keeps the file - the replace fails "in use"
as before.

## T006 - the rotation and the background color (`wicengine.cpp`)

`CWicImage::Turns` (net clockwise quarter turns of the decoded frame; 0 after every fresh decode
and after the thumbnail fast path), `RotateDib` split out of `WicChangeImage` (which counts the
turn), `WicSetBkHandle`: a turned frame is decoded again at once and turned again
(`RedecodeTurned`, three turns = one counter-clockwise); if that fails the old image stays (drawn
over the old color); an unturned frame keeps the lazy re-decode.

## T007 - GIF comment: decided, no code change

ASCII as is (GIF89a), other text its UTF-8 bytes (`research.md` 3): GIF has no Unicode alternative
(the Windows GIF encoder refuses XMP, measured `0x88982F91`), Windows shows no GIF comment at all,
refusing or stripping would lose the user's text without a word (no new string), JPEG and TIFF keep
UTF-8 the same way. Recorded in the `wicengine.cpp` comment.

## T008/T009 - saltests, harness

- `TestPvPixel120` (row formats, every reader branch, the 15/16-bit parity loop, the histogram
  incl. padding and the old swap, the mirror mapping): **saltests 14,655 -> 17,423, 0 failed.**
- Harness `probe/pixharness/build_and_run.cmd` (`probe/pixharness_result.txt`): NEW 0 mismatching
  checks on all 9 fixtures (pipette every pixel, 5 histogram channels, turn + black, three turns +
  white); OLD (git HEAD = the build before) 2,295.

## T010 - probe `probe/pv120_probe.ps1` (written, not run)

Rows `tgt-shown` (A renames x.png onto z.png shown by B, C shows x.png too), `tgt-shown-no`,
`tgt-shown-hl` (B shows a hard link), `tgt-shown-print` (B's Print dialog open), `hist-png`,
`hist-gif`, `hist-alpha` (the histogram control captured - BitBlt, else PrintWindow - and its bars
read per level by the tone band under them; NOT DRIVEN when the capture shows no band),
`bk-rot` (FullScreenBGColor seeded black, rotate, full screen on/off, Save As = the turned image),
`cmt-gif-ascii`, `cmt-gif-u8`, `pip-plain`, `pip-mirror` (only `-VisiblePipette` on the visible
desktop: the pipette follows the real cursor, which a hidden desktop does not have). Helpers copied
from 111's probe; references from Pillow (`mkfix120.py`, `ref120.py`, 111's `pilcheck.py`).
Checked without the GUI: the script parses (0 errors), its C# compiles, the bar reader returns
`50,100,200` / `red` / mag 3 on a synthetic capture painted like `CHistogramControl::Paint`.

## T011 - Gates

| Gate | Result |
|---|---|
| Debug build (`build.cmd`) | exit 0, no warning |
| Release (`build.cmd full release`) | exit 0; 20 plug-ins, 189 language modules, runtime closure OK (218 modules) |
| saltests | **17,423 / 0** (14,655 before; `TestPvPixel120` +2,768) |
| `tools/check_encoding.py --strict` | TOTAL: 0 |
| clang-format | the touched code formatted; remaining deviations pre-existing (`render1.cpp` the two `CreateFileW` lines of `RenameFileInternal`) |
| Line endings / BOM | every touched source keeps its form; `salpvpixel.h` BOM + CRLF like `salpvsource.h`; `build_and_run.cmd` CRLF; specs and probe files LF without BOM |
| GUI | **pending** - commands in `quickstart.md` (`Debug_x64_120`, control `Debug_x64_pre120`, registry baseline `9BD42518403B7EDF...`) |

## T012 - code-only review: ACCEPT pending GUI

The reviewer rebuilt the pixharness (0 mismatches vs Pillow on 9 fixtures; the build before 2,295),
ran an ASan harness over salpvpixel.h (every row format, palette sizes, widths 1-70, exact-size rows)
and the real engine + reader (animated GIF, TIFF pages of different sizes, alpha, 1x1, 1001x1, 16-bit
gray, CMYK, 16-colour, bilevel; pipette refuses every out-of-image position; histogram counts exactly
w*h; rotation re-apply equals a fresh decode through detach/re-attach and page changes): 0 failures.
sfaReplaced follows 111's operation-id rules; pasted/scanned images are never released; a failed
replace re-attaches the original target. Recorded NITs: PixelAccess.cpp:54/:96 falls back to the
caller's bounds if the engine cannot report the row size (cannot happen with this engine - fail-open
by design); render1.cpp:1407 a failed pipette read keeps a stale tooltip; render1.cpp:3017 a target
window showing only a modal dialog (Save As, Rename) is not treated as busy and reopens underneath
(a rotation done only there is lost - same exposure 111 accepted; the user answered Yes to the
overwrite); render1.cpp:3020 a target whose new content will not open keeps the old picture under
the same title; a background-colour change while an image is let go applies at the next change
(111 code).

Committed after this review with the GUI runs still owed; the build is preserved as
`build\tandemcommander\Debug_x64_120`. The visible-desktop pipette rows need the maintainer's
agreement. Results follow in a separate commit.

## Recorded, not changed

- **PictView's print preview is empty** in every release since 006: `print.cpp CreatePreview` asks
  `PVSaveImage` for scaled, cropped, flipped raw rows; the WIC engine supports only unscaled rows
  (`WicSaveImage`, the thumbnail subset) and refuses. Printing itself draws through `PVDrawImage`
  and works. NEXT-WORK.
- The pipette's coordinates on a mirrored image are those of the shown image (as the selection's
  and the crop's), the color is the shown pixel's.
- The pipette and the histogram report the colors as shown: transparent parts composited over the
  viewer's background color.
- A GIF comment outside ASCII is UTF-8 (decided above); a reader that decodes it as Latin-1 shows it
  garbled.
- After a Rename onto a file another window shows, that window shows the renamed file's content
  under the name it already had (decided above); its mirror is kept (111's `ReopenKeepingView(TRUE)`
  for windows that did not write the file).
- `RedecodeTurned` decodes synchronously (as the lazy decode at the next paint did, also without
  progress).

## GUI results (2026-10-06 06:45-07:30)

Run one at a time, on the preserved trees `Debug_x64_120` and `Debug_x64_pre120`; no
tandemcommander.exe before each run; registry baseline SHA-256 `1AB614304771DBE0...` checked
before the first run, restored and verified identical by every probe, and again by a separate
export after the last run; `HKCU\Control Panel\Desktop` wallpaper values unchanged (111's
`wp-real` PASS; the 111 wallpaper rows on the dry-run seam). Nothing built.

| Run | Tree | Result |
|---|---|---|
| `pv120_probe.ps1` (hidden desktop) -> `probe/pv120_result.txt` | `Debug_x64_120` | **17 PASS / 0 FAIL / 5 NOT DRIVEN**: `tgt-shown` (z.png = x's content, A/B/C titled z.png, B and C show x's pixels, z held again, no error), `tgt-shown-no`, `tgt-shown-hl`, `tgt-shown-print`, `bk-rot` (30x40, pixel-exact), `cmt-gif-ascii`, `cmt-gif-u8`, every END row; NOT DRIVEN `hist-*` (the hidden desktop renders nothing - the capture shows no tone band), `pip-*` (no cursor) |
| the same -> `probe/pv120_result_pre120.txt` | `Debug_x64_pre120` | 15 / **2 FAIL** / 5: `tgt-shown` FAIL (`Error Renaming File` **(5) access denied**, z.png unchanged, B still shows z), `bk-rot` FAIL (Save As 40x30 unrotated while the title says 30 x 40); `tgt-shown-hl` PASS on this build too (see below) |
| 111 `shown_probe.ps1` -> `probe/regress_shown111_120.txt` | `Debug_x64_120` | **85 / 0 / 2** (as 111's own result), `wp-real` PASS |
| 105 `saveas_probe.ps1` -> `probe/regress_saveas105_120.txt` | `Debug_x64_120` | **56 / 0 / 4, existing files lost 0** |
| `pv120_probe.ps1 -VisiblePipette` (visible desktop, `TC_PROBE_ALLOW_VISIBLE_DESKTOP=1`) -> `probe/pv120_pipette.txt` | `Debug_x64_120` | `pip-plain`, `pip-mirror` **NOT DRIVEN**: the session is locked - `SetCursorPos` works, but the window at the viewer's place is `LockScreenBackstopFrame` and the foreground window the lock screen, so no mouse message reaches the viewer (two earlier attempts recorded FAIL "0 positions read" before the probe learnt to tell this). Stopped there as instructed; the control run on `Debug_x64_pre120` was not made |

Findings of the runs:

- **The error on the build before is 5 (access denied), not 32**: `MoveFileExW(REPLACE_EXISTING)`
  onto a file another process holds open without `FILE_SHARE_DELETE` answers 5. The backlog (111)
  and this feature's first records said 32 / "in use"; `research.md` and `spec.md` are corrected.
  **Outside this folder, not edited (instruction: no edits outside `specs/120-...` during the GUI
  runs), owed:** the `CHANGELOG.md` entry says *"failed with "used by another process""* - should
  say *"Access is denied"*; the comment in `render1.cpp RenameFileInternal` says *"failed "in use"
  (32)"* - should say 5; the `NEXT-WORK.md` entry says *"GUI runs pending"*.
- **A window showing the target through a hard link never blocked the rename** (`tgt-shown-hl`
  PASS on both builds): Windows replaces the name z.png although the same file is open through
  hz.png without delete sharing. On this build that window lets go and re-attaches; the row
  verifies that it keeps its own file and is held again - it is not a demonstrator of the defect.
- `tgt-shown-print`: the refusal on both builds is the same error 5 box; probe expectation
  corrected (see below).
- No product defect found.

Probe-only fixes made during the runs (`probe/pv120_probe.ps1`, no product file touched):
1. `tgt-shown-print` and the "no error" checks of the other rename rows now look for the
   `Error Renaming File` box instead of the text of error 32 (the first full run on
   `Debug_x64_120` reported this row FAIL only because of that expectation; re-run alone and then
   the whole probe again: PASS).
2. The pipette rows sample a grid over the window's middle (the 120 x 90 image is centered at
   100 %) and report NOT DRIVEN, with the window under the cursor and the foreground window named,
   when the viewer is not under the cursor (a locked session).

Still owed to a person (unlocked visible desktop): the pipette rows on both builds
(`quickstart.md` step 4) and the histogram rows (`-Only hist-*` with
`TC_PROBE_ALLOW_VISIBLE_DESKTOP=1` on the visible desktop, or by hand - `quickstart.md`); the
harness covers the reader on the real engine's rows meanwhile (0 mismatches; the build before
2,295).

## CLAUDE.md "Recent Changes" entry (proposed)

- 120-pictview-leftovers: **PictView's pipette and histogram read the real
  pixels; a Rename onto a file another window shows goes through; a
  rotation survives a new background color.** The "Found by 111" entries of
  NEXT-WORK, measured first (`research.md`) with a harness that compiles
  the plug-in's own `wicengine.cpp` + `PixelAccess.cpp` twice (working tree
  / git revision) and compares with Pillow (`probe/pixharness/`).
  - **Pipette / histogram**: the WIC engine hands out 32-bit rows for every
    image (`PV_COLOR_TC32`, stride width x 4); the reader took 3 bytes per
    pixel - pipette wrong for 3 of 4 pixels of every row of every image,
    all histogram channels wrong (2,295 mismatches over 9 fixtures; now 0).
    One pure reader for both, `src/common/salpvpixel.h`
    (`SalPvReadRowPixel`, `SalPvHistogramRow`, `SalPvShownToRow`), bounded
    by the engine's own rows (`WicGetRowsSize`). Also: a mirrored image
    showed the pixel opposite the cursor (the viewer mirrors at draw time,
    the rows never are), `ClientToPicture` overflowed 32 bits zoomed into a
    large image. Other consumers checked: clipboard and print draw through
    `PVDrawImage`, thumbnails take 32-bit rows, Save As / wallpaper encode
    the DIB - correct.
  - **Rename onto a shown target**: the target's windows let it go after
    "Yes" (`ReleaseShownFile(target, own FALSE)` around the replacing
    `MoveFileExW`) and then show what the name holds (`sfaReplaced` = the
    `sfaUnknown` rule: a hard link re-attaches, else reopen at the same
    zoom); busy windows keep it ("in use" as before).
  - **Rotation** (105's record): `WicSetBkHandle` re-decoded lazily without
    the viewer's turns (drawn squeezed, saved unturned) - the engine counts
    `Turns` and turns a frame it decodes again (`RedecodeTurned`).
  - **GIF comment, decided**: ASCII as is, other text UTF-8 (GIF has no
    Unicode alternative - the encoder refuses XMP, measured); no change.
  - Found, recorded: the print preview is empty since 006 (`PVSaveImage`
    with scaling refused by the WIC engine).
  - saltests 14,655 -> 17,423. No new string, interface 107, no registry
    change. Probe `probe/pv120_probe.ps1` (hidden desktop; the pipette rows
    only with `-VisiblePipette` on the visible desktop - the pipette follows
    the real cursor) written, GUI runs pending. Records:
    `specs/120-pictview-leftovers/fix-log.md`.
