# Fix log: feature 097 - archives at long paths

Branch `097-archive-long-path`, from `096-archive-edit-accented`.
Decisions by the author (maintainer away): `spec.md` *Clarifications*.

## S1 - refuse, never cut (2026-10-02)

Not committed (the stage goes to the review first). No limit was lifted: an
archive path of 260 bytes or more ends in the refusal for every archive type.

### What changed

| File : function | Change |
|---|---|
| `src/fileswn2.cpp` : `CFilesWindow::ChangePathToArchive` | First statement: `strlen(archive) >= MAX_PATH \|\| strlen(archivePath) >= MAX_PATH` -> `*noChange = TRUE`, message `IDS_TOOLONGPATH` ("The path specified is too long.") titled `IDS_ERRORCHANGINGDIR` (no message when `isRefresh`), `*failReason = CHPPFR_INVALIDPATH`, `return FALSE`. Nothing is copied, cancelled or closed before it, so the panel is exactly where it was. The three `lstrcpyn(..., MAX_PATH)` stay but can no longer cut. |
| same, the focus name | A `suggestedFocusName` of 260+ bytes is dropped (`NULL`: focus nothing), not cut. Reason: names in an archive listing are limited to `MAX_PATH - 5` bytes (`CSalamanderDirectory::AddFile` / `AddDir`), so such a name cannot be in the listing; a cut name could only match another item. The path change itself is not refused for it. |
| `src/plugins/uniso/isoimage.cpp` : `CISOImage::Open` | `sprintf(errStr[MAX_PATH], IDS_CANT_OPEN_FILE, fileName)` -> `_snprintf_s(..., _TRUNCATE, ...)`; when the text was cut, a UTF-8 sequence torn by the cut is dropped (the core shows text that is not valid UTF-8 as code-page text). `GetLastError()` is now read before `LoadStr`, not after it. Same text. |
| `src/salamdr1.cpp` : `GetCommandLineParamExpandEnvVars` | upstream cut 1 below |
| `src/fileswn1.cpp` : `SetUnescapedHotPath`, `SetUnescapedHotPathToEmptyPos` | upstream cut 3 below |

`SalGetFullName` in `ChangePathToArchive` (in place, `nameBufSize` = `MAX_PATH`):
the name only grows for the relative forms (`c:path`, `\path`, `path`), and each
of them checks `l1 + l2 >= nameBufSize` first and reports `IDS_TOOLONGPATH`; an
absolute name is only shortened (leading spaces, `.` / `..`). With the input now
under 260 bytes in a 260-byte buffer it can neither overflow nor cut. A relative
name that would grow past 259 bytes gets the same message through the existing
error branch.

Nothing else in the function shortens the archive name: after the check
`archive` is `backup1` whole; `path[MAX_PATH]`, `text[MAX_PATH + 500]`,
`buf[MAX_PATH]`, `buf[MAX_PATH + 200]`, `currentPath[MAX_PATH]` are filled from
values under 260 bytes (`SetZIPArchive` / `SetZIPPath` are called only here and,
with `""`, where the path is closed). So the "every check succeeds on the cut
name" case cannot occur: no cut name exists.

### Callers and the refusal

| # | Caller | Can the refusal be reached in S1? | What it does with FALSE |
|---|---|---|---|
| 1 | `fileswn2.cpp` `Execute`: Enter on an archive file | yes (probe ENTER) | reads `noChange` (TRUE: `TopIndexMem` kept), `UpdateWindow`, `EndStopRefresh`, return. No retry. |
| 1b | same, Enter on a shortcut (`.lnk`) to an archive | no: `IShellLink::GetPath(fullName, MAX_PATH)` gives at most 259 bytes (the shell's limit, not a cut of ours; not driven) | as 1 |
| 2 | `Execute`: `..` inside an archive | no (ZIPArchive and the shortened ZIPPath are under 260) | `TopIndexMem.Clear()` |
| 3 | `Execute`: Enter on a folder inside an archive (ZIPPath + name, not limited upstream) | yes (probe INNER d3) | reads `noChange` (TRUE), nothing else: the panel stays in the parent folder |
| 4 | `fileswn0.cpp` refresh (`isRefresh` TRUE) | no (panel members) | no message would be shown; FALSE with `noChange` TRUE |
| 5 | `fileswn1.cpp` `GotoRoot` | no | result ignored |
| 6 | `fileswn8.cpp` `ChangePathToOtherPanelPath` | no (the other panel's members) | result ignored |
| 7 | `fileswn3.cpp` `ChangeDir`: Change Directory dialog, `cd`, hot paths, tabs, `-L/-R/-A`, plug-in `ChangePanelPath`, directory-line click, paste path | yes (probe CHDIR, START) | returns FALSE with `CHPPFR_INVALIDPATH`; the dialog is not opened again (as for any other archive failure); only `CHPPFR_SHORTERPATH` adds its own message, so one message in total. `ChangeDir` already refused an inner part of 260+ bytes itself ("Path: ... Error: The path specified is too long.", dialog opened again) - unchanged. |
| 7a | tabs: `paneltabs.cpp` `SwitchToTab` | only for a stored location that is too long (this build cannot produce one) | not `CANNOTCLOSEPATH`: the tab becomes active and takes the panel's real location, as for any location that is gone |
| 7b | start-up `-L/-R/-A`: `mainwnd2.cpp` `ChangeDirLite`, `mainwnd3.cpp` (request from another instance) | yes (probe START) | the panel keeps its stored path. One message. |
| 8 | `salamdr3.cpp` `CPathHistoryItem::Execute` (`isHistory` TRUE) | no in S1: history is recorded from the panel, which cannot be at such a path | `CHPPFR_INVALIDPATH`: no second message, `TopIndexMem.Clear()`. The refusal returns before `tryPathWithArchiveOnError` is used: the panel is NOT moved to the nearest disk path ("the panel stays where it was"). |
| 9 | `zip.cpp` `CSalamanderGeneral::ChangePanelPathToArchive` (plug-in service) | yes for a plug-in that passes such a path (not driven) | the plug-in gets FALSE and `CHPPFR_INVALIDPATH`; the message is shown, as it already was for a `SalGetFullName` error |

No caller tries a shortened path, loops, or leaves the panel half changed.

### Upstream cuts

| # | Site | Silent? Another archive possible? | S1 |
|---|---|---|---|
| 1 | `salamdr1.cpp` `GetCommandLineParamExpandEnvVars`: `-L/-R/-A/-AJ` into `CCommandLineParams::*Path[2 * MAX_PATH]`; when the expanded value did not fit, the fallback `lstrcpyn(target, argv, targetSize)` cut it at 519 bytes | silent; yes - the cut path goes to `ChangeDir`, which opens whatever exists there (old build, probe row CL600: "Path: [the first 519 bytes] Error: The path specified was not found.") | **fixed**: a value that does not fit is not applied (empty = "do not set") and `IDS_TOOLONGPATH` is shown, titled with the product name, before the main window exists. The shared structure is not widened. A value whose expansion fails for another reason is still used unexpanded when it fits (as before). |
| 2 | forwarding to a running instance: research 1.4 named `mainwnd3.cpp:2077-2084` and `salamdr2.cpp:2207-2216` (`lstrcpyn(..., MAX_PATH)`) | **stale**: both are inside comment blocks (`WM_USER_SETPATHS`, dead code). The live hand-over copies the whole `CCommandLineParams`, i.e. the 519-byte fields of row 1 | nothing to do |
| 3 | `fileswn1.cpp` `SetUnescapedHotPath`, `SetUnescapedHotPathToEmptyPos`: `GetGeneralPath(path, 2 * MAX_PATH)`, result ignored | silent; the stored hot path was the first 519 bytes, a later jump goes to whatever is there. Not reachable from an archive location in S1 (259 + 1 + 259 = 519 fits exactly); reachable from a disk path over 519 bytes | **fixed**: a clipped path is not stored; `IDS_TOOLONGPATH` titled `IDS_ERRORTITLE`. Not driven by the probe. |
| 4 | `GetExpandedHotPath(..., 2 * MAX_PATH)` (`fileswn1.cpp`, `drivelst.cpp`, `salamdr3.cpp`) | not silent: `ExpandVarString` refuses with its own message when the expansion does not fit | nothing to do |
| 5 | `fileswn9.cpp` `ClipboardPastePath`: `buff[2 * MAX_PATH]`; a `ConvertU2A` failure with `ERROR_INSUFFICIENT_BUFFER` is deliberately ignored, and the `CF_TEXT` branch uses `lstrcpyn` | silent; yes in principle (a pasted path over 519 bytes is cut and handed to `ChangeDir`) | **not changed** (clipboard text conversion, wider than this stage): S2 / backlog |
| 6 | `fileswn0.cpp` reparse-point target: `junctionOrSymlinkTgt[MAX_PATH]` | not a cut: the use is guarded by `strlen(fullName) < MAX_PATH` | nothing to do |
| 7 | `fileswn3.cpp` `ChangeDir`: `strcpy(shortenedPath[MAX_PATH], copy)` for a typed path to a non-archive FILE of 260+ bytes | an overflow, not a cut (research 2.2, "unrelated overflow") | **not changed**: backlog |
| 8 | `GetGeneralPath` callers that display or copy (window title, history menu text, clipboard "copy path", comparison of two locations in `mainwnd3.cpp`) at 519 bytes | silent, display only; not reachable from an archive location in S1 | S2 (there the archive location can pass 519 bytes) |
| 9 | panel tabs, path history, Change Directory field, `WM_USER_CHANGEDIR` | heap or `SAL_MAX_PATH_UTF8`: no cut | nothing to do |

`uniso` twins of the unbounded text: none is fed with the image file name.
Listed, not changed: `Error(int resID, BOOL quiet, ...)`, `Warning`, `SysError`
(`uniso.cpp`): `vsprintf` into `buf[1024]`, fed with names INSIDE the image
(`IDS_UDF_ICB_AND_FILESIZE_MISMATCH`, `IDS_ERR_HFS_SEEK_BLOCK_EXTR`,
`IDS_ERR_HFS_FILE_FRAGMENTED`); `Error(char* msg, DWORD err, BOOL quiet)`:
`sprintf` into `buf[1024]` of the message (now at most 259 bytes) plus the
system error text.

### Probe

`probe/arcpath_probe.ps1` (hidden desktop; registry restored and identical in
every run; fixtures removed). Results: `probe/arcpath_result_s1.txt`,
`probe/arcpath_result_pre097.txt` (each: the full run, then a second run
`-Only ISO,ISOU` appended). Routes: ENTER (End, Enter in the archive's folder),
CHDIR (Change Directory, command 862, wide `WM_SETTEXT`, OK), START
(`-l "<archive>"`). Which archive the panel is in: End, F3 - the viewer's title
names a.txt (requested archive) or twin.txt.

| Case | Archive full name | S1 build | Build before the feature |
|---|---|---|---|
| C200 | 200 bytes ASCII | opens, a.txt, no message (3 routes) | same |
| A259 | 259 bytes ASCII | opens, a.txt, no message (3 routes) | same |
| A260 | 260 bytes ASCII | one "The path specified is too long." (title "Error Changing Directory"), panel stays (3 routes) | **nothing shown**, nothing happens (3 routes) |
| U130 | 281 bytes / 169 characters | one message, panel stays (3 routes) | nothing shown (3 routes) |
| U200 | 417 bytes / 237 characters | one message, panel stays (3 routes) | nothing shown (3 routes) |
| MID | 280 bytes, byte 259 inside a character | one message, panel stays (3 routes) | nothing shown (3 routes) |
| **TWIN** | 300 bytes; another archive exists at its first 259 bytes | one message, panel stays (3 routes); twin.txt never shown | **the twin archive is opened** on all three routes (the title names `...ppp.zip`, F3 shows twin.txt), no message |
| CL600 | 619 bytes, `-l` only | one message before the main window (title "Tandem Commander 0.1.8 (x64)"); the panel keeps its stored path | "Path: [the first 519 bytes] Error: The path specified was not found." |
| INNER | 57 bytes; d1\d2 = 241 bytes, d1\d2\d3 = 362 bytes | archive, d1, d2 entered; Enter on d3: one message, panel stays in d2. Change Directory to `arc.zip\d1\d2\d3`: `ChangeDir`'s own "Path: ... too long" (unchanged) | Enter on d3: **nothing shown**, panel stays in d2. Change Directory: as S1 |
| ISO | `.iso` at 250 bytes that cannot be opened | plug-in message "Cannot open file '...", cut at 259 bytes, plus the system error; program alive, exit 0 | the message, then **"Run-Time Check Failure #2 - Stack around the variable 'errStr' was corrupted"** in `uniso.spl` |
| ISOU | 252 bytes accented | same; the cut text is readable | same failure |

Totals: S1 build 51 PASS / 0 FAIL (+ 4 / 0 for ISO, ISOU); build before the
feature 34 PASS / 17 FAIL with 3 rows showing the twin archive (+ 0 / 4 for
ISO, ISOU). Every END row on the S1 build: alive, WM_NULL answered, no stray
window, no new crash report, exit code 0.

Found on the way: on the old build the "error naming a cut path" outcome did not
appear in these layouts - the folder of the cut name always exists (the cut
falls inside the last folder name or the file name), so the cut name is simply
"not an archive" (a trace only): silence.

Regression probes on the S1 build: 095 `longarc_probe.ps1` 60 PASS / 0 FAIL;
096 `archedit_probe.ps1` 17 of 17 UPDATED.

Order of events, for the record: the full S1 run and the 095 / 096 runs were
made before the last narrowing in `fileswn1.cpp` (the hot-path refusal applies
only to a really clipped path: one condition, two sites); after it the build was
repeated and the probe re-run for A259, TWIN, CL600 (14 PASS / 0 FAIL), together
with saltests and the guard.

Gates: Debug x64 build exit 0, no error; `saltests` 13,102 checks, 0 failed;
`python tools\check_encoding.py --strict` TOTAL: 0.

### Not driven

- History (Alt+F12, back / forward) and tabs with a too-long archive location:
  cannot be produced on this build (the panel never gets there); read only.
- The plug-in service `ChangePanelPathToArchive`, Enter on a shortcut to an
  archive, refresh: read only.
- The hot-path assignment refusal (needs a disk path over 519 bytes and
  Ctrl+Shift+digit): compiled, not run.
- `-R`, `-A`, `-AJ` and the hand-over to a running instance: same function as
  `-L`; only `-L` at a fresh start was run.
- External archivers and the 7zip / tar / uncab plug-ins: the refusal comes
  before any handler is chosen; only ZIP archives (and the ISO failure) were
  used.
- Release build: not built in this stage (S3 gate).

## S2 - archives at long paths open and work (2026-10-02)

Not committed. Interface version unchanged (107), no new string, no
configuration change.

### The rule

`SalArchiveNameFitsHandler(builtForVersion, nameLen)` in
`src/common/salplugver.h` (pure, 17 saltests checks): a name under 260 bytes
always; a longer one only for a plug-in built for interface 107 or later and
only up to `SAL_MAX_PATH_UTF8 - 1` bytes; an external archiver
(`SAL_ARCHIVE_HANDLER_EXTERNAL`), an older plug-in and an unknown version keep
259 bytes.

Where it is applied:

| Place | What it does |
|---|---|
| `fileswn2.cpp` `ChangePathToArchive` | after `SalGetFullName` (the name is absolute, held whole on the heap, nothing closed yet): `PackGetUnpackerVersion` (extension -> unpacker; a plug-in is loaded to learn its version) + the rule; refusal = S1's message, silent on refresh. A name that is not an archive goes on to the old "not an archive" handling. The archive already open in the panel is not re-checked. |
| `fileswn3.cpp` `ChangeDir` | the same rule before `ChangePathToArchive` is called, reported the way `ChangeDir` already reported a too-long inner path ("Path: ... Error: The path specified is too long.", the Change Directory dialog opens again with the text) - review NIT 7 |
| `plugins1.cpp` `CPluginData::ListArchive / UnpackArchive / UnpackOneFile / PackToArchive / DeleteFromArchive / UnpackWholeArchive` | backstop for every other entry (Alt+F5, Alt+F9, paste, update of edited files): an old plug-in never gets a long name; message "The path specified is too long." titled "Packer Error" |
| `pack1.cpp` `PackList` (external branch), `PackUniversalUncompress`, `PackUnpackOneFile` (external branch); `pack2.cpp` `PackUniversalCompress`, `PackDelFromArc` (external branch) | an external archiver never gets a name of 260+ bytes: all ten unbounded copies of research 2.2 "external-archiver route" stay unreachable, from the panel and from the Pack / Unpack dialogs and custom packers |

The path INSIDE the archive keeps its limit of 259 bytes (S1's refusal): the
listing structure (`CSalamanderDirectory`, `AddFile` / `AddDir` limits) is
shared with plug-ins and is not changed in this feature.

### Inventory (redone at HEAD: every use of `GetZIPArchive()`, `ZIPArchive`, the pack functions' `archiveFileName`, `GetGeneralPath` callers)

FIXED = holds the name whole now; REFUSES = clean refusal with the existing
message; SAFE = was already whole (pointer or heap).

| # | Site | Before | After |
|---|---|---|---|
| 1 | `fileswn2.cpp` `ChangePathToArchive`: `backup1[MAX_PATH]` | cut (S1: refused at 260) | FIXED: heap copy with the room `SalGetFullName` needs (`SAL_MAX_PATH_UTF8`) |
| 2 | same: `path[MAX_PATH]` as the archive's folder (`strcpy`, `CutDirectory`, `SetPath`, fallback path) | overflow once the limit is lifted | FIXED: heap `arcDir`; `path` now serves the inner path only |
| 3 | same: `text[MAX_PATH + 500]`, two `sprintf(IDS_FILEERRORFORMAT)` | overflow | FIXED: `CSalHeapString::Printf` |
| 4 | same: `buf[MAX_PATH + 200]` `sprintf(IDS_ARCHIVEREFRESHEDIT)` | overflow | FIXED: heap |
| 5 | `fileswnd.h` `CFileTimeStamps::ZIPFile[MAX_PATH]`, `salamdr3.cpp` `AddFile` `strcpy` | overflow into the following members | FIXED: `CSalPathBuf` |
| 6 | `dialogs5.cpp` Archive Update, *Copy Selected To*: `path[MAX_PATH]` `strcpy` | overflow | FIXED: heap; a start folder of 260+ bytes is not handed to the folder-browse dialog |
| 7 | `fileswn7.cpp` F8 in an archive, non-empty folder question: `name[SAL_MAX_PATH_UTF8]` on the stack + `text[2 * MAX_PATH + 100]` `sprintf` | overflow (close to it already before) | FIXED: heap |
| 8 | `zip.cpp` `CSalamanderGeneral::GetPanelPath`: `buf[2 * MAX_PATH]`, `memcpy` / `strcat` of the archive location and **`strcpy` of the disk path** | overflow from 520 bytes - for a DISK path reachable before this feature | FIXED: heap; the plug-in's buffer is still guarded by `bufferSize` (too small -> FALSE, as documented) |
| 9 | `shellsup.cpp` drag from an archive: `lstrcpyn(realDraggedPath + 1, ..., 2 * MAX_PATH)` (two sites) | one byte past the buffer from 519 bytes; otherwise cut | FIXED: whole or empty (a cut path would be offered as a path to go to) |
| 10 | `bugreprt.cpp` "Archive = %s", "ArcPath = %s" into `buf[1024]` | overflow from 1,014 bytes | FIXED: `_snprintf_s(_TRUNCATE)` |
| 11 | `fileswn9.cpp` copy full name / current path to the clipboard: `buff[2 * MAX_PATH]` | cut at 519 bytes | FIXED: heap, whole. UNC name: not converted when location + name do not fit the 520-byte buffers of `CopyUNCPathToClipboard` (they were filled without a bound) |
| 12 | `fileswn8.cpp` `OpenFocusedInOtherPanel`: `buff[2 * MAX_PATH]` | cut; the cut path was opened in the other panel | FIXED: heap |
| 13 | `mainwnd3.cpp` Compare Directories "same path?" | two locations equal in 519 bytes were "the same" | FIXED: cut locations are never equal |
| 14 | `salamdr3.cpp` `CPathHistoryItem::IsTheSamePath` (disk type) | compared through two 520-byte copies | FIXED: the stored strings |
| 15 | `salamdr3.cpp` path-field menu "left / right panel directory" | cut path put into the field | REFUSES: not inserted when it does not fit the work buffer or the dialog's field; message (second review) |
| 16 | `mainwnd1.cpp` window title: three `GetGeneralPath(path, 2 * MAX_PATH)` | built from the first 519 bytes: an archive and its folder had the same title; a cut inside a character showed the title as code-page text | FIXED: built from the whole location, cut to the caller's buffer at a whole character |
| 17 | `dialogs3.cpp` Change Directory field: read with `2 * MAX_PATH` BYTES although it takes 519 CHARACTERS | an accented path over 519 bytes was cut and the cut path opened ("not found", or another folder) | FIXED: read into the caller's `SAL_MAX_PATH_UTF8` buffer |
| 18 | `salamdr3.cpp` `SalGetTempFileName` (and the plug-in service) | a base path of 260+ bytes failed: ZIP (with backup) and 7z could not add to / delete from / update an archive in such a folder | FIXED: new last parameter `tmpNameSize`; the plug-in service allows a long base path for plug-ins built for 107 (their `tmpName` is then `SAL_MAX_PATH_UTF8` bytes: stated in `spl_gen.h`); every other caller as before |
| 19 | `fileswn7.cpp` Alt+F9: the archive's name built in `subject[MAX_PATH + 100]` (`memcpy` + `sprintf`) | **overflow reachable before this feature** (archive in a folder of about 360 bytes) | FIXED: heap |
| 20 | `fileswn7.cpp` Alt+F5: default archive name `memcpy(fileBuf[MAX_PATH], <folder name>)` | **overflow reachable before this feature** (folder name of 260+ bytes, e.g. 130 accented characters) | FIXED: used only when it fits, else the "new archive" default |
| 21 | `fileswn8.cpp` F5 into an archive: `SalPathAddBackslash(path, 2 * MAX_PATH + 200)` | wrong bound | FIXED: real size |
| 22 | `salshlib.h` `CSalShExtPastedData::ArchiveFileName[MAX_PATH]` (copy to clipboard from an archive) | cut: Paste could list and unpack another archive | REFUSES: `shellsup.cpp` shows "The path specified is too long." before anything is created; `SetData` returns FALSE as the backstop. Not widened. |
| 23 | `fileswnd.h` `CTmpDragDropOperData::ArchiveOrFSName[MAX_PATH]` (drop / paste INTO an archive) | cut: a file with the cut name was packed into, or deleted when empty | REFUSES: `DoDragDropOper` marks the request, `DragDropToArcOrFS` shows the message and does nothing. Not widened. |
| 24 | external-archiver route, 10 sites (`pack3.cpp` 880, 915, 952, 999; `pack2.cpp` 467, 513; `pack1.cpp` 565, 864; `pack2.cpp` 401, 763) | overflow | REFUSES: unreachable behind the five guards above |
| 25 | hot-path assignment, `-L/-R/-A` (519 bytes) | S1 | REFUSES (S1) |
| - | `fileswn1.cpp` directory line, `stswnd.cpp`, `fileswn2.cpp` / `fileswn9.cpp` "archive is about to close" texts, disk-cache names (095), `fileswn5/6.cpp`, path history items and their registry form, panel tabs, `PackIsArchive`, plug-in route pointers, `fileswn7.cpp` unpack / delete calls, `fileswn8.cpp` F5 target, `SetZIPArchive`, refresh, `DialogError` | - | SAFE (15 groups) |
| - | history menu texts, Compare Directories progress texts, debug trace in `RefreshDirectory` | cut at 519 bytes | display only, left |

Totals: 20 rows FIXED (the 12 of research 2.2's plug-in route + 8 found by the
new inventory or by the probe: rows 12-14, 16-20), 5 rows REFUSE (the two
internal 260-byte fields, the 10 external-archiver sites, one path-field menu,
S1's two), 15 groups SAFE, 3 display-only cuts left.

Note on rows 22-23: both structures are private to the process (the shell
extension's shared memory carries no archive name), so they could be widened
later; this stage refuses, as specified.

### Plug-ins (independent read-only audit + probe)

| Plug-in | Archive name of 300 / 800 / 2000 bytes | Changed |
|---|---|---|
| zip | SAFE (heap `U8_MAX_PATH` = `SAL_MAX_PATH_UTF8`, `CreateFileU8` with `\\?\`); add / delete with *backup* failed in `SalGetTempFileName` | fixed in the core (row 18) |
| 7zip | SAFE; every add / delete / update failed in `SalGetTempFileName`; messages `_TRUNCATE` at 1,023 bytes; options dialog shows the name cut (display) | fixed in the core (row 18) |
| tar | SAFE (exact allocations) | - |
| uncab | refuses itself from `CB_MAX_CAB_PATH` with "Can't finish operation because of too long path name." | left (FDI limit) |
| uniso | SAFE; the cannot-open text is bounded (S1) | tail rule made exact (review NIT 5) |

No plug-in copies the archive name into a fixed buffer without a bound, so no
plug-in is on an exception list. No other enabled plug-in implements the
archiver interface. Left, listed: zip SFX creation at a path of 260+ ANSI bytes
ends with the misleading `IDS_ERRADDICON` (`chicon.cpp:89`); `MakeFileName` /
`RenumberName` (zip multi-volume) can write about 6 bytes more than their input
(matters only within 6 bytes of `SAL_MAX_PATH_UTF8`).

`spl_arc.h`: comment on the length and encoding of the archive name per
interface version. `spl_gen.h`: the `SalGetTempFileName` buffer for a long base
path (comment; behaviour for plug-ins built for older versions unchanged).

### Review findings of S1 (commit 5f2169d1) folded in

| Finding | Done |
|---|---|
| SHOULD-FIX 1: history moved although the panel did not | `CPathHistoryItem::Execute`: the "too long" refusal (explicit flag `refusedTooLong` of `ChangePathToArchive`, see the second review below) is treated like `CANNOTCLOSEPATH` (stay, nothing cleared, entry kept) |
| SHOULD-FIX 2: tab switch not reverted on the refusal | `ChangeDir` got an internal out-parameter `refusedTooLong` (plug-in-facing signatures unchanged); `SwitchToTab` reverts on it as on `CANNOTCLOSEPATH` |
| SHOULD-FIX 3: relative `-L` value that fits only while relative | refused with the same message (`SalGetFullName` result checked); probe row RELL |
| NIT 4: hot-path flash after a refused assignment | `SetUnescapedHotPath` returns BOOL; both callers flash only on success |
| NIT 5: uniso tail dropped a complete character | the rule of `SalU8TrimIncompleteTail`, ported |
| NIT 6: a refused `-L` lets `-A` apply | kept and documented: with `-L` not applied, `-A` (previously ignored when `-L` or `-R` was given) is applied - the user asked for that location too |
| NIT 7: dialog not reopened after the refusal | reopened, same message form as the inner-path refusal (see the rule table) |

### Still limited (FR-008)

- external archivers and plug-ins built for an interface older than 107: 259 bytes (refusal);
- CAB: the plug-in's own limit;
- the path inside an archive: 259 bytes (refusal on entering);
- `-L/-R/-A`: 519 bytes (refusal); the structure is shared between instances of different versions;
- hot paths: a location over 519 bytes is not stored (refusal);
- Change Directory field: 519 characters;
- copy to clipboard from, and drop / paste into, an archive whose name is 260+ bytes: refusal;
- Alt+F5 (Pack) and Alt+F9 (Unpack) dialogs: the typed archive / target folder is limited to 259 bytes (dialog buffers); F5 into an existing long-path archive works;
- a temporary file beside an archive whose folder is 246-259 bytes long (ZIP with backup, 7z update) still fails as before this feature: the service's result must fit `MAX_PATH` there because the caller's buffer size is not known;
- found, not changed: `pack2.cpp` `strcpy(sourceShortName[MAX_PATH], sourceDir)` (external packer, source folder of 260+ bytes); `CPanelTmpEnumData::WorkPath` copies cut at 259 bytes; `fileswn3.cpp` `shortenedPath[MAX_PATH]` and `fileswn9.cpp` `ClipboardPastePath` (S1 list); `CopyUNCPathToClipboard`'s own unbounded copies (now guarded by its caller).

### Probes

`probe/arcwork_probe.ps1` (new; hidden desktop; registry restored and identical;
fixtures removed). Results: `probe/arcwork_result_s2.txt`,
`probe/arcwork_result_pre097.txt`. Archive full names: C200 = 200 bytes; U130 =
285 bytes / 173 characters; U200 = 421 / 241; B259 = 655 bytes / 259 characters
(U+20AC); L300A = 300 / 300; L300U = 537 / 300.

S2 build, each of ZIP / 7z / TAR at each of the six lengths (18 archives):

| Step | ZIP | 7z | TAR |
|---|---|---|---|
| ENTER (title names the archive) | 6/6 | 6/6 | 6/6 |
| VIEW a.txt (F3) | 6/6 | 6/6 | 6/6 |
| UNPACK a.txt (F5 to a short folder, content equal) | 6/6 | 6/6 | 6/6 |
| EDIT (F4) + UPDATE on leaving (archive read back) | 6/6 | 6/6 | n/a (leave: 6/6) |
| REENTER | 6/6 | 6/6 | 6/6 |
| DELETE del.txt (F8, read back) | 6/6 | 6/6 | n/a |
| ADD add.txt (F5 with the archive as the target, read back) | 6/6 | 6/6 | n/a |
| TWO panels on the archive, one leaves | 6/6 | 6/6 | 6/6 |
| HIST: Back returns into the archive | 6/6 | 6/6 | 6/6 |
| TAB: new tab, leave, previous tab returns into the archive | 6/6 | 6/6 | 6/6 |
| END: alive, WM_NULL, no stray window, no crash report, exit 0 | 6/6 | 6/6 | 6/6 |

Rows of this table (first run): 220 PASS, 0 FAIL, 18 n/a; final run with the
rows added after the second review: see below. Extra rows: RELL (relative `-l` value of 309
bytes from a folder of 249 bytes) - one "too long" message before the main
window; CLIP (Copy to clipboard inside the 285-byte ZIP archive) - nothing shown
and nothing put on the clipboard path: the shell-extension shared memory is not
available in this product build, so the copy code - and with it the new refusal
- is never reached (read only).

Build before the feature: C200 of all three types passes every step (identical
to S2); U130, U200, L300A: Enter does nothing, nothing shown (9 FAIL rows, the
rest not driven); B259, L300U: not driven - their folders (over 519 bytes)
could not even be reached through Change Directory ("Path: [cut path] Error:
The path specified was not found.": inventory row 17); RELL: no refusal, the
relative value is resolved against the panel path later ("Path: C:\qqq...
not found"). Rows: 53 PASS, 10 FAIL, 172 not driven.

`probe/arcpath_probe.ps1 -Stage S2` on the S2 build
(`probe/arcpath_result_s2.txt`): 55 PASS / 0 FAIL. A260, U130, U200, MID and
**TWIN** now open the REQUESTED archive on all three routes (F3 shows a.txt;
rows showing the twin archive: 0); CL600 and the inner path of INNER are still
refused with one message; ISO / ISOU as in S1. (`-Stage S1` keeps the S1
expectation for the S1 build.)

Regression probes on the S2 build: 095 `longarc_probe.ps1` 60 PASS / 0 FAIL;
096 `archedit_probe.ps1` 17 of 17 UPDATED.

What the probe found (fixed, then the run repeated): the title built from a cut
location (row 16) and the Change Directory field read in bytes (row 17) - both
only from 520 bytes up. Probe-side: a folder over 519 bytes cannot be given with
`-l` (the S1 refusal), so those cases go there through Change Directory; a
posted F4 right after the copy operation was sometimes ignored (seen on both
builds, short-path controls included) - the probe now waits for idle and
re-posts once (no re-post was needed in the final runs).

Gates: Debug x64 build exit 0; `saltests` 13,119 checks, 0 failed (13,102 + 17);
`python tools\check_encoding.py --strict` TOTAL: 0.

### Not driven

- An archive handled by an EXTERNAL archiver at 260+ bytes (ARJ / LZH fixtures
  cannot be created with 7-Zip; RAR packing needs WinRAR): the refusal is
  covered by the saltests of the rule and by reading the five guards.
- A plug-in built for an interface older than 107 (none is shipped): rule
  tested in saltests, wrappers read.
- Copy to clipboard from / drop or paste into a long-path archive: the first is
  unreachable in this build (see CLIP), the second needs a real clipboard or
  drag on the input desktop; both read only.
- The Archive Update dialog's *Copy Selected To*, the F8 non-empty-folder
  question, the crash report, the plug-in service `GetPanelPath` with a long
  location, copy name / path to clipboard, Compare Directories, hot-path
  refusal, Alt+F5 / Alt+F9 at long paths, zip with *backup* enabled (its
  setting was left as stored): compiled, read, not run.
- History and tab rows were driven only for successful returns; the reverted
  tab switch and the unmoved history on a REFUSED location cannot be produced
  with the shipped plug-ins (no refused location can be stored) - read only.
- CAB at a long path (the plug-in's own refusal), ISO images that open, 7z /
  TAR on the Change Directory and start-up routes (`arcpath_probe` uses ZIP).
- Release build: S3 gate.

### Second review of S2 (REJECT: 1 blocker, 4 should-fix, 6 nits) - what was done

| # | Finding | Done |
|---|---|---|
| B1 | History Back stuck on a dead archive entry (short paths too): the condition `CHPPFR_INVALIDPATH && noChange` also matched an archive whose drive or folder is gone | `ChangePathToArchive` has its own out-flag `refusedTooLong` (TRUE only at its two "too long" refusals). `CPathHistoryItem::Execute` tests that flag (the generic `noChange` is no longer passed); `ChangeDir` hands it on in its own `refusedTooLong`, which is what the tab revert tests. No other place keyed on `noChange` / `CHPPFR_INVALIDPATH` for the refusal (checked: `Execute` callers in `fileswn2.cpp` read `noChange` only for `TopIndexMem`, as before the feature). Probe row HDEAD (subst drive) on both builds. |
| SF2 | Directory-line drop used a path cut at 259 bytes (`stswnd.cpp` `GetDirFromDataObject`, `lstrcpyn(..., MAX_PATH)`), and dropped text cut at 519 bytes | `GetDirFromDataObject(obj, path, pathSize, tooLong)`: the dragged path is taken whole into a buffer of the size of `Buffer` (2 * MAX_PATH; the drag source provides at most 518 bytes) or refused; the `CF_HDROP` branch converts with the real size and its ANSI `strcpy` is bounded; dropped text of 520+ bytes is refused. Refusal = `WM_USER_CHANGEDIR` with a NULL path: the panel shows "The path specified is too long." and does not navigate. Also `editwnd.cpp` `GetNameFromDataObject` (drop on the command line): a dragged name that does not fit its MAX_PATH buffer is not accepted (it was inserted cut). |
| SF3 | A hot path set from the directory-line menu was stored cut (`mainwnd1.cpp` `HotText[2 * MAX_PATH]`) | `CMainWindow::SetUnescapedHotPath` - the one function every route stores through - returns BOOL and refuses a path of 520+ bytes with the message (a hot path is expanded into 520-byte buffers when used). `HotText` is a heap buffer of `SAL_MAX_PATH_UTF8` (the clipboard copy of the hot text is whole too); the menu flashes only on success; `CFilesWindow::SetUnescapedHotPath*` return its result. |
| SF4 | Path-field menu "left / right panel directory" (and hot paths) inserted a path cut to the dialog's field | `InvokeDirectoryMenuCommand`: a path of `editBufSize` bytes or more is not inserted; the message is shown (also for a panel location that does not fit the 520-byte work buffer). |
| SF5 | `demoplug\archiver.cpp` passed `tmpExtractDir[MAX_PATH]` to `SalGetTempFileName` with the user's target folder | `CSalMaxPathBuffer` (compiled once by hand: the plug-in is off in `plugins.cfg`). All calls of the service in all plug-ins under `src\plugins`, enabled or not (grep for the name, 7za excluded): 7zip x2 and zip x1 (heap `U8_MAX_PATH`), pictview (base path in a `_MAX_PATH` buffer: short), undelete (base path from a MAX_PATH buffer), demoplug (fixed); every other call passes NULL as the base path. `zip\extract.cpp:1991` calls the plug-in's own function. `spl_gen.h`: the older "min. size MAX_PATH" line now names the exception. The other touched service contract, `GetPanelPath`, is unchanged (the caller's `bufferSize` is honoured). |
| N6 | `SalGetTempFileName` heap branch bounded by `tmpNameSize`, not by the block | bound = min(`tmpNameSize`, block size) |
| N7 | `CPluginData::CanCloseArchive` without the backstop | added: an older plug-in is not called with a long name (returns TRUE, no message) |
| N8 | `ChangeDir` `lstrcpyn(path, newDir, SAL_MAX_PATH_UTF8)` cut a location near the limit; the same edge with a panel filter in `fileswn1.cpp` | `ChangeDir` refuses a `newDir` of `SAL_MAX_PATH_UTF8` bytes or more (message, `refusedTooLong`); the directory-line text with a filter is built in a heap buffer sized for location + filter |
| N9 | relative `-L` with a current folder over 259 bytes stayed relative | the current folder is read whole (heap); if it cannot be read, a relative value is refused |
| N10 | title: about 196 KB allocated per update | sized for the location (path lengths + 520) |
| N11 | `ChangeDir` cleared `TopIndexMem` before the refusal | the clear moved to the five places where a path change really starts (`ChangePathToDetachedFS`, `ChangePathToPluginFS`, `ChangePathToArchive`, two `ChangePathToDisk`); every refused or failed path now leaves it alone |

Correction to the S2 text above: review SHOULD-FIX 1 of S1 (history) and the
tab revert are now driven by the explicit `refusedTooLong` flag, not by
`noChange`; inventory row 15 now shows the message.

Found by the reviewer, older than 097, **not changed** (queued as their own
feature):

- (a) a run-time check failure under `CStatusWindow::BuildHotTrackItems`
  (`src/stswnd.cpp`) while navigating plain DISK folders about 7,500-8,200
  characters deep; identical on the build before the feature;
- (b) `src/fileswn3.cpp:2463` (at the review; now near 2490)
  `strcpy(shortenedPath[MAX_PATH], copy)`; `src/fileswn9.cpp:1929-1933`
  `uncPath` in `CopyUNCPathToClipboard`;
- (c) `src/plugins/7zip/extract.cpp:650` `_stprintf` into `msg[1024]` with an
  item path from inside the archive.

### Final runs (after the second-review fixes)

`arcwork_probe.ps1` gained: RESTART / END2 for every archive (closed with the
panel inside the archive, started again without `-l`: the stored panel path -
the archive's folder, by design on every build - is restored without a message);
nine very long cases (ZIP and 7z at 1,000 and 5,000 bytes, ASCII and U+20AC
folders; TAR at 7,000 bytes); HDEAD (history over a dead archive on a subst
drive, removed in a finally block).

| Run | Result |
|---|---|
| `arcwork_probe.ps1`, S2 build | 390 PASS / 0 FAIL / 21 n/a: all 27 archives pass every step (ENTER, VIEW, UNPACK, EDIT, UPDATE, REENTER, DELETE, LEAVE, ADD, TWO, HIST, TAB, END, RESTART, END2; EDIT / DELETE / ADD n/a for TAR); RELL refused; CLIP nothing shown; **HDEAD: Back 1 error for the archive, Back 2 error for the drive, Back 3 the start folder** |
| `arcwork_probe.ps1`, build before the feature | 70 PASS / 10 FAIL / 304 not driven: the three C200 controls pass every step incl. RESTART; U130 / U200 / L300A: Enter does nothing (9 FAIL); folders over 519 bytes not reachable; RELL not refused (1 FAIL); **HDEAD: the same three-Back sequence** |
| `arcpath_probe.ps1 -Stage S2`, S2 build | 55 PASS / 0 FAIL; twin archive shown: 0 |
| 095 `longarc_probe.ps1`, S2 build | 60 PASS / 0 FAIL |
| 096 `archedit_probe.ps1`, S2 build | 17 of 17 UPDATED |

HDEAD was not run against the rejected S2 binary (it no longer exists); the
reviewer's observation of the stuck history is the negative control.

Gates: Debug x64 build exit 0; `saltests` 13,119 checks, 0 failed; strict
encoding guard TOTAL: 0. `demoplug` (off in `plugins.cfg`) compiled once by hand
(exit 0), its output removed by the next `build.cmd` run.

Not driven after the second review (compiled and read): the directory-line and
command-line drop refusals (need a real drag on the input desktop); the hot path
set from the directory-line menu and the path-field menu refusals (context
menus); `CanCloseArchive` backstop and the `refusedTooLong` revert of a tab
(no refused location can be stored with the shipped plug-ins); a relative `-L`
with a current folder over 259 bytes; the filter text on a location near the
98,301-byte limit.

## Third review (ACCEPT) and the final gates (2026-10-03)

Re-review of the reworked S2: ACCEPT. The reviewer re-ran its own dead-history
scenarios on both builds (an archive on a removed `subst` drive; an archive in
a deleted folder): identical sequences, Back reaches the start folder; its
length ladder (ZIP at 200, 300, 1,000, 5,000, 20,000 bytes: enter, view,
unpack, edit + update, delete, add, Back / Forward, tab) 50 / 0. Judged:
keeping `TopIndexMem` on a failed change of path is correct (the memory
validates itself; failures that move the panel clear it); `CanCloseArchive`
returning TRUE for an older plug-in is the right default (such a plug-in never
opened the archive). Its three NITs: a sixth `TopIndexMem.Clear()` before the
"listable but not found by name" branch of `ChangeDir` - added; an Explorer
drop that does not fit as UTF-8 fell back to the code page and could hand on
`?` - now refused; a failed heap copy reported as "too long" - left (harmless).

Final run on the final tree (all GUI on the hidden desktop):

| Gate | Result |
|---|---|
| Debug build; full Release build | no errors |
| saltests | 13,119 checks, 0 failed |
| `check_encoding.py --strict` | TOTAL: 0 |
| `arcpath_probe.ps1 -Stage S2` | 55 PASS / 0 FAIL; twin archive shown 0 times |
| `arcwork_probe.ps1` | 390 PASS / 0 FAIL / 21 n/a |
| 095 `longarc_probe` | 60 / 0 |
| 096 `archedit_probe` | 17 of 17 UPDATED |
| 093 `dialogs_probe` / `cmdline_probe` | 139 / 0 LOSSY / 0 FAIL (1 not driven, the known menu row) ; 63 / 0 |
| registry key after everything | identical (`1AB61430...`); no test process left |

