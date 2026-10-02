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
