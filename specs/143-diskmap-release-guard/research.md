# Research: Disk Map closes safely while one of its loops is open

All rows measured with `probe/release_guard_probe.ps1` on the hidden desktop, build
`Debug_x64_pre143` (= the prepared 0.1.10 tree, commit `8e5d6c8a`), result
`probe/result_pre143.txt`.

## R1 - Is the defect reachable? (measured: yes, worse than recorded)

| Row | State of the map when the close comes | 0.1.10 build |
|---|---|---|
| E0 | finished, nothing open | clean exit (0x0, 1.4 s) |
| E1 | file context menu open, normal exit | **crash**: access violation, read on 0xFFFFFFFFFFFFFFFF in `WindowThreadBody`; bug report written; the process hangs behind the crash box |
| E2 | About box open, normal exit | clean exit |
| E3 | Esc close confirmation open, normal exit | clean exit |
| E4 | the shell's "permanently delete this file?" (Delete from the menu, file on `\\localhost\C$`), normal exit | **crash** (same) |
| U1 | file context menu open, installer's close | **not declined** - the core counts no undeclared window (a popup menu is not one), agrees, `Release` posts `WM_CLOSE`, **crash**; Restart Manager fails after 40 s |
| U2-U4 | About / confirmation / shell confirmation, installer | declined in 0.0 s (undeclared top-level windows) |

- Mechanism (code reading, consistent with the crash): `CPluginInterface::Release` posts
  `WM_CLOSE` to every map; a modal or menu loop on the map's thread dispatches it; the map's
  `WndProc` has no `WM_CLOSE` case, `DefWindowProc` destroys the window; `OnDestroy` deletes
  `CShellMenu`, `CDiskMapView`, `CDirectoryLine` while `CShellMenu::ShowFileMenu` (and its caller
  `CDiskMapView::OnContextMenu`) are still on the stack; when the loop returns,
  `this->_pcm2` / `this->_pcm` are read from freed memory (debug fill -> the address above).
- The shell's confirmation of Delete runs **on the map's thread**, inside
  `IContextMenu::InvokeCommand` (thread ids equal in E4 and U4) - a shell command is a loop of
  the map, as assumed.
- E2/E3 survive by luck: the About box and the confirmation return into `OnCommand` / `OnKey`,
  which touch nothing after the box (the window is gone, `this` of `CMainWindow` still lives -
  it is deleted after the message loop).
- 118's record "a window of milliseconds in an unattended close" is wrong for the menu: an open
  context menu does not decline at all (U1).
- In practice a menu closes when its window loses activation; an installer started by the user
  activates another window. On a busy machine (an update started by a package manager in the
  background, sign-out) or with a shell command open, the crash is reachable as measured.

## R2 - Where does the close request come from, and what does the core do with `FALSE`?

- Normal exit / plug-in unload: `CPluginData::Unload` / `Remove` (`src/plugins1.cpp`) call
  `Release(parent, FALSE)`; on `FALSE` the core asks `IDS_PLUGINFORCEUNLOAD` ("%s plugin has
  rejected to unload. Do you want to force it to unload?") and on Yes calls `Release(parent,
  TRUE)`. Disk Map's `Release` waits `KillAll(FALSE)` = 1 s.
- Critical shutdown: `Release(parent, TRUE)` directly (`KillAll(TRUE)`: 1 s, then terminate).
- Unattended close (080): `FALSE` -> no question, the close is abandoned (`UnattendedClose`).
- **Decision**: unchanged waits and answers (FR-007). A close that has to wait for a shell
  command meets the existing question after 1 s - the person answers the shell's window and
  the core's question; nothing new is shown.

## R3 - What ends which loop?

- Menu: `EndMenu()` on the menu's thread (the `WM_CLOSE` handler runs there) - `TrackPopupMenuEx`
  returns 0, no command runs. **Decision**: end it.
- The map's own boxes (About = the core's `SalMessageBox` via `PluginInterface.About`, the close
  confirmation = `SalMessageBoxEx` with `MSGBOXEX_ESCAPEENABLED`): ended by `WM_COMMAND IDCANCEL`
  to every enabled dialog of the thread owned by the map (only while no shell command is open, so
  a shell window is never among them). To be measured on the build (E2/E3 must end within the
  1 s of `KillAll`). **Decision**: cancel them - the confirmation's question is answered by the
  request itself; a box left open would turn a clean exit (today, by luck) into the core's
  "rejected to unload" question.
- Shell command: not ended (FR-004) - it may be half-way through a file operation.
- Alternatives rejected: (a) `Release` refusing on a normal exit whenever a map is in a loop -
  the core would ask "force?" for an open About box; (b) destroying the window from the loop but
  making `CShellMenu` survive (reference counting) - the shell command would still run on a
  window that is gone; (c) `TerminateThread` - never in a normal close.

## R4 - The declaration during a loop (FR-005)

`SetWindowClosesUnattended(hWnd, FALSE)` withdraws (spl_gen.h, interface 107, "can be called from
any thread"). Withdrawn when the thread enters its first loop, declared again when it leaves the
last one without a pending close; only in a 107 core (`DISKMAP_UNATTENDED_CLOSE_VER`, 118 FR-009).
With the declaration withdrawn the core declines U1 at its question like U2-U4.

## R5 - The guard in `Release` (FR-006)

A process-wide counter of map threads inside a loop (`InterlockedIncrement` on a thread's first
loop, decrement on its last) - the File Comparator's `CompareDialogsOpen` pattern. Read in
`Release` before anything is posted: unattended and > 0 -> `return FALSE`. A loop opened after
that check: the close request is deferred (R3) and `KillAll(FALSE, 5000)` decides as in 118.

## R6 - State per window

Each map has its own thread and exactly one main window; the state lives with the window
(`CMainWindow`) and is reached from `CShellMenu` through the window handle it already has
(`GetWindowLongPtr(GWLP_USERDATA)` gives the `CWindow`; a `thread_local` pointer would work too
but hides the owner). **Decision**: `CShellMenu` gets a pointer to the window's loop state when
the window creates it (it is created in `CMainWindow::OnCreate`).

## R7 - Found on the way, not fixed

- E2/E3's boxes on the build before vanish with the map (destroyed as owned windows) - harmless.
- `IDS_PLUGINFORCEUNLOAD` + Yes during a shell command terminates the map's thread inside the
  shell (`KillAll(TRUE)`) - the existing force semantics, the person's choice; recorded.
