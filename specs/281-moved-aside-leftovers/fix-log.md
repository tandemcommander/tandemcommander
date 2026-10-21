# Fix log: 281 - an entry moved aside for an 8.3 clash is never left under salNNN silently

Backlog item `moved-aside-restore-leftovers` (leftover of 221).

## Measured at 17ac1562 (by reading - a race, not drivable without a seam)

- `SalCreateFileEx` / `SalCreateDirectoryEx` (`src/worker.cpp`) and `SafeFileCreate`
  (`src/safefile.cpp`): when the first `SalMoveFileBack` fails, the new file / folder is removed and
  the move back repeated; when that fails as well only `TRACE_E`. The caller gets the create's
  error (the move back's reason) and reports "cannot create <the new name>"; nothing names the
  `salNNN` entry. In `SafeFileCreate` a Retry then finds the short name free and creates the file:
  the other entry stays under `salNNN` silently.
- Callers enumerated (Grep `SalCreateFileEx\(|SalCreateDirectoryEx\(|MakeUnpackFoldersOwn`):
  `worker.cpp` copy (2 calls of `SalCreateFileEx`), `DoCreateDir`; `fileswn5.cpp` Edit New File,
  F7 Create Directory; `salamdr3.cpp` `MakeUnpackFoldersOwn` (from `CheckAndCreateDirectory` and
  `SafeFileCreate`); `zip.cpp` the plug-in wrappers (FTP `operats5.cpp`, SFTP `operats.cpp`,
  Renamer `rendlg3.cpp`, DemoPlug).
- PictView `PvMoveAsideShortNameClash` and Renamer `MoveAsideShortNameClash`: the move back is one
  `SalamanderGeneral->SalMoveFile` (a second only after undoing the rename) - no retry; they do
  report the `salNNN` name.

## Decisions

- Out parameter `CMovedAsideLeft*` on the core functions; with none, the function shows the
  message itself (never silent) - the plug-in interface unchanged (research R1).
- The message: `DialogError(..., BUTTONS_OK, salNNN path, reason, "Error Renaming File")` - 221's
  form and strings (R2). Owner rule R3.
- `src/common/salmoveback.h`: 221's retry rule shared by the core and the two plug-ins, plus the
  Debug-only seam `TC_PROBE_MOVE_BACK_FAIL` (contract `contracts/probe-seam.md`).

## Work

1. `src/common/salmoveback.h` (new, header-only): `SalMoveBackRetryable`, `SAL_MOVE_BACK_RETRIES` 10,
   `SAL_MOVE_BACK_WAIT_MS` 100 (221's numbers), `SalMoveBackRetryEx(move, wait, seam, &err)`,
   `SalMoveBackRetry` (Sleep + the Debug seam), the seam `TC_PROBE_MOVE_BACK_FAIL` (parse, take).
   `SalMoveFileBack` (`salfileio.cpp`) uses it. `saltests` `TestMoveBack281`.
2. Before measurement (the seam in, nothing else): see *Measurements*.
3. `consts.h`: `CMovedAsideLeft` (UTF-8 path + error), `ReportMovedAsideLeft`,
   `GetMovedAsideReportParent`; an optional `CMovedAsideLeft* left` on `SalCreateFileEx`,
   `SalCreateDirectoryEx`, `MakeUnpackFoldersOwn`.
4. `worker.cpp` `SalCreateFileEx` / `SalCreateDirectoryEx`: when the second move back fails, the
   record is filled (path = the salNNN entry, error = that move back's - it also becomes the
   create's error, as before only the first one was kept); with no record the function shows it
   itself. The worker's file copy and `DoCreateDir` show it through the progress dialog
   (`WM_USER_DIALOG` 5, 221's form; the last error kept). Trap: the copy's `goto`s skipped the new
   local (C2362) - it lives in a block of its own.
5. `salamdr3.cpp`: `ReportMovedAsideLeft` = `DialogError(BUTTONS_OK, path, reason, "Error Renaming
   File")`; `GetMovedAsideReportParent` = the calling thread's foreground / first visible enabled
   captioned top-level window (its last active popup), else the main window on the main thread,
   else none. `MakeUnpackFoldersOwn` passes the record on; `CheckAndCreateDirectory` shows it in
   every mode with the parent the caller gave (else the rule above).
6. `safefile.cpp` `SafeFileCreate`: its own move aside and the `MakeUnpackFoldersOwn` route show
   it with `hParent` before the create's error dialog (whose Retry would create the file in the
   freed short name).
7. `fileswn5.cpp`: Edit New File and F7 show it before their error (the last error kept).
8. `zip.cpp`: the plug-in wrappers pass no record - the create shows it itself (owner rule above);
   the plug-in interface unchanged.
9. PictView `PvMoveAsideShortNameClash`, Renamer `MoveAsideShortNameClash`: both move backs through
   `SalMoveBackRetry` (a lambda around `SalamanderGeneral->SalMoveFile`).

## Measurements

Probe `probe/left281_probe.ps1` (driver of 203's), hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\281-moved-aside-leftovers\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\281-moved-aside-leftovers\probe\left281_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"
```

- Before (`result_before.txt`, the copy rows again in `result_before_copy.txt` after the probe
  stopped clicking the copy's progress window): PASS 8 / FAIL 6. Every `*-left` row: the other
  entry under `salNNN` (content intact), **no** message naming it - only the create's error
  ("Error Opening File" / "Error Creating Directory" / "Error Creating File" / ZIP's "Cannot create
  directory" / Edit New's "Error"). `cp-brief`: PASS (221's retry already in the core). Found on
  the way: in `zipdir-left` the unpack went on after the error and made the member's own
  `LONGDI~1` (the short name was free) - no data touched.
- After (`result_after.txt`): **PASS 14 / FAIL 0**. Each `*-left` row: exactly one "Error Renaming
  File" box, then the create's own error as before. The path is painted by `CStaticText` (no
  window text), so the probe captures the box (`shot_<row>_after.png`); read in this run: every
  capture names the very entry the probe found on disk (sal211, salC4A, sal22F, sal815, salDF1,
  sal446) with "(32) ... used by another process".
- saltests: 25,011 checks, 0 failed (the build with the header only); see *Checks* for the end.
- Renamer (`probe/ren281_probe.ps1`, derived from 199's driver; `result_ren_after.txt`): PASS 4 /
  0. `ren-brief` (seam 3): renamed, `longfilename.txt` keeps name and content, no box - the
  retry recovered; `ren-left` (seam 1000): the existing box names `...\ren-left\sal382`, which
  holds the content; x.txt keeps its name (the rename undone). The box lines repeat in the row:
  the probe closes the Renamer's progress window, whose cancel questions interleave with the box
  - one entry, one name (as in 199's `ren-83-held`). No before run for the Renamer: before this
  feature the plug-in did not use the seam (its single move back succeeded), so a before row
  says nothing.
- Incident: the first Renamer run hung in its check - the helper was named `Sal`, which
  PowerShell resolves to the alias `sal` (Set-Alias), waiting for console input. The probe was not
  stopped by hand; the session's background limit ended it at 08:47 before its `finally`. The
  registry was restored from `%TEMP%\tc281_ren_backup.reg` (reg delete + import, export
  compared: identical, A3805966...FEF), the fixture removed by the re-run. The helper is
  `SalEntries` now and the probes run with `-NonInteractive`.

## Checks

- Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Build: `build.cmd` -> BUILD SUCCEEDED (Debug x64); `build.cmd release` -> BUILD SUCCEEDED. The
  seam's variable name in the binaries (UTF-16): Release `tandemcommander.exe`, `renamer.spl`,
  `pictview.spl` 0 each; Debug `tandemcommander.exe`, `renamer.spl` 1 each (positive control).
- saltests: 25,011 checks, 0 failed. Negative control: the retry loop stopping one attempt early
  (`SAL_MOVE_BACK_RETRIES - 1`) -> 4 failed (`TestMoveBack281` edge / held / waited / seam rows);
  restored, rebuilt, 0 failed.
- Probes: `left281_probe` before 8 / 6 -> after 14 / 0; `ren281_probe` 4 / 0; regression 203's
  `create_clash_probe -Expect103` 14 / 0 (`regress_203.txt`), 201's `short_clash_probe -Expect103`
  6 / 0 (`regress_201.txt`) - both as in 221.
- Not driven: PictView's rename (the same change as the Renamer's, by reading); the plug-in
  interface wrappers' own message (FTP / SFTP need a server; no probe here reaches the wrappers -
  the Renamer's folder create was not tried). The wrappers' path is the same code as the core's
  rows, with `ReportMovedAsideLeft(NULL, ...)` called inside the create.
- clang-format: no new finding in the changed code (the one extra in `saltests.cpp` is the new
  `#include` line in the include block, which the tool reports line by line already).
