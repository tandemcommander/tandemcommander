# Fix log - 386-mydocs-path-whole

Backlog item `my-documents-drive-opens-a-cut-path-when-documents-needs`.

## Measurement at 10eb1994 (main, before the feature)

Code reading (the GUI needs a seam, see below):

- `src/shellib.cpp` `GetMyDocumentsOrDesktopPath`: `SalSHGetPathFromIDListU8(pidl, buff, 2 * MAX_PATH)`
  then `lstrcpyn(path, buff, pathLen)` + `SalU8TrimIncompleteTail(path)` - the cut. `buff` is 520
  bytes: a Documents path of 174-259 units in 3-byte letters (more than 519 bytes) falls to the
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
