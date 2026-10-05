# Fix log: feature 111 - PictView works on the image it shows

Branch `111-pictview-shown-image`, from `110-zip-plugin-name-matching` (018ec169). Decisions by the
author (the maintainer asked for autonomy): `spec.md` *Clarifications*. Measurements behind every
decision: `research.md`. Pre-change build: `build\tandemcommander\Debug_x64_pre111`. Not committed
(the coordinator commits after an independent review).

## Measured first - the premises

All right, and one more broken operation (`research.md` section 0/1, `probe/shown_result_pre111.txt`):
Rename of the shown image fails with 32 for every name and file system (NTFS, WebDAV); **Delete**
of the shown image ends in the shell's "File in use" window; a second window on the file makes
Save As, Rename and Delete fail; an opaque 32-bit PNG/TIFF/ICO asks the alpha question; bilevel
sources are never offered "2 colors" / CCITT; the default depth is always 24-bit; the title says
16777216 colors for every image; the TIFF comment is UTF-8 in tag 270 only; the JPEG COM ends with
00; a failed Save As over the shown image resets zoom and mirror. Nothing was lost in any of these.
The wallpaper commands were read, not run: the build before calls
`SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, NULL, ...)` for every command, also after its
failed save (section 4).

## T003/T004 - engine (`wicengine.{h,cpp}`, `src/common/salpvsource.h` new)

- `WicDetachSource` records the frame count, decoded frame and info frame (`Detached` only for a
  decoder opened on a file) and keeps the source format of the frame in memory.
- `WicReattachSource(handle, u8Path)`: a new decoder on the file's current name, accepted only
  with the same container format and frame count; the DIB (with the viewer's rotations) stays, so
  nothing is redrawn or reset. On failure the image stays detached (drawn from memory).
- `WicGetSourceFormat`: `SourceFormatOf` maps the frame's WIC pixel format - BlackWhite -> 2;
  indexed -> the palette's size (`SalPaletteColorsForSave`: <=2 -> 2, <=16 -> 16, else 256; a
  gray 256-entry palette -> 256 gray); gray formats -> 256 gray; 555/565/5551 -> 15/16-bit; CMYK
  formats -> 24-bit + CMYK; otherwise 32-bit if `IWICPixelFormatInfo2::SupportsTransparency`, else
  24-bit. Alpha use is recorded at decode: `CompositeOverBackground` returns whether a pixel was not
  opaque (no extra pass). An alpha channel that is not used reports 24-bit.
- `PVImageInfo::Colors` stays `PV_COLOR_TC32` (the pipette and the histogram read the rows by it).
- Comments: TIFF outside ASCII also `/ifd/xmp/<xmpalt>dc:description/x-default` (measured: the only
  query that writes the lang-alt XMP property); JPEG: `JpegDropCommentNul` after the commit (the
  segment found by the pure `SalJpegCommentNul` - only the first COM before SOS, exactly the text +
  one NUL, else untouched; length - 1, the rest of the file one byte to the front, `SetEndOfFile`;
  a failure is a write error, the caller discards the temporary file).

## T005 - release/retake (`render1.cpp`, `renderer.h`, `pictview.{h,cpp}`)

- `ReleaseShownFile(wPath, own, &rel)`: this window (`OnReleaseFileRequest`: shown here by 105's
  `IsShownFile`, not loading -> `WicDetachSource`, `FileReleased`) and every other viewer window
  (snapshot of `ViewerWindowQueue` - new `CViewerWindowQueue::GetWindows`; `WM_USER_RELEASEFILE`
  by `SendMessageTimeoutW(SMTO_NORMAL | SMTO_ABORTIFHUNG, 5 s)`; result 1 = let go).
- `RetakeShownFile(&rel, after, newName)`: `WM_USER_RETAKEFILE` to the windows that let go, then
  this window. `OnRetakeFile`: `sfaSame` -> (new name taken) `WicReattachSource`; `sfaChanged` ->
  `OpenFile` again, the zoom type/factor restored, the mirror restored except in the window that
  saved (its mirror went into the file); `sfaGone` -> `<Deleted>`.
- Message data (path, new name) is a heap copy per window, freed when the window answered or when
  the window no longer exists; after a time-out it is left alone (the message may still be handled).
- Rename: release before each `RenameFileInternal` attempt (103's guarded code unchanged inside),
  retake with the new name or the old one. Delete: release before `SHFileOperationW`, retake
  `sfaGone` when the file is gone, else `sfaSame`.

## T006 - Save As (`saveas.cpp`)

- `SaveImageSafe` builds the parameters and calls `EncodeReplaceSafe` (105's body: mirror + DPI,
  temporary file, encode, flush, release every window showing the target, `SalReplaceWithTempW`,
  retake: `sfaChanged` when replaced, `sfaSame` otherwise; the left-at-temp name is returned wide and
  turned into the UTF-8 message by the caller). The 105 reload after the message box is gone.
- The alpha question: `SalAlphaWouldBeLost(HasAlpha, AlphaUsed)` - any format, no format list.
- `srcInfo` (`GetSourceImageInfo`: `pvii` with the source's colors / color model / bit depth) for
  the mono type list and `FillTypeFmt` (default depth, "2 colors" offered for a bilevel source -
  Open Salamander's rule, now reachable). The static options never keep the pointer to it
  (`storeOptions`).
- Title (`SetTitle`) and Image Information (`CMD_IMG_PROP`) from `GetSourceImageInfo`.

## T007 - wallpaper (`render2.cpp`, `PRIVACY.md`)

- `SaveWallpaperFile`: `SHGetFolderPathW(CSIDL_LOCAL_APPDATA)` + `\Tandem Commander` (created on
  demand) + `\PictView_Wallpaper.bmp`, 24-bit BMP through `EncodeReplaceSafe` (a folder of that
  name refused).
- `SetAsWallpaper`: wide registry reads (`WpRegRead`); Center/Tile/Stretch: the file first (any
  failure: message, nothing else changes), then `Prev*` (only when the current wallpaper is not
  ours), `WallpaperStyle`, `TileWallpaper`, `WpApply(file)`; Restore: current -> `Prev*`, the stored
  style/tile (when not empty), `WpApply(prev)` ("" when there is none); None: current -> `Prev*`,
  `WpApply("")`. `WpApply` = `SystemParametersInfoW(SPI_SETDESKWALLPAPER, path,
  SPIF_UPDATEINIFILE | SPIF_SENDCHANGE)` - never NULL.
- Dry-run seam: `TC_PICTVIEW_WALLPAPER_DRYRUN` = a log file; `WpRegWrite` and `WpApply` (the only
  writers) append `SET <value>=<data>` / `SPI_SETDESKWALLPAPER <path>` (UTF-8) instead.
- Errors: `IDS_SAVEERROR` with the system's text (`FormatSaveErrorU8`, saveas.cpp).
- `PRIVACY.md`: new *Desktop wallpaper* section, the temporary file sentence, what uninstall leaves,
  removal steps, the 0.1.8 paragraph, validity line 2026-10-05.

## T009 - saltests `TestPvSource111`

Palette colors (12), the alpha rule (4), `SalJpegCommentNul` (13: found / another length / zero /
beyond the read / not JPEG / no NUL / SOS first / broken chain / stray byte / first after SOI with
UTF-8 / only the first COM). **saltests 14,140 -> 14,169, 0 failed.**

## T010 - probe `probe/shown_probe.ps1` (hidden desktop)

Fixtures by Pillow (`mkfix111.py`); every saved file decoded by Pillow and its tags / COM read by
hand (`pilcheck.py`); `-NoWallpaper` for the build before.

| Rows | This build | Debug_x64_pre111 |
|---|---|---|
| `ren-ascii/cyr/cjk` | renamed; the viewer holds the file again under the new name (open for DELETE -> 32); zoom 125 % kept; a Save As of the shown image pixel-exact | "Error Renaming File (32)" |
| `ren-locked`, `ren-tgtlocked` | refused (32), both files intact, held again under the old name | the same |
| `ren-tgtro` (onto a read-only file, overwrite Yes) | replaced, title the new name | 32 |
| `dav-fold` (WebDAV, NFD -> NFC, the folding server answers "already exists") | the server holds exactly `Café.png` with the content - 103's guard route in PictView, never reached before | 32 |
| `dav-plain` | renamed | 32 |
| `del-yes` (`\\localhost\C$`, "permanently delete?" Yes) | gone, title `<Deleted>`, the image still saveable | "File in use", file stays |
| `del-no` | file kept, held again | the same |
| `two-save` (A saves over the file, rotated 90; B mirrored before) | saved 30x40; both titles 30x40; A shows the file, B shows it mirrored (its view kept) | "Unable to save ... (32)" |
| `two-ren`, `two-del` | B shows the new name / `<Deleted>` | 32 / "File in use" |
| `alpha-opq-png/tif/ico` | no question | asked |
| `alpha-real-png/tif` | asked | asked |
| `depth-bl-png`, `depth-bl-tif` | "2 colors" default, CCITT G3/G4 offered; saved CCITT G4 TIFF / 1-bit PNG pixel-equal to the source | 16 colors and up, no CCITT |
| `depth-gray`, `depth-pal16`, `depth-bl-title` | default 256 gray / 16 colors / 2 colors; title 256 / 16 / 2 colors | 24-bit, 16777216 colors |
| `depth-rgb` | 24-bit (unchanged) | the same |
| `cmt-tif-u8` | tag 270 UTF-8 + NUL and XMP dc:description = the text | no XMP |
| `cmt-tif-ascii` | tag 270 ASCII, no XMP | the same |
| `cmt-jpg-u8`, `cmt-jpg-ascii` | COM = the text, no NUL | + `00` |
| `cmt-gif` | unchanged | the same |
| `view-fail` (replace fails: file held elsewhere) | zoom kept, still mirrored (the next save mirrored) | zoom 125 -> 100, mirror lost |
| `view-ok` | the mirrored image in the file, zoom kept, not mirrored twice | zoom reset |
| `wp-center/tile/stretch/restore/none` (dry run) | BMP 24-bit 40x30 pixel-exact, rewritten each time; log: style/tile values, `Prev*` = the current values, SPI path = the file / the stored previous / "" - never NULL | NOT DRIVEN (would change the desktop) |
| `wp-real` | the real wallpaper values and `SPI_GETDESKWALLPAPER` unchanged | the same |
| total (before the review) | 69 PASS / 0 FAIL / 2 NOT DRIVEN | 40 PASS / 23 FAIL / 7 NOT DRIVEN |

Every row's END: exit 0, no crash report, no stray window. Registry restored and identical in
every run (SHA-256 `1AB614304771DBE0...`). Probe history: run 1 on the first build 65/0/3 (the
WebDAV rows were added during it); the final binary 69/0/2. The first pre-111 run answered the
re-opened Rename dialog with OK (six error boxes per row) - the probe now cancels it.

NOT DRIVEN: Delete into the Recycle Bin (it would put probe files into the user's Recycle Bin; the
code path differs only by `FOF_ALLOWUNDO`); the real `SPI_SETDESKWALLPAPER` and the
`HKCU\Control Panel\Desktop` writes (never - the hidden desktop shares the user's wallpaper; code
review + the dry-run log).

## T011 - Gates

| Gate | Result |
|---|---|
| Debug build (`build.cmd`) | exit 0, no warning |
| Release (`build.cmd full release`) | exit 0; 20 plug-ins, 189 language modules, runtime closure OK |
| saltests | **14,169 / 0** (14,140 before; `TestPvSource111` +29) |
| `tools/check_encoding.py --strict` | TOTAL: 0 |
| clang-format | the touched code formatted; remaining deviations pre-existing (`render1.cpp` 8 lines, `pictview.cpp` 2, `saltests.cpp` include block) |
| Probe 111 | 69 / 0 / 2 before the review, 83 / 0 / 2 after it (pre-111: 49 / 28 / 7, T013) |
| 105 `saveas_probe.ps1` (`probe/regress_saveas105_111.txt`) | 56 / 0 / 4, 0 files lost - as before (its `shown` row now goes through the release/retake) |
| 103 `samefile_probe.ps1 -Expect103` (`probe/regress_samefile103_111.txt`) | 62 / 0 as before (all routes; its PictView rename route has no case of its own - `dav-fold` of this probe drives 103's guard in PictView) |
| 104 `plugnames_probe.ps1 -Only pv-copyto,pv-saveas` (`probe/regress_plugnames104_111.txt`) | 4 / 0 as before |
| 088 `viewers_probe.ps1` (`probe/regress_viewers088_111.txt`) | 7 / 3 - identical to 105's run (`regress_viewers088_105.txt`): the PictView rows P3, P5, N1a pass; P1/P2 (Code/Markdown Viewer) time out and N3 gets the Code Viewer's question on the hidden desktop on every build (105 fix-log) |
| Real wallpaper | unchanged after every run (`wp-real`) |
| Line endings / BOM | every touched source keeps its form (BOM where it had one, CRLF); the new header BOM + CRLF; specs and probe files LF without BOM |

## T013 - independent review: REJECT (1 blocker, 3 SHOULD-FIX, NITs) - fixed

The reviewer reproduced 69/0/2 and confirmed formats, second-window rename, Save As of a `<Deleted>`
window, the comments and the wallpaper's "never NULL / a failed save changes nothing", and found:

- **B1 (driven): a window that moved to another file was given the old file's identity.**
  `FileReleased` was cleared only by the retake; `OpenFile` never cleared it and nothing checked that
  the window still showed the released image. Window B's thread is free while A waits on a question:
  A deletes x.png, B goes to y.png during "permanently delete?", Yes -> B titled `<Deleted>` while
  showing y.png; A renames x.png onto z.png, B moves to y.png during the overwrite question, Yes -> B
  named z.png while showing y's pixels (its Rename/Delete/Save As then act on z.png). Fix
  (`render1.cpp`, `renderer.h`, `wicengine`): `OpenFile` drops the released state (`ForgetRelease`
  before it closes the old image); the retake acts only on the released handle while it is still
  detached (`WicIsDetached`, new); the request carries an operation id (`CShownFileRequest`,
  process-wide `ShownFileOps`): a request handled after its operation ended is a no-op, and a window
  whose retake never came takes the file back on a 1-s timer (`RETAKE_TIMER_ID`) once the operation is
  over (the late-release NIT). Re-attach only when the file's identity, size and last write time are
  those of the release (`TakeBackIfSame`, 103's `salsamefile.h`), else the file is opened again
  keeping the view (the NIT "any file of the same format and frame count").
- **NIT hard links / aliases:** the request remembers whether it named the window's own path
  (`ReleasedSamePath`); `<Deleted>` and a new name apply only then - a window showing the file under
  another path keeps its name and re-attaches (a hard link survives a delete); its own path gone
  after a rename, it takes the new name when that is the same file.
- **S1 (code reading): use-after-free.** Save As's progress hook (`PeekMessage`) and the Print dialog
  dispatch sent messages, so a window encoding or printing answered "let go" and then, on
  `sfaChanged`, reopened the file and freed the image its encoder / print dialog still used. Fix:
  `ImageBusy` (around the encode in `EncodeReplaceSafe` - also the wallpaper - and over the whole
  `CMD_PRINT`): such a window answers 2 and keeps the file; the other window's operation fails "in
  use" as before. Probe `r-print` (deterministic: B's Print dialog open, A saves over the file ->
  "Unable to save ... (32)", file unchanged, B's image intact); `r-busy` (B's slow 256-color save
  while A saves) is timing-dependent and recorded as it happened.
- **S2 (dry-run driven): wallpaper backup.** Restore with nothing backed up passed "" (removed the
  wallpaper); None overwrote the backup with our BMP or "" when run twice (pre-existing). Now:
  Restore does nothing when there is no backup (no message - no existing string fits); the backup is
  written only after `SystemParametersInfo` succeeded and never empty - Center/Tile/Stretch and None
  never back up our own file, Restore backs up the one it replaces (also ours, so a second Restore
  swaps back; re-review wording NIT); the style
  values written for the call (Windows reads them there) are put back when it fails. `PRIVACY.md`
  corrected (Restore "switches to the remembered background and remembers the one it replaced ...
  does nothing when no background is remembered") and now names `WallpaperStyle`/`TileWallpaper`. Probe rows corrected:
  `wp-restore` (the maintainer's registry has no backup) requires an EMPTY log; `wp-none` requires the
  SPI line first and the backup only for a worthy current wallpaper; Center/Tile/Stretch require the
  backup lines after the SPI line.
- **S3 (driven): multi-page TIFF title** showed the previous page's colors - `WicGetSourceFormat`
  now reads the info frame (the title is set before the new page is decoded). Probe `r-multi`.
- **NIT failed reopen** dropped a non-saving window's mirror - `ReopenKeepingView` puts the mirror
  back when the file cannot be opened (and for every non-saving window).
- **CMYK Image Information**: measured `CMYK` on this build (probe `info-cmyk`: the dialog's Colors
  field read by WM_GETTEXT; the title says CMYK too) - not reproduced, no change.
- **Recorded as shipped behaviour:** the dry-run switch `TC_PICTVIEW_WALLPAPER_DRYRUN` is compiled
  into the Release build too. Set in the environment of a Tandem Commander process, its wallpaper
  commands write the picture file but no registry value and call no `SystemParametersInfo` (they log
  instead). It has no other effect.
- Process note: one probe fixture edit was made with `sed -i` on `probe/mkfix111.py` (against the
  house rule); the file was checked afterwards (LF, no control characters) and later edits were made
  with Python.

| Rows after the review | This build | Debug_x64_pre111 |
|---|---|---|
| `r-nav-del` | B shows and holds y.png, x.png deleted, A `<Deleted>` | x.png not deleted ("File in use" - A holds it); B moved to y.png |
| `r-nav-ren` | B shows and holds y.png, z.png holds x's content, A named z.png | not renamed (32) |
| `r-multi` | page 1 16777216 colors, page 2 2 colors | both pages 16777216 colors |
| `r-print` | A "Unable to save (32)", file unchanged, B intact | the same (B holds the file anyway) |
| `r-busy` | no crash, both files valid; in the final run B had finished before A asked (in a review-row run B was still encoding and kept the file - the refusal path) | no crash; the shown file unchanged (B holds it) |
| `hl-del` | B keeps b.png and holds it, A `<Deleted>` | a.png not deleted ("File in use") |
| `info-cmyk` | CMYK | "TrueColor 24Bit", title 16777216 colors |
| total | **83 PASS / 0 FAIL / 2 NOT DRIVEN** | 49 PASS / 28 FAIL / 7 NOT DRIVEN |

After the fixes: saltests 14,169 / 0; strict guard TOTAL 0; Debug and full Release builds exit 0 (20
plug-ins, 189 language modules, runtime closure OK); probe 83 / 0 / 2 (`probe/shown_result.txt`),
pre-111 49 / 28 / 7 (`probe/shown_result_pre111.txt`); regressions 105 saveas 56 / 0 / 4 (0 files
lost) and 103 samefile 62 / 0 re-run on the final binary; registry hash `1AB614304771DBE0...` and
the real wallpaper unchanged after every run.

## T014 - re-review: REJECT (B1 second route) - fixed in code, GUI runs pending

- **Blocker (driven `r-cross` by the reviewer):** `\\localhost\C$` folder; A and B show x.png, C shows
  y.png. A starts deleting x.png, B goes to y.png, C starts renaming y.png onto z.png and B lets y go
  for C's operation; A's delete confirmed -> B (showing y) became `<Deleted>`; C declined, y.png held
  by C, B stayed `<Deleted>` and detached for good. The take-back carried no operation id, so A's
  `sfaGone` was applied to B's release for C's operation. Fix: `WM_USER_RETAKEFILE` now carries
  `CShownFileRetake` (operation id, outcome, new name); `OnRetakeFile` acts only when the id is the
  window's `ReleasedOp` (the timer passes its own); every message of the protocol carries the id.
- **NIT, fixed:** a window already let go for another window's operation now holds the release for
  its OWN operation (`OnReleaseFileRequest(..., own)` re-assigns `ReleasedOp`), so the other
  operation's take-back can no longer re-attach the file in the middle of the window's own rename
  (which then failed "in use"); the own operation's take-back decides.
- **NIT, wording corrected:** the backup is never empty; Center/Tile/Stretch and None never back up
  PictView's own file, Restore backs up the one it replaces (also ours) so that a second Restore swaps
  back - `render2.cpp` comments, `PRIVACY.md`, `CHANGELOG.md`, `spec.md`, T013 above.
- Probe: new row `r-cross` (both builds).
- Gates on the final code: Debug build exit 0, saltests 14,169 / 0, strict guard TOTAL 0, full Release
  build exit 0 (20 plug-ins, 189 language modules, runtime closure OK).
- **GUI runs pending**: the maintainer's installed Tandem Commander was running (shared
  `HKCU\Software\Tandem Commander`), so no probe was run on this code; `probe/shown_result.txt`,
  `shown_result_pre111.txt` and the regression files are still those of T013 and need the re-run
  listed in the report (the probe itself refuses while any tandemcommander.exe runs).

## T015 - code-only re-check of the T014 fix: ACCEPT pending the GUI run

The reviewer read the delta (no GUI: the maintainer uses the installed program during the day,
which shares the registry key with the probes). The operation id travels in the release request
(`CShownFileRequest`) and the take-back (`CShownFileRetake`), the own take-back and the timer use
the stored `ReleasedOp`; `OnRetakeFile` returns unless the id matches; a request handled after its
operation ended gets 0 (`IsActive`). Ids start at 1 and wrap to 1 after 2^31; more than 64 active
operations leave the new one untracked (it then fails "in use", as before 111). The takeover of
a release by the window's own operation keeps the identity of the first release; every path ends
in `DropReleasedState`; heap copies per window, a timed-out copy deliberately leaked, never
dangling. NIT: a release that times out and is handled late, for an operation that deleted or
renamed the file, leaves that window detached under its old name (no data path).

Committed after this check with the GUI runs still owed (`r-cross`, `r-nav-del`, `r-nav-ren`,
`r-multi`, the whole probe on this build and on pre-111, regressions 105 and 103) - to be run in
the evening on the preserved build tree `build\tandemcommander\Debug_x64_111`; their results
and any fix follow in a separate commit.

**GUI runs, 2026-10-05 evening (23:15 on), hidden desktop, one at a time, no tandemcommander.exe
running before each run; registry baseline now SHA-256 `9BD42518403B7EDF...` (the maintainer's
installed copy saved its settings), equal before and after every run (each probe's own backup and
restore; checked once more by a separate export afterwards); wallpaper rows on the dry-run seam,
`wp-real` PASS in both shown-probe runs; no Recycle Bin; nothing built:**

| Run | Tree | Result |
|---|---|---|
| `shown_probe.ps1` -> `probe/shown_result.txt` | `Debug_x64_111` | **85 PASS / 0 FAIL / 2 NOT DRIVEN** - `r-cross` PASS (B moved to y.png, x.png deleted, y.png and z.png unchanged, B and C show y.png, y.png held again, B's Save As = y.png's pixels), `r-nav-del`, `r-nav-ren`, `r-multi`, `r-print`, `hl-del`, `info-cmyk`, `wp-restore` (empty backup: empty log) PASS; `r-busy` PASS with B finished before A asked (the refusal path not exercised in this run - `r-print` covers it deterministically) |
| `shown_probe.ps1 -NoWallpaper` -> `probe/shown_result_pre111.txt` | `Debug_x64_pre111` | 50 PASS / 29 FAIL / 7 NOT DRIVEN - `r-cross` FAIL (x.png not deleted: "File in use"); every END row PASS |
| 105 `saveas_probe.ps1` -> `probe/regress_saveas105_111.txt` | `Debug_x64_111` | 56 PASS / 0 FAIL / 4 NOT DRIVEN, existing files LOST 0 |
| 103 `samefile_probe.ps1 -Expect103` -> `probe/regress_samefile103_111.txt` | `Debug_x64_111` | 62 PASS / 0 FAIL (WebDAV rows driven) |

No defect found; T014 is closed by these runs.

## Recorded, not changed

- **PictView's pipette and histogram read the 32-bit rows as 3 bytes per pixel** (`PixelAccess.cpp`,
  every release since 006; code reading; display only) - NEXT-WORK.
- A Rename onto another file that a second PictView window shows still fails "in use" - only the
  renamed file's windows let go (nothing lost).
- The GIF comment extension gets UTF-8 although GIF89a defines 7-bit ASCII (no alternative in GIF).
- A TIFF comment outside ASCII: tag 270 holds UTF-8 (Windows' own practice); readers that decode it
  strictly as Latin-1 (Pillow) show its bytes there but find the text in XMP.
- After a save over the shown image the window that saved shows the file without its former
  mirror (the mirror is in the file now) - deliberate.
- The wallpaper file stays when the background is changed elsewhere; Windows keeps its own
  settings; the `Prev*` value names are PictView's of old (written in `HKCU\Control Panel\Desktop`).
- A viewer window that is loading, or does not answer in 5 s, keeps the file: the operation fails
  "in use" as before; a timed-out message's data block is not freed (a few bytes).
- 103's "left at the temporary name" outcome of a Rename: the window keeps the image in memory
  (it cannot be re-attached under the old name).

## CLAUDE.md "Recent Changes" entry (proposed)

- 111-pictview-shown-image: **PictView renames, deletes and saves over the
  image it shows.** The PictView entries of NEXT-WORK found by 103 and 105,
  measured first (`research.md`): Rename of the shown image failed with 32
  (NTFS and WebDAV), **Delete** of it too ("File in use" - not in the
  backlog), a second viewer window on the file blocked Save As, Rename and
  Delete; every opaque 32-bit PNG/TIFF/ICO asked "the alpha channel will be
  lost", "2 colors"/CCITT were never offered, the title said 16777216 colors
  for every image (the engine reports its 32-bit rows); the wallpaper
  commands could not write and then called
  `SystemParametersInfo(SPI_SETDESKWALLPAPER, NULL)` (documented: revert to
  the default) - read, never run; TIFF tag 270 UTF-8 only, JPEG COM with a
  NUL; a failed save over the shown image reset zoom and mirror.
  - **Release/retake** (`render1.cpp`): before Rename, Delete and the
    replace step of Save As every PictView window showing the file
    (105's `IsShownFile`) lets its WIC decoder go (`WicDetachSource`);
    afterwards `sfaSame` re-attaches without a reload (`WicReattachSource`:
    new decoder on the current name, same container + frame count, the DIB
    untouched - zoom, mirror, rotation stay), `sfaChanged` reopens at the
    same zoom (the saving window drops its mirror - it is in the file),
    `sfaGone` titles `<Deleted>`. Other windows (own threads) via
    `WM_USER_RELEASEFILE`/`_RETAKEFILE`, `SendMessageTimeout(SMTO_NORMAL |
    SMTO_ABORTIFHUNG, 5 s)` to a snapshot of `ViewerWindowQueue`
    (`CViewerWindowQueue::GetWindows`); message data copied per window and
    never freed after a time-out; a loading window keeps the file (fails "in
    use" as before). Not chosen: `FILE_SHARE_DELETE` (pending-delete names on
    FAT/SMB, files changing under the viewer).
  - **Source format** (`WicGetSourceFormat`, pure rules in
    `src/common/salpvsource.h`): the palette's size decides (a 2-color GIF is
    8bppIndexed), `SupportsTransparency` = alpha channel, alpha use recorded
    at decode (`CompositeOverBackground` returns it). `PVImageInfo::Colors`
    stays TC32 (pipette/histogram read the rows by it). Used by the alpha
    question (only real transparency), Save As default depth / mono list /
    "2 colors" + CCITT, title, Image Information.
  - **Wallpaper** (`render2.cpp`): 24-bit BMP via `EncodeReplaceSafe` (105's
    temp + replace, shared with Save As) into `%LOCALAPPDATA%\Tandem
    Commander\PictView_Wallpaper.bmp`, wide registry, `Prev*` backup,
    `SPI_SETDESKWALLPAPER` with an explicit path (never NULL); a failed save
    changes nothing. **Dry-run seam** `TC_PICTVIEW_WALLPAPER_DRYRUN` (a log
    file) in the only two writers (`WpRegWrite`, `WpApply`): probes MUST use
    it - the hidden desktop shares the user's wallpaper; the probe refuses
    without the seam in `pictview.spl` and checks the real values before and
    after. `PRIVACY.md` updated.
  - **Comments**: TIFF outside ASCII = tag 270 UTF-8 (Windows' own
    `System.Title` practice, read back as UTF-8 - measured) + XMP
    `dc:description` (`/ifd/xmp/<xmpalt>dc:description/x-default`); JPEG COM
    NUL removed after the commit (`JpegDropCommentNul`).
  - Found, recorded (NEXT-WORK): pipette and histogram read the 32-bit rows
    as 3 bytes per pixel (every release since 006); a Rename onto a file
    another window shows still fails "in use"; GIF comments UTF-8.
  - Probe `probe/shown_probe.ps1` + `pilcheck.py` + `mkfix111.py` (hidden
    desktop, Pillow decode, WebDAV via 103's `davnorm.py` - `dav-fold`
    drives 103's guard in PictView for the first time): 83/0/2; pre-111
    49/28/7 (`-NoWallpaper`). Review REJECT (B1: a window that moved on was
    given the old file's name or `<Deleted>`; S1: a window encoding or
    printing let go and freed its image; S2: Restore without a backup removed
    the wallpaper; S3: multi-page title) - fixed: the retake acts only on the
    released, still detached image (`WicIsDetached`), `OpenFile` drops the
    release, operation ids in every message (a take-back acts only for the
    operation the window let go for - re-review `r-cross`) + a 1-s timer for
    lost retakes, re-attach only for
    the same file id + size + write time, `<Deleted>`/new name only for the
    operation's own path (hard links), `ImageBusy` refuses during encode and
    print, the wallpaper backup written only after SPI succeeded. Regressions: 105 saveas 56/0/4, 103 samefile 62/0, 104 PictView rows 4/0, 088 viewers 7/3 as on 105 (PictView rows pass; Code/Markdown Viewer rows fail on the hidden desktop on every build). saltests 14,140 ->
    14,169. No new string, interface 107, no registry format change.
    Records: `specs/111-pictview-shown-image/fix-log.md`.
