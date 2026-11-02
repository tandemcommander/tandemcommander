# Fix log - 386-mydocs-path-whole

Backlog item `my-documents-drive-opens-a-cut-path-when-documents-needs`.

## Measurement at 10eb1994 (main, before the feature)

Code reading (the GUI needs a seam, see below):

- `src/shellib.cpp` `GetMyDocumentsOrDesktopPath`: `SalSHGetPathFromIDListU8(pidl, buff, 2 * MAX_PATH)`
  then `lstrcpyn(path, buff, pathLen)` + `SalU8TrimIncompleteTail(path)` - the cut. `buff` is 520
  bytes: a Documents path of more than 519 bytes (e.g. 200 CJK letters) falls to the
  Desktop even for the callers with `SAL_MAX_PATH_UTF8`.
- Reachable from: the drive bar Documents button (`CDriveBar::Execute` -> `ChangePathToDrvType`,
  `fileswn3.cpp`, `path[MAX_PATH]`), the Alt+F1/F2 menu item Documents (`ChangeDrive` ->
  `ChangePathToDrvType`), Ctrl+; (`fileswn0.cpp`, `path[MAX_PATH]`); `ChangePathToDisk` then opens
  the cut path.
- Other callers (Grep `GetMyDocumentsOrDesktopPath`, 8 calls): `SafeGetOpenFileName` /
  `SafeGetSaveFileName` (`SAL_MAX_PATH_UTF8`), `SafeGetSaveFileNameW` / `SafeGetOpenFileNameW`
  (`MAX_PATH`), `GetIfPathIsInaccessibleGoTo` (`MAX_PATH`; callers fileswn2.cpp x3, dialogs5.cpp
  x2, mainwnd2.cpp, zip.cpp -> plug-ins `SALCFG_IFPATHISINACCESSIBLEGOTO`, limited to MAX_PATH).

## Analyze

No CRITICAL / HIGH / MEDIUM. LOW C1 (T014 conditional) - decided at closing; LOW U1 (the RESCUE row
depends on the start-up route reaching the rescue path) - checked in the before-run.

## Log

### T002-T004 - seam, probe, the measurement before the fix

- Seam (Debug only) `TC_PROBE_MYDOCS_FILE` in `GetMyDocumentsOrDesktopPath` (old code otherwise
  unchanged). First tried as `TC_PROBE_MYDOCS_PATH` holding the path itself: the program received
  90 literal `?` (message code units dumped: `003F` x 90, error 123). Cause: `CEnvVariables`
  (`src/salamdr7.cpp`) reads the environment with the code-page `GetEnvironmentStrings` and writes
  differences back with `SetEnvironmentVariable` (code page) at start - every variable with
  letters outside the code page becomes `?` in the program and its children. Out of scope ->
  Inbox (`measure:386`). The seam now reads the folder from a UTF-8 file named by the variable.
  (Passing a CJK value through Windows PowerShell `Start-Process` itself was checked: intact.)
- Probe rows: the drive bar 1 Documents index is in the `ALL idx=.. type=7` lines of the
  `TC_PROBE_DRIVES_DUMP` build (not in its `ITEM` lines, which list the drives only).
- RESCUE row: a left panel on a drive letter that does not exist (`Q:\tc386_none`) only gave
  "The path or file name "Q:\" is invalid." and stayed on another folder - the rescue route needs
  a root that exists but cannot be listed. Recorded NOT DRIVEN (code reading; analyze U1).
- `.\build.cmd` -> BUILD SUCCEEDED; probe on the hidden desktop -> `probe/result_before.txt`:
  SHORT PASS (the short folder), **LONG FAIL - the panel silently opened the PREFIX folder**
  (`...\tc386\` + the first 73 of 90 letters, 259 bytes; no message), registry restored identical.

### T005-T011 - the fix

- `src/common/salmydocs.h` (new, header-only): `SalDocumentsOrDesktopToU8(docsW, desktopW, path,
  pathSize)` - Documents when it has a path, the Desktop only when it has none; the UTF-8 size is
  measured first; whole (`SAL_DOCS_OK`) or refused with an empty buffer (`SAL_DOCS_TOO_LONG`, also
  for a Documents path that does not fit - the Desktop is not used instead), `SAL_DOCS_NONE`.
- `src/shellib.cpp` `GetMyDocumentsOrDesktopPath`: reads both folders wide
  (`GetSpecialFolderPathW`, `SHGetPathFromIDListW`, the Desktop only when Documents has no path),
  hands them to the rule; `buff[2 * MAX_PATH]`, `lstrcpyn`, `SalU8TrimIncompleteTail` gone;
  `TRACE_E` on a refusal. The seam stays (Debug).
- Callers (Grep: 8 calls): `fileswn0.cpp` Ctrl+; and `fileswn3.cpp` `ChangePathToDrvType` (drive
  bar button, Alt+F1/F2 menu item) now `char path[SAL_MAX_PATH_UTF8]` (the other branches of
  `ChangePathToDrvType` copy `MAX_PATH` sources - `DropboxPath`, `OneDrivePath`, the checked
  OneDrive Business folder, `GetPathForGoogleDrive(path, MAX_PATH)` - unchanged limits);
  `salamdr6.cpp` `SafeGetSaveFileNameW` / `SafeGetOpenFileNameW` `initDir[SAL_MAX_PATH_UTF8]`
  (`initDirW[MAX_PATH]` holds every 259-unit path); `SafeGetOpenFileName` / `SafeGetSaveFileName`
  already `SAL_MAX_PATH_UTF8` (unchanged); `GetIfPathIsInaccessibleGoTo` keeps `MAX_PATH` - a
  refusal takes its existing fallback, the Windows drive root (comment added; spec
  Clarifications).
- Stack: two new `SAL_MAX_PATH_UTF8` (96 KB) locals (Ctrl+; handler, `ChangePathToDrvType`); the
  stack is 3 MB and `ChangePathToDisk`, called right after, already holds such arrays.

### Checks

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (Debug x64).
- saltests -> `saltests: 30699 checks, 0 failed` (`TestDocumentsPath386`: 24 CHECK sites, 113 checks with the per-letter loop; its negative
  control `OldDocumentsPath386` = the old copy rule gives the 259-byte strict prefix - reproduced
  by the test itself).
- clang-format: `salmydocs.h`, `shellib.cpp`, `fileswn0.cpp`, `salamdr6.cpp` clean; `fileswn3.cpp`
  2 findings, both older (the same at HEAD); `saltests.cpp` +1 = the new include line in the
  include block, which is unformatted at HEAD (lines 90-100 all flagged).
- Probe after the fix (`probe/result_after.txt`): SHORT PASS, **LONG PASS - the whole folder**
  (before: the prefix folder), RESCUE NOT DRIVEN; registry restored identical.
- NOT DRIVEN (code reading, the same helper and buffer change): Ctrl+; (needs a real Ctrl key
  state on the hidden desktop), the Alt+F1/F2 menu item (same `ChangePathToDrvType` as the
  button), the File Open / Save fallback (only when the common dialog refuses its initial folder),
  the rescue path (see T002-T004). Owed to a person: Ctrl+; with a long Documents.

### T014 - items added (Inbox)

- `environment-variables-passed-to-the-program-arrive-as` (bug, measure:386) - the code-page copy
  of the environment at start (`CEnvVariables`).
- `rescue-path-goes-to-the-windows-drive-root-when-documents` (improvement, leftover:386) - the
  rescue path keeps MAX_PATH (decided C1 of analyze: worth an item).
- `confirm-ctrl-opens-a-long-documents-folder-whole-on-a-real` (person-step, leftover:386) -
  Ctrl+; and Alt+F1 with the seam on a real keyboard.

## Review

### Review 1 (independent agent, refute-first) - no MUST

Re-measured: build, saltests 30699 / 0 failed, encoding guard 0; probe after SHORT / LONG PASS;
negative control = a worktree at 66a9dfcc (the seam with the old code) built in
`%TEMP%\rev386\build`: LONG FAIL (the prefix folder). All 8 callers enumerated; no data written
or deleted; a refusal empties the buffer.

- SHOULD 1 (fixed): the RESCUE row can be driven - a subst drive on a fixture folder, the left
  panel on it, the folder's listing right denied to the user (`icacls /deny <me>:(RD)`, removed
  right after), `WM_COMMAND 724` (CM_LEFTREFRESH). Added as rows RESCUE-SHORT / RESCUE-LONG (free
  subst letter, deny and subst removed in `finally`). Settles analyze U1.
- SHOULD 2 (fixed): FR-006 had no probe row - the LONG row (310 bytes) fits the old 520-byte
  buffer. Added row LONG200 (200 letters, 240 units, 640 bytes): the old code opened the
  **Desktop** (`C:\Users\pavel\Desktop`) silently even on the long-path drive bar route - a second
  "another folder" the fix removes.
- NOTE 1 (-> Inbox): a Documents path of 260 or more UTF-16 units still falls silently to the
  Desktop (`SHGetPathFromIDListW` is MAX_PATH-bound) - recorded in the spec's edge cases; item
  added.
- NOTE 2 (-> the rescue-path item's Notes): the settings page and the configuration load compare
  with `GetIfPathIsInaccessibleGoTo(path, TRUE)`, which is the drive root for such a user - the
  page shows `C:\` for "Documents", and typing `C:\` switches to Documents mode.
- NOTE 3 (accepted): the 96 KB local in the Ctrl+; handler frame (`OnSysKeyDown`), not recursive,
  3 MB stack.
- NOTE 4 (recorded): the Release build was not compiled by the reviewer (the code outside
  `_DEBUG` is plain); the closing run builds Debug - see *Checks*.

### Probe after the review fixes (same probe, both builds)

| Row | before (66a9dfcc, the reviewer's negative-control build) | after (this branch) |
|---|---|---|
| SHORT | PASS | PASS |
| LONG | FAIL - the PREFIX folder | PASS - the whole folder |
| LONG200 | FAIL - `C:\Users\pavel\Desktop` | PASS - the whole folder |
| RESCUE-SHORT | PASS | PASS |
| RESCUE-LONG | FAIL - the PREFIX folder | PASS - `C:\` (refused, the drive-root fallback) |

`probe/result_before.txt` (3 FAIL), `probe/result_after.txt` (5 rows, 0 FAIL); registry restored
identical in both; no subst drive left (`subst` empty).
