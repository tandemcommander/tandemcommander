# Research: 266 - forced Disk Map unload, stray comparator box

## R1 - Part (1): can a forced Disk Map unload avoid terminating the map's thread?

- Decision: no behaviour change; the force path is documented at `CPluginInterface::Release`
  (`src/plugins/diskmap/DiskMapPlugin/DiskMapPlugin.cpp`); a `decision` item offers the maintainer
  the one alternative that would work.
- Rationale: the core calls `Release(parent, TRUE)` after "force?" Yes and `FreeLibrary` right
  after it, whatever it returns (`src/plugins1.cpp` `CPluginData::Remove`; `spl_base.h`: with
  `force` the return value is not respected). A forced release cannot be declined. The map's
  thread is inside `IContextMenu::InvokeCommand` - the shell's window (e.g. the Delete
  confirmation) waits for the person. `KillAll(TRUE)` waits 200 ms (`forceWaitTime`,
  `auxtools.h`) and terminates it.
- Alternatives considered:
  - wait until the shell call returns (no limit): the core's main thread is blocked inside
    `Release` for as long as the shell window stays open - the main window freezes; rejected;
  - a bounded longer wait: the shell window waits for the person, who already answered "force";
    the thread is terminated anyway, only later; no gain;
  - cancel the shell's window (post `IDCANCEL` to the `#32770` dialogs of the map's thread, as
    `OnClose` does for the map's own boxes) and then wait: the shell call would return and the
    map would close cleanly - but feature 143 decided (spec *Clarifications*, FR-004,
    `contracts/close-in-loop.md`, `src/common/salloopclose.h`) that the shell's windows are
    never answered for the user ("cancelling a shell operation half-way is not the plug-in's
    decision"). Reversing a recorded decision is the maintainer's (stop-rules §1) -> a
    `decision` item, recommendation: keep the force semantics.
- The item's *Approach* and *Notes* allow keeping the termination ("a valid outcome for part
  (1)").

## R2 - Part (2): where does the close "begin", and can it be driven?

- Decision: the mark is set first in `CMainWindow::WindowProc` `WM_DESTROY`
  (`src/plugins/filecomp/mainwnd.cpp`), on both file views, before `DestroyData` and before the
  worker wait that pumps every message of the thread (`PeekMessageW(PM_REMOVE)` +
  `DispatchMessageW`). The views are children of the main window and still exist then, so a
  pending `WM_USER_HANDLEFILEERROR` reaches `CHexFileViewWindow::WindowProc`; after the main
  window's `WM_DESTROY` returns the children are destroyed and their posted messages are
  dropped by the system - the pump is the only route.
- Rationale: every close route ends in `DestroyWindow(HWindow)` (`CM_EXIT`; `WM_CLOSE` posts
  `CM_EXIT`; the plug-in's `Release` posts `WM_CLOSE`). `CM_EXIT` with the window disabled
  (an open box) first closes the owned boxes and retries - a separate, earlier state, kept.
- Reproduction: not drivable on the hidden desktop. The pump runs only while a comparison
  worker runs at close time (otherwise `WorkerEvent` is signalled and nothing is pumped), and
  the error message must be posted by the hex view's paint in that window; a message posted from
  a probe would carry a pointer of another process in `wParam`. Recorded as NOT DRIVEN; proven
  by code reading and the independent review.
- Alternatives considered: a flag on the main window read by the views through
  `WindowsManager.GetWindowPtr(GetParent(...))` (depends on the parent's registration during its
  destruction - rejected); dropping the message when `DataValid` is FALSE (also hits a recompare
  while the window stays open, which must keep its box, FR-002 - rejected); filtering the pump
  (the pump is shared by every message; a per-message filter in the main window knows the views'
  private message - rejected).

## R3 - `CFileMapping::Destroy` and `FileSize`

- Decision: `FileSize = 0` in `Destroy` after the handles are closed.
- Callers of `Destroy`: the destructor, `SetFile` (sets `FileSize` again right after, unless
  `GetFileInformationByHandle` fails - then 0 is the truthful value), `CHexFileViewWindow::
  DestroyData` (destructor, `WN_BINARY_FILES_DIFFER` before new data, main window `WM_DESTROY`).
  Readers of `GetFileSize` after `DestroyData`: `Paint` (with size 0 it maps nothing; with
  `ViewOffset > 0` `clipLastRow` becomes 0 - nothing mapped), selection / navigation commands
  (guarded by `DataValid`). `MapViewOfFile` already returns NULL for size 0. `CM_CLOSEFILES` ->
  `InvalidateData` repaints with paint already disabled. A recompare whose `SetData` cannot open
  the file repainted with the stale size and posted a second "handle is invalid" box - gone now
  (review of 266, NOTE 5).
- Limit (review of 266, SHOULD-2): `Paint` maps the SIBLING's data by the view's own stored
  `SiblinkSize`, so in `WN_BINARY_FILES_DIFFER` (both views' data destroyed, then `SetData` of the
  left view repaints it) the left view can still ask the released right mapping - a pre-existing
  route of the recompare, not of the close; since 266 the box's reason is whatever
  `GetLastError()` holds. Inbox item `file-comparator-hex-recompare-error-box-from-the-released`.
- `CFileMapping::Release` (forgets handles) has no caller - unchanged (spec *Clarifications*).
