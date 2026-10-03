# Fix log: feature 098 - long-path overruns

Branch `098-long-path-overruns`, from `097-archive-long-path`.
Decisions by the author (maintainer away): `spec.md` *Clarifications*.

## S1 - the directory line (D1)

- `src/stswnd.h` `CHotTrackItem`: `Offset`, `Chars`, `PixelsOffset`, `Pixels` from `WORD`
  to `int`. The deepest hot-track item spans the whole path, so `Pixels` holds the
  path's rendered width - about 65,554 px at 7,475 characters (system GUI font, 125%):
  the `(WORD)` cast lost data and the Debug build stopped (RTC #1 "cast to smaller
  type"; Release wrapped silently). A 32,767-character path also has more than 65,535
  UTF-8 bytes, which the byte-unit `Offset`/`Chars` could not hold either.
- `src/stswnd.cpp` `BuildHotTrackItems`: the four `(WORD)` casts removed; the bottom
  line's `SubTexts` check compares in `DWORD` instead of `(WORD)len`.
- Checked and unchanged: every reader of the fields (`FindHotTrackItem`, `GetItemText`,
  `Paint`, the click handler, the bottom line's clipboard copy) already does `int`
  arithmetic; `AlpDX` is heap-sized from the text (bytes + 1 >= UTF-16 units); the
  text, the ellipsis loop and `DrawTextSeg` are `int`/heap; the tooltip goes through
  `CopyToolTipAnswer`; mouse `LOWORD/HIWORD` are client coordinates. `SubTexts`
  (`LOWORD` position / `HIWORD` length) is the info-line producers' packing - bottom
  line only, short texts - and stays. No other 16-bit storage of positions was found on
  this path.

## S2 - Change Directory to a file, clipboard path (D2)

- `src/fileswn3.cpp` `ChangeDir`, the "existing file, not an archive" branch:
  `char shortenedPath[MAX_PATH]` + `strcpy` replaced by a `CSalHeapString` copy of
  `copy` (+1 byte: `CutDirectory` moves the name one byte right for `C:\name`); the
  panel goes to the folder and focuses the file at any length. In the same function the
  "no disk / reparse point" parent check (`ERROR_INVALID_PARAMETER` / `ERROR_NOT_READY`)
  cut `copy` to MAX_PATH with `lstrcpyn` before `CutDirectory`: now a heap copy too. The
  focus name is bounded downstream (`ChangePathToDisk`: `SAL_FIND_NAME_U8`); `path` and
  `copy` are `SAL_MAX_PATH_UTF8`.
- `src/fileswn9.cpp` `ClipboardPastePath` (CM_CLIPPASTE 775 when the clipboard holds no
  files, and the "paste" of the shell context menu, `shellsup.cpp`): a text that does
  not fit `char[2 * MAX_PATH]` is refused with IDS_TOOLONGPATH and nothing else happens
  (it was cut at 519 bytes and opened). Leading and trailing blanks/CR/LF are trimmed
  before the length check. **Also changed**: the wide text is converted with `SalWToU8`
  (UTF-8, WTF-8) - `ConvertU2A` gave code-page bytes to `PostProcessPathFromUser`, whose
  contract is UTF-8 (a character outside the code page became `?`). The `CF_TEXT`
  branch (reached only without `CF_UNICODETEXT`) is unchanged except for the refusal.
- `CopyUNCPathToClipboard` (`fileswn9.cpp`; CM_CLIPCOPYUNCNAME 712 and the Find
  window's "copy UNC name"): the 097 review's mapped-drive branch (`uncPath` = share +
  rest of the path + name, unbounded `strcat`) is real but needs a mapped network drive
  and a location + name of about 505-519 bytes. Two twins in the same function were
  worse: the SUBST branch, `char target[MAX_PATH]` + `strcat(target, path + 3)` (a SUBST
  drive with a location over about 220 bytes), and the final message, `wsprintf` (up to
  1,024 bytes) into the 520-byte `uncPath` (a local path of about 420+ bytes that is
  neither shared nor mapped). The 097 guard sat only in the panel caller; the Find
  window called with no guard (`strcpy(buff[520], path)`). Now the guard is inside the
  function, every append is bounded (a result that does not fit is not converted),
  `target` is `2 * MAX_PATH`, the message is a `CSalHeapString`.
  `src/shares.cpp` `CShares::GetUNCPath` (hidden shares such as `C$`): the unbounded
  `strcat(unc, rest)` and the `lstrcpyn` that cut the result - a path that does not fit
  is now not converted.

## S3 - the packing walk and the external packer (D4)

- `src/fileswnd.h` `CPanelTmpEnumData::WorkPath`: `char*` on the heap (`SetWorkPath`,
  freed in the destructor). The struct is never copied - all six users are locals
  handed to the enumerator by pointer (`param`); copying is now declared private. The
  five fills (`fileswn7.cpp` Pack, `fileswn8.cpp` x2 copy/move into an archive or a
  plug-in FS, `fileswna.cpp` drop into an archive, `zip.cpp`
  `CallPluginOperationFromDisk`) copy the path whole.
- `src/fileswn7.cpp` `ReadDirectoryTree` / `_ReadDirectoryTree`: the walk's path buffer
  is `SAL_MAX_PATH_UTF8 + 4` on the heap (was `char[MAX_PATH]`). A folder whose path
  cannot be built - or that is nested deeper than 1,000 levels
  (`READDIRTREE_MAX_DEPTH`) - is reported with the existing IDS_NAMEISTOOLONG and
  OK (skip, SALENUM_ERROR) / Cancel, never skipped in silence (it returned TRUE and the
  archive lost the folder's contents). The recursion's find data and name buffers moved
  to a per-level heap block. (Corrected after the review: the Debug frame is still about
  1.5 KB - `sub rsp,5B8h` - so 1,000 levels need about 1.5 MB; it is safe because every
  caller runs on the main thread, 3 MB stack - `CallPluginOperationFromDisk` is
  main-thread only. The Release frame is in the review section.) The two "cannot read folder" messages are `CSalHeapString` (were
  `sprintf` into `char[2 * MAX_PATH + 100]`, unreachable before); the dir-link message
  name is trimmed with `SalU8TrimIncompleteTail` after its MAX_PATH cut.
- Plug-in contract: unchanged. What crosses into a packer plug-in is `sourcePath` (the
  panel path, whole since feature 004 - not changed here) and names *relative* to it from
  `PanelEnumDiskSelection`, which keep their MAX_PATH bound with the existing
  IDS_NAMEISTOOLONG skip/cancel prompt of `_PanelSalEnumSelection`. `WorkPath` is
  core-internal, so no refusal for plug-ins built for < 107 is needed. (Open, not
  changed: a plug-in built for < 107 already receives a `sourcePath` over MAX_PATH; the
  107 contract text covers only the archive name.)
- `src/pack2.cpp` `PackUniversalCompress`: a source folder that does not fit
  `sourceShortName[MAX_PATH]` is refused with IDS_TOOLONGPATH before the list file is
  written (was an unbounded `strcpy`). New helper `PackPathFitsMaxPath` (`pack.h`,
  `pack3.cpp`; message and title as `PackArchiveNameFitsHandler`).
- Twins fixed the same way - the path inside the archive for an external archiver:
  `PackCompress` `archiveRootPath[MAX_PATH]` (`strcpy`), `PackUniversalCompress`
  `rootPath` (`"\" + root`), `PackUniversalUncompress` `rootPath` (root + `"\"`,
  `pack1.cpp`), the delete `rootPath` (`pack2.cpp`); an in-archive folder path can reach
  about 511 bytes (`AddDir` checks the parent and the name separately at 255).
  `PackUniversalUncompress` `srcDir[MAX_PATH]` (temp folder + path in the archive +
  `\*`, unbounded `strcat`) is on the heap with a bound. Checked and left:
  `PackUnpackOneFile` (heap-sized), list-file names (relative, bounded), `strcpy(buffer[1000],
  cmdLine)` only for `!supportLongNames` (no such archiver since 084), OEM conversions
  (never longer than the UTF-8).

## S4 - the 7zip plug-in (D3)

- `extract.cpp` `OnDataError`: `_stprintf(msg[1024], ...)` -> `_snprintf_s(..., _TRUNCATE)`,
  text kept (the item path reaching it is at most about 510 bytes - the listing gate).
- `FStreams.cpp` `ShowRetryAbortBox`: `vsprintf(msg[1024])` and `_stprintf(buf[2052])`
  bounded the same way.
- `7zip.cpp:1455` (ISO caption): **correction to research.md** - the line is inside a
  `/* ... */` block (lines 1404-1494, a leftover copy of the UnISO viewer) and is not
  compiled. The live viewer is `src/plugins/uniso/uniso.cpp`, which already uses
  `_snprintf_s(caption[2000], _TRUNCATE)`, and the core cuts a viewer caption to MAX_PATH
  with `SalU8TrimIncompleteTail` (`viewer3.cpp`). The dead copy was bounded anyway so
  that it cannot come back if un-commented.
- The rest of the plug-in (not the 7za engine): numbers and dates into local buffers,
  `strcpy` into heap buffers of `U8_MAX_PATH` or of exact size, button labels - no path
  into a fixed buffer.

## Probes (S1-S4)

`probe/fix_probe.ps1` (+ `fix_probe_lib.ps1`; `click_debug.ps1` established the click
method). Hidden desktop; the registry SHA-256 identical after every run
(`1AB61430...F769`); fixtures removed; nothing left running. Results:
`probe/fix_result_s4.txt` (this build), `probe/fix_result_pre098.txt`
(`Debug_x64_pre098`).

| Case | This build | Before 098 |
|---|---|---|
| D1 ASCII 1,500 / 8,000 / 15,000 / 32,000 units (13-165 components) | GO, PATH, CLICK, UP, END: all PASS | 1,500 PASS; 8,000 / 15,000 / 32,000 crash at GO (RTC #1 "cast to smaller type", bug report) |
| D1 U+20AC 1,500 / 8,000 / 15,000 / 32,000 units (up to 95,554 bytes) | all PASS | 1,500 and 8,000 PASS (narrower glyph); 15,000 / 32,000 crash |
| D2 file path 300 / 1,000 bytes, ASCII and U+0159 | in the folder, the file focused (viewer title), END PASS | Debug assertion "Buffer is too small" at GO, all four |
| D2 clipboard paste (600 bytes; U+0159; U+4E2D) | not driven | not driven |
| D4 ZIP / 7z x Alt+F5 / F5 into an archive x 300 / 1,000 bytes x ASCII / U+0159 (16) | every file in the archive, content equal: 16/16 | 16/16 lose `sub1/b.txt` and `sub1/sub2/c.txt` - only `a.txt` (+ `seed.txt`), no message |
| D3 ISO at 2,100 bytes (ASCII, U+20AC), F3 | the UnISO viewer opens; caption cut to MAX_PATH by the core | same |
| D3 7z CRC error, item path 130 bytes, unpack | the message names the whole item path | same |

Rows: this build 94 PASS / 0 FAIL / 3 not driven; before 098 37 PASS / 34 FAIL / 3 not
driven. CLICK: the visible tail of the line is the same text at every depth (six
20-character components), so each deep case must land as many components up as the
shallow reference of its character set: all eight landed 5 up (x = 90 px). UP walked
8-160 x Backspace back to the chain root. The directory-line window has no text to read;
the location is read from the Change Directory field.

Not driven / probe notes:
- Clipboard paste: `OpenClipboard` is denied (error 5) to this session's processes on
  both desktops, so neither the probe nor the program can use the clipboard here (the
  user's clipboard was not touched). `ClipboardPastePath` is verified by reading only.
- `CopyUNCPathToClipboard` twins (SUBST, mapped drive, the message) and
  `CShares::GetUNCPath`: read only (they need the clipboard, a drive letter or a share).
- The external-packer refusals: WinRAR is not installed; read only. The walk's
  1,000-level and extreme-path refusals: read only (no such tree was built).
- The first posted click on a fresh hidden desktop does nothing (both builds;
  `click_debug.ps1`: x = 90 first -> nothing, then x = 60/90/120/250 land 5/5/4/4 up at
  1,500 and at 8,000 units alike); `fix_probe` posts one throwaway click in a throwaway
  instance first.

## Gates (S1-S4, Debug)

- Debug x64 build exit 0, no warnings in the log; `saltests` 13,119 checks, 0 failed;
  `tools/check_encoding.py --strict` TOTAL: 0.
- Files touched keep BOM + CRLF (checked per file).
- Regression probes on this build (results in `probe/regress_*_098.txt`; registry
  identical, fixtures removed, nothing left running after each):

  | Probe | Result | Before (097 records) |
  |---|---|---|
  | 095 `longarc_probe.ps1` | 60 PASS / 0 FAIL (Debug handle notes 4) | 60 / 0, handle notes 4 |
  | 096 `archedit_probe.ps1` | 17 of 17 UPDATED | 17 of 17 |
  | 097 `arcpath_probe.ps1 -Stage S2` | 55 PASS / 0 FAIL, twin rows 0 | 55 / 0 |
  | 097 `arcwork_probe.ps1` | 390 PASS / 0 FAIL / 21 n/a | 390 / 0 / 21 |

- Not done in S1-S4: the Release build, the independent review (T007, T008).

## Independent review (T007): REJECT, fixed

### B1 (blocker) - "Move to archive" could delete files outside the selection

Driven by the reviewer: selection A (1,005 levels of `d`) + B (junction J -> X outside
the selection, holding x.txt), Alt+F5 with "Delete files from disk after packing": on the
S1-S4 build no link warning appeared and `X\x.txt` was packed and **deleted** (ZIP and
7z); the build before 098 and the control without A showed the warning. Cause: the link
scan before the move is `ReadDirectoryTree` in silent mode (`parent == NULL`), and S3's
`ReportReadDirTreeTooLong` returned FALSE in silent mode - the scan stopped at A's level
1,001, found no link, and `Pack` read "no link"; the real pack then walked B, followed J
and the move deleted what it packed.

Fix (`src/fileswn7.cpp`):
1. Silent mode skips and goes on: `ReportReadDirTreeTooLong` and the low-memory exit of
   `_ReadDirectoryTree` return TRUE when `parent == NULL` (as the "cannot read folder"
   branch always did), with SALENUM_ERROR. In scan mode the first folder that was not
   checked is recorded in `linkName` (`NoteUncheckedFolder`; also done by both "cannot
   read folder" branches).
2. `Pack` passes an error variable to the scan; a scan that did not look everywhere
   (SALENUM_ERROR with no link found: a folder too deep or too long, unreadable, low
   memory, the early "unexpected situation" / buffer exits) is treated as a link: the
   existing message IDS_DELFILESAFTERPACKINGNOLINKS names the first unchecked folder (or
   the panel folder), "delete files" is switched off and the Pack dialog opens again -
   exactly the link-found path. A scan failure can no longer mean "no links".
   **Behaviour change**: a Move-pack whose selection holds a folder the scan cannot read
   (e.g. access denied) now has its delete switched off with that (link) message, which
   names the unreadable folder; before, the move went ahead (the pack skipped that folder
   too). No new strings, so the message text speaks of a link.

Every silent caller / every "scan said safe" consumer:
- `ReadDirectoryTree(NULL, ..., &containsDirLinks, ...)` in `CFilesWindow::Pack` - the
  only silent scan and the only consumer of `containsDirLinks`: fixed as above.
- `PanelEnumDiskSelection` -> `ReadDirectoryTree(parent, ...)` (the packing walk itself):
  `parent` is the plug-in's; a plug-in passing NULL on the *first* pass now gets a skipped
  too-deep folder with SALENUM_ERROR (the SalEnumSelection2 meaning: an error, skipped)
  instead of an early end; the 7zip plug-in's NULL second pass reuses the tree built on
  the first (it is not walked again).
- No other route checks links: F6 (move) into an archive panel (`fileswn8.cpp`), a
  drag&drop move into an archive (`fileswna.cpp`) and `CallPluginOperationFromDisk` never
  had a link scan - nothing that could say "safe". **New finding (pre-existing, both
  builds, not fixed here)**: probe row `d5f6zip` (INFO): F6 of S\B (B holding the
  junction J -> X) into an existing ZIP: no warning, `B\J\x.txt` is packed and
  `X\x.txt` is **deleted** - on this build and on the build before 098 alike. The
  link check of Alt+F5 is missing on the F6 / drag-move routes; queue it.
- Delete (F8) builds its own script (`BuildScriptDir`, which does not follow junctions);
  it does not use this scan.

Probe rows added to `fix_probe.ps1` (D5; junction by `mklink /J`, deep tree through
`\\?\`, the junction removed with `rmdir` before its target's parent; X must survive):

| Case (ZIP and 7z each) | This build | Before 098 |
|---|---|---|
| sep: A (1,005 x `d`) + B\J -> X | link warning, delete off, `X\x.txt` survives, A and B kept; 2 "too long" messages from the pack walk (level 1,001) and the enumerator (relative name) | warning, survives (the old walk cut silently at 259 bytes) |
| same: A holds the deep chain and A\J | warning, survives | warning, survives |
| ctl: only B\J | warning, survives | warning, survives |
| f6 (INFO): F6 of B into an archive | no warning, **X\x.txt deleted** | the same |

The S1-S4 build itself (with the defect) was not kept, so these rows were not run on it;
the reviewer's driven result stands for it.

### S1 (should-fix) - the stack claim corrected

The Debug frame of `_ReadDirectoryTree` is `push rbp; push rdi; sub rsp,5B8h` (measured with
`dumpbin /disasm` on `Debug_x64\Intermediate\fileswn7.obj`): about 1.5 KB, so 1,000 levels
need about 1.5 MB - safe because every caller is on the main thread (3 MB). Release
(`dumpbin /disasm` of `Release_x64\tandemcommander.exe` with its PDB): 7 pushes +
`sub rsp,0E0h` + the return address = about 290 bytes, about 290 KB for 1,000 levels. The
comment at `READDIRTREE_MAX_DEPTH` and S3 above say so now.

### N5 - fixed

`pack1.cpp` `PackUniversalUncompress`: `srcDir` is `SAL_MAX_PATH_UTF8` bytes in all (the
temporary folder's length is taken from the reserve), the size `MoveFiles` takes.

### Recorded only (no change)

- N1: at depth 1,001 the walk says "Name ... with full path is too long" although the
  path is about 2,000 characters - the reason is the depth (no new strings by rule).
- N2: `ClipboardPastePath` still refuses 520+ bytes although Change Directory takes any
  length - the spec chose refusal.
- N3: `CopyUNCPathToClipboard` refuses silently in the Find window (the old clipboard
  content stays).
- N4: `CShares::GetUNCPath` still cuts `path` to 259 bytes for the share-prefix match
  (older, unlikely).
- **New finding (backlog, from the reviewer, not re-driven here)**: Change Directory to a
  file whose NAME has a CJK character (e.g. `f` + U+4E2D + `.txt` in any folder, at any
  path length) lands in the folder, but the viewer opened with F3 shows the title
  `f??.txt` - on both builds, so older than 098 (the input side or the viewer's title).
- **Old code, not driven**: dragging a directory-line component of a path over about
  7,500 characters makes `CreateDragImage` build a bitmap about 280,000 px wide.

### Gates after the fixes

- Debug x64 build exit 0, no warnings; `saltests` 13,119 / 0; strict guard TOTAL 0.
- Full Release build (`build.cmd full release`) exit 0; 20 plug-ins, 189 language
  modules, runtime closure OK; one warning, C4244 at `zip.cpp(5913)` - a line of the
  initial commit, not touched by 098.
- `fix_probe.ps1` (with D5): this build **107 PASS / 0 FAIL / 3 not driven / 1 INFO**;
  before 098: 50 PASS / 34 FAIL / 3 not driven / 1 INFO (the 34 are the D1, D2 and D4
  failures above; D5 passes there too).
- Regression on this build: 095 longarc 60 / 0 (handle notes 4, as its baseline); 096
  archedit 17 of 17 UPDATED; 097 arcpath 55 / 0; 097 arcwork 390 / 0 / 21 n/a (run
  because `Pack` changed). Registry SHA-256 identical after every run; nothing left.

## Second review - ACCEPT (2026-10-03)

Re-driven by the reviewer: the B1 scenario and its variants (deep tree plus
junction, junction inside the deep tree, the selection itself a junction,
Cancel in the reopened dialog) on ZIP and 7z - the warning appears, delete is
off, `X\x.txt` survives; every outcome of the silent scan reads as "a link
was found" except a real "no links" and Esc; the unreadable-folder change
(Move keeps the sources) accepted as the safe direction - stated in the
CHANGELOG. The author's new finding confirmed on both builds: F6 (move) of a
folder holding a junction - or of the junction itself - into an existing ZIP
or 7z archive packs the file behind the junction and deletes it, no warning;
drag & drop with Move goes through the same call (not drivable). Older than
098; queued as the next feature (NEXT-WORK item 5). `fix_probe.ps1` re-run:
107 / 0 / 3 / 1. saltests 13,119 / 0; strict guard 0; BOM and CRLF kept.

