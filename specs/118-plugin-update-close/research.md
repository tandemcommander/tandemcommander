# Research: feature 118 - plug-in windows and an installer's close request

Code reading at `72a14a8e` (HEAD of 117). No GUI run (see `spec.md` Clarifications).

## R1 - How the core decides and acts (080, 088)

- Question (`WM_QUERYENDSESSION`, `ENDSESSION_CLOSEAPP`): `CMainWindow::DecideCloseApp()`
  (`mainwnd3.cpp`) - D1..D8; D8 enumerates every top-level window of the process and declines on
  a visible, real window (`WS_CAPTION`, or not a tool / no-activate window) of an unknown kind that
  does not carry the property `SALCLOSEAPP_WINDOW_PROP` (set by `SetWindowClosesUnattended`).
- Instruction (`WM_ENDSESSION`): the decision is taken again; then the ordinary exit runs with
  `UnattendedClose` set; `CPlugins::UnloadAll` calls `Release(parent, FALSE)` of each loaded
  plug-in and stops at the first refusal; the core's own "force unload?" question is skipped
  (`plugins1.cpp:3212`).
- So a plug-in window declines the update unless declared; a declared window must be closed by
  `Release()` without a question.

## R2 - File Comparator (`src/plugins/filecomp`)

- Windows: the comparator window (`CMainWindow`, class `SFC Window Class`, its own thread
  `CFilecompThread`, in `MainWindowQueue`); the Compare Files dialog (modeless, its own thread,
  also in `MainWindowQueue`; the same class modal from a comparator); Options / Go to / Colors
  dialogs and `SalMessageBox`es owned by the comparator.
- Content: read-only. The comparator reads the two files, shows the differences; nothing is
  written (the "copy" commands copy to the clipboard).
- Close: `WM_CLOSE` -> `CM_EXIT`. With input enabled: `DestroyWindow`; `WM_DESTROY` sets
  `CW_SILENT` and waits for the worker with a message pump. While comparing (input disabled):
  `CancelWorker = CW_EXIT`; the worker throws on its next check (`CancelFlag` is polled in the
  diff, the line identification and the cached reader) and posts `WN_WORKER_CANCELED`, which posts
  `CM_EXIT` - no message box.
- **Race found**: when the worker finishes with a result just before it sees `CW_EXIT`, the
  result handler (`WM_USER_WORKERNOTIFIES`) shows its box: "The files are identical. Do you wish
  to close File Comparator?", "all differences ignored", an error - and for "files differ" the
  window simply stays open: the close request is lost. During an unattended close that box would
  appear on an unattended screen and `Release()` would time out. Fixed (FR-007). A result sent by
  a worker that is being dropped (`CW_SILENT` - window destroyed, comparison replaced) likewise
  shows no box now.
- `CancelWorker` was not initialised in the constructor (always set by `SpawnWorker` before any
  worker exists; initialised now because the new code reads it).
- `Release()` never asked anything: `CRemoteComparator::Terminate`, `CloseAllWindows(force)`
  (1 s), `KillAll(force)` (1 s).

## R3 - Disk Map (`src/plugins/diskmap`)

- Windows: the map window (`Zar.DM.MainWin.WC`, one thread per window, `WindowThreadBody`), its
  Log window (`Zar.DM.LogWin.WC`, `WS_POPUPWINDOW | WS_CAPTION`, owned by the map, hidden until
  View > Log Window, `WM_CLOSE` hides it), its file tooltip (`Zar.DM.ToolTip.WC`, `WS_POPUP |
  WS_BORDER`, no tool-window style - so D8 counts it as a real window while it is shown), the
  shell context menu (a menu window - not counted), the About box and the Esc close confirmation
  (`SalMessageBox[Ex]`, owned).
- Content: read-only (a scan of a folder). Close: `WM_CLOSE` -> `DefWindowProc` ->
  `DestroyWindow` -> `OnDestroy` deletes the view -> `CDiskMap::Abort()` sets the worker's abort
  flag (polled per file, `CZDirectory.cpp:317`) and waits for it. No question.
- `Release()` posts `WM_CLOSE` to every map window and `KillAll(force)` (1 s) - no question.
- **Defect found**: `Release()` freed the thread records (`TThreadInfoItem`) **before** waiting for
  the threads; a window thread writes `MyThreadInfo->MainWindow = 0` into its record when it
  ends. When `KillAll` returned FALSE (a thread still running - `Release()` refused), the thread
  later wrote into freed memory. Reachable on a normal exit with a slow abort (1 s) and in an
  unattended close (5 s). Fixed (FR-008): records freed only after the threads ended.
- **Interface level**: `SalamanderPluginGetReqVer()` returns 103 (`OPENSAL_VERSION` is defined
  nowhere, so `SALSDK_COMPATIBLE_WITH_VER` applies) - Disk Map is the one in-tree plug-in of the
  four that still loads in a core of interface 103-106, where `IsUnattendedClose` /
  `SetWindowClosesUnattended` do not exist (calling them would call past the end of the core's
  interface). The calls are guarded by `SalamanderVersion >= 107` (FR-009). File Comparator,
  Checksum and Batch Renamer refuse to load below `LAST_VERSION_OF_SALAMANDER` (107).

## R4 - Checksum (`src/plugins/checksum`)

- Windows: Calculate and Verify dialogs (`CDialog::Execute` = modal `DialogBoxParam` with no
  owner, each on its own thread, in `ModelessQueue`); the Save dialog (common dialog), the overwrite
  question, error boxes of the workers (`SafeOpenCreateFile`, `SafeReadFile`), the configuration
  dialog - all owned, all undeclared.
- Close: `WM_CLOSE` -> (window enabled) `EndDialog(IDCANCEL)`; `WM_DESTROY` stops the worker
  (`bTerminateThread`, checked per 256 KB read) and waits for it. **No "save?" question exists**:
  a normal exit (and the plug-in's `Release`) closed a Calculate window with unsaved hashes
  silently in every release - unchanged for a person (they chose to exit); an unattended close
  must not do it.
- Verify: reads the list and the files, shows OK / CORRUPT / MISSING. Nothing to keep.
- Calculate: reads the files, the hashes exist only in the window until Save. Holds work from
  its start (reading folders, calculating) until saved; again after a row is removed (Del or the
  context menu) - the list then differs from the saved file. Save is enabled exactly when there is
  something to save (`OnThreadEnd` enables it when the list is not empty and some hash type is
  calculated; `DeleteItem` disables it when the list becomes empty).
- Save: `fprintf` results were not checked; a write error (disk full) produced a truncated list
  without a word - recorded (R7). For this feature a list counts as saved only when `ferror` and
  `fclose` report no error.
- **One save writes one hash type** (the type picked in the Save dialog, `Config.HashType`);
  the window calculates every type enabled in the configuration - by default all five
  (`checksum.cpp` `Config.HashInfo`: CRC, MD5, SHA1, SHA256, SHA512). "Saved" therefore has to be
  per type: the window holds nothing unsaved only when every calculated type was saved (code
  review S2). And `_wfopen(..., "wb")` truncates the target at once: a re-save over the file of
  a saved type destroys that list until the write completes - the type is forgotten at the open,
  identified by the file's volume serial and file index (`GetFileInformationByHandle`, so a
  different spelling of the same file is recognised; all types are forgotten when the file
  cannot be identified) and counted again only after `ferror` / `fclose` report success (code
  review S1).
- `Release()` never asked anything: `CloseAllWindows(force)` (1 s), `KillAll(force)` (1 s).

## R5 - Batch Renamer (`src/plugins/renamer`)

- Window: the renamer dialog (modeless, own thread, `WindowQueue`). Holds the masks, options, the
  manual list, and `UndoStack` - the undo of renames already performed, lost when the window
  closes. During a rename a progress dialog runs and the dialog is disabled; `WM_CLOSE` then only
  flashes the window.
- `WM_CLOSE` with the window enabled: `DestroyWindow` - no question (the Esc confirmation is on
  `IDCANCEL`). `Release()` never asked anything: `CloseAllWindows(force, 1000, INFINITE)`.
- Decision: never declared (spec). `Release()` during an unattended close refuses while a window
  is open (FR-006) - otherwise a race would close it and lose the Undo.

## R6 - Other enabled plug-ins with top-level windows (`plugins.cfg`, 20 on)

| Plug-in | Top-level windows of its own | Today |
|---|---|---|
| codeview, mdview, pictview, dbviewer | viewers | declared (088) |
| filecomp, diskmap, checksum, renamer | see R2-R5 | this feature |
| regedt | Find window (modeless, own thread, results list, may be searching) | declines (undeclared); candidate: declare while not searching, like the core's own Find (080 D5) |
| ftp | operation windows, Logs window, Welcome Message window | declines; operations must; the Logs and Welcome windows hold nothing - candidate |
| sftp | none outside modal dialogs; its file system in a panel declines (D7) | - |
| portables | a message-only window (`HWND_MESSAGE`, not enumerated) | - |
| peviewer | uses the internal viewer (closed by the core) | - |
| 7zip, folders, tar, uncab, undelete, uniso, zip | modal dialogs / progress only (the main thread is busy: D2) | - |

Recorded for the backlog, not changed (the item named the four plug-ins).

## R7 - Found on the way, not fixed

- Checksum Save ignored write errors: a full disk produced a truncated list without a message
  (now at least not counted as saved). Needs a message (an existing string fits:
  `IDS_ERRORCREATINGFILE`) - backlog.
- A worker error box (File Comparator hex view `HandleFileError`, Checksum read errors) can appear
  while its window closes; owned by the closing window - pre-existing, also on a normal exit.
- `CDiskMap::Abort()` called `SetSelfDelete(TRUE)` before `Abort(TRUE)` on the same object: when
  the worker had already finished, `SetSelfDelete` deleted it at once and `Abort` ran on freed
  memory - upstream, but now also reachable by an unattended close during a scan. **Fixed**
  (contained): `CWorkerThread::AbortAndSelfDelete()` sets the abort flag while the object is
  alive, hands it over, and waits on the thread handle taken before; the worker still sees
  "aborting and self-delete" and frees the detached root as before.
- Disk Map's `Release()` has no FR-006-style guard: an About box, the Esc confirmation, the shell
  context menu or a shell file operation started from the map between the core's decision and
  the plug-in's turn gets `WM_CLOSE` and the map is destroyed from inside that modal or menu loop
  (pre-existing on a normal exit; a window of milliseconds in an unattended close) - recorded.
- File Comparator: when `CloseAllWindows` times out, `Release()` returns FALSE after the remote
  comparator (the `fcremote.exe` channel) was already terminated - the same as on the normal path
  since Open Salamander; recorded.
