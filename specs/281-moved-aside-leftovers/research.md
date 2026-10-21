# Research: 281 moved-aside leftovers

## R1 How a create function hands the left entry to its caller

- Decision: an optional last parameter `CMovedAsideLeft* left` on the core's `SalCreateFileEx`,
  `SalCreateDirectoryEx` and `MakeUnpackFoldersOwn`. With a record, the function fills it and the
  caller shows it (in its own window and order); with `NULL` the function shows it itself
  (`ReportMovedAsideLeft(NULL, ...)`) - so no caller can drop it silently.
- Rationale: the item names an out parameter; defaults keep every existing call compiling and,
  more importantly, never silent.
- Alternatives: a thread-local "last left entry" (implicit, can go stale and be shown at an
  unrelated later site); a new plug-in API (maintainer-owned, constitution V).

## R2 Which dialog

- Decision: `::DialogError(parent, BUTTONS_OK, path, GetErrorText(err), LoadStr(IDS_ERRORRENAMINGFILE))`
  - the OK-only `IDD_ERROR3` dialog; the worker sends the same through its progress dialog
  (`WM_USER_DIALOG` 5 = `CFileErrorDlg` with `IDD_ERROR3`, exactly 221's report of the worker's move).
- Rationale: existing strings (no `.slt` refresh), callable from any thread (plug-ins already call
  `DialogError` from their worker threads), shows a UTF-8 path whole.

## R3 Owner when no window is given

- Decision: `GetMovedAsideReportParent()`: the foreground window when it belongs to the calling
  thread; else the first visible enabled top-level window of the calling thread (its last active
  popup); else on the main thread the main window; else `NULL`.
- Rationale: a window of the calling thread is disabled while the box is up (no re-entry into a
  plug-in's dialog, e.g. the Renamer's); a window of another thread is never used as the owner
  from a background thread (cross-thread owner = attached input queues, possible hangs).

## R4 The retry rule and the plug-ins

- Decision: `src/common/salmoveback.h`, header-only, needs only `<windows.h>`:
  `SalMoveBackRetryable(err)`, `SAL_MOVE_BACK_RETRIES` (10) and `SAL_MOVE_BACK_WAIT_MS` (100),
  `SalMoveBackRetry(move, wait, &err)` taking the move as a callable; the core's `SalMoveFileBack`
  calls it with `SalMoveFile`, the plug-ins with `SalamanderGeneral->SalMoveFile`.
- Rationale: one rule (221's numbers), testable in `saltests` with a fake move and a fake wait.

## R5 Driving the race

- Decision: a Debug-only seam in the same header: `TC_PROBE_MOVE_BACK_FAIL=<n>` makes the first n
  move-back attempts of the module fail with `ERROR_SHARING_VIOLATION` (read once per module;
  `n` large = always; `n` 3 = a short hold within the retry window). Contract:
  `contracts/probe-seam.md`.
- Rationale: as features 125 and 246 (Debug-only env seams); a held handle cannot hit the
  microsecond window between the two moves.
- Alternatives: a probe that watches the folder and opens `salNNN` (loses the race; the retry
  window would hide it anyway).
