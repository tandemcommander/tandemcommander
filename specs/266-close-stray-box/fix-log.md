# Fix log: 266 - plug-in closing: forced Disk Map unload in a shell command, stray comparator box

Backlog item `plugin-close-forced-unload-and-stray-box` (leftovers of 143 and 147's review LOW-2).

## Before (measured 2026-10-20 at `5eb288af`, code reading)

- Part (1), Disk Map: `CPluginInterface::Release` (`src/plugins/diskmap/DiskMapPlugin/DiskMapPlugin.cpp`)
  with `force` TRUE calls `ThreadQueue.KillAll(TRUE)` - waits `forceWaitTime` 200 ms
  (`src/plugins/shared/auxtools.h`) and then `TerminateThread`. The core
  (`src/plugins1.cpp` `CPluginData::Remove`) calls `Release(parent, TRUE)` after "force?" Yes and
  `FreeLibrary` right after it; `spl_base.h`: with `force` the return value is not respected. 143's
  probe row E5 recorded the result (clean exit, file kept, the Debug leak reports of the
  terminated thread). Still as recorded.
- Part (2), File Comparator: `CMainWindow::WindowProc` `WM_DESTROY` (`src/plugins/filecomp/mainwnd.cpp`)
  destroys the views' data and then, while a comparison worker runs, waits with
  `MsgWaitForMultipleObjects` + `PeekMessageW(PM_REMOVE)` + `DispatchMessageW`. The hex views are
  children and still exist; a pending `WM_USER_HANDLEFILEERROR` (posted by
  `CHexFileViewWindow::HandleFileError`, `viewwnd3.cpp`) reaches the handler, which shows
  `SG->DialogError` (Retry / Cancel) and on Cancel posts `CM_CLOSEFILES` (the "close the
  comparison?" question). No check of the close. Still present.
- `CFileMapping::Destroy` (`src/plugins/filecomp/filemap.cpp`) closes view, mapping and file and
  keeps `FileSize`. Still present.
- Reproduction of part (2) on the hidden desktop: not feasible (research R2) - the pump runs only
  while a worker runs at close time, and the message must be posted by the view's own paint in
  that window (its `wParam` is a pointer of the process). Recorded as NOT DRIVEN.

## Decisions

- Part (1): no behaviour change (research R1). A forced release cannot be declined; an unbounded
  wait freezes the main window; the only route that makes the shell call return - cancelling the
  shell's window - reverses 143's recorded decision (FR-004), which is the maintainer's. The
  item's *Approach* / *Notes* accept the termination as the force semantics. The site gets a
  comment; a `decision` item carries the alternative.
- Part (2): the close begins at the main window's `WM_DESTROY`; both views get `BeginClose()`
  first, and the hex view's `WM_USER_HANDLEFILEERROR` returns at once once it is set.
- `speckit-analyze`: CRITICAL 0, HIGH 0; MEDIUM E1 (no task for the decision item) fixed in
  T010; LOW U1 (US1 only by code review - research R2) and F1 (probe row list notation) accepted.

## Work

- `src/plugins/filecomp/viewwnd.h` / `viewwnd.cpp`: `CFileViewWindow::CloseBegun` (FALSE in the
  constructor) + `BeginClose()`.
- `src/plugins/filecomp/mainwnd.cpp` `WM_DESTROY`: `BeginClose()` on both existing views first -
  before `DestroyData` and the worker wait that dispatches the thread's messages.
- `src/plugins/filecomp/viewwnd3.cpp` `WM_USER_HANDLEFILEERROR`: `if (CloseBegun) return 0;` - no
  `DialogError`, no posted `CM_CLOSEFILES`. A recompare while the window stays open
  (`WN_BINARY_FILES_DIFFER`) does not set the mark - its box keeps its behaviour (FR-002).
- `src/plugins/filecomp/filemap.cpp` `CFileMapping::Destroy`: `FileSize = 0` after the handles.
- `src/plugins/diskmap/DiskMapPlugin/DiskMapPlugin.cpp` `Release`: a comment at `KillAll` on the
  force path (no code change).
- Decision item `forced-disk-map-unload-in-a-shell-command-cancel-the-shell` (Inbox, measure:266):
  A keep the termination (recommended) / B cancel the shell's window, then wait.
- Observed, not changed (an earlier state, spec *Assumptions*): `CM_EXIT` with an open box
  (window disabled) closes the owned boxes first and retries after 100 ms; if the closed box is
  the hex view's error box, its Cancel posts `CM_CLOSEFILES`, which runs before the retried
  `CM_EXIT` and shows the "close the comparison?" question - which the next retry closes in turn.
  Pre-existing, low, not this item's route (the close has not begun there).

## After (2026-10-20, Debug x64 of the branch)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- clang-format `--dry-run` on the changed files: no new findings (`mainwnd.cpp` keeps its 2
  pre-existing ones at lines untouched by 266).
- `.\build.cmd`: BUILD SUCCEEDED (`filecomp.spl`, `diskmap.spl` rebuilt 16:47).
- `saltests.exe`: `saltests: 24716 checks, 0 failed` (no new checks - no pure rule).
- `probe/result_143_E4-E6.txt` (143 probe `-Only E4,E5,E6`, hidden desktop): **PASS 7, FAIL 0,
  NOT DRIVEN 0**; registry restored, identical. E5 as recorded in 143: clean exit in 5.2 s, file
  kept, the Debug leak reports of the forced unload (part (1) kept by decision).
- `probe/result_147_K1.txt` (147 probe `-Only K1`, the comparator's close with its box open):
  **PASS 2, FAIL 0**; registry restored, identical.
- Comparator stray box (US1): **NOT DRIVEN** (research R2) - proven by code reading and the
  independent review. Not owed to a person either: the timing cannot be produced by hand.
