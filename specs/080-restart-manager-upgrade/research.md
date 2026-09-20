# Research — Feature 080 (upgrading over a running instance)

**Date**: 2026-09-20 · **Baseline**: `main` at `e6466db` (0.1.8 / build 192,
unreleased) · Everything marked *measured* was run on the development machine
(Windows 11 Pro 26200, non-elevated shell) with the probes in `probe/`; raw
observations are in `fix-log.md`.

There were no `NEEDS CLARIFICATION` items left by the specification. The
unknowns below are the ones the Technical Context raised.

---

## R1 — Why did the update fail? (spec FR-001)

**Decision**: The failure recorded by feature 072 was caused by the
crash-reporting helper `salmon.exe`, not by the program's handling of the
close request. Feature 079 removed the helper and with it the failure. This
feature does not have to *make the idle program close*; it has to make the
close **unattended-safe**, bring the program **back**, and clean up the
**stale helper file**.

**Evidence** (measured, table B0–B6 in `fix-log.md`):

- Published 0.1.7 installer over a running 0.1.7: **exit 5**. The installer's
  log lists two applications — *Tandem Commander, File Manager* and *Tandem
  Commander Bug Reporter* — and reports *Some applications could not be shut
  down* **20 ms** after *Shutting down applications*. Both processes keep
  their pids: nobody was asked anything.
- `RmGetList` classifies `salmon.exe` as `RmUnknownApp`; it has **no top-level
  window**. `RmShutdown` returns `ERROR_FAIL_SHUTDOWN` (351) after 0.0 s. The
  Restart Manager can only close what has a window, a console handler or a
  service control handler, and it refuses the whole session when one entry is
  none of those.
- The same 0.1.7 main program, registered alone: `RmShutdown` = 0 after 1.2 s.
- HEAD installer over a running **0.1.7**: **exit 0**. The HEAD package does
  not contain `salmon.exe`, so the file is not registered with the Restart
  Manager and the helper never enters the list. It dies with its parent.
- HEAD installer over a running HEAD build: **exit 0**, three times out of
  three, 3.0–3.1 s; the program is not started again.

**Alternatives considered**: none — this is a finding, not a choice. It is
recorded first because it overturns the premise of the backlog item
(*"the program does not end"*) and therefore the shape of the whole feature.

---

## R2 — The Restart Manager's window protocol

**Decision**: Treat the protocol as measured below, not as remembered from
documentation. The design relies on P1, P2, P3 and P6.

| # | Fact (measured with `probe/rm_protocol_dummy.ps1` + `probe/rm_probe.ps1`) |
|---|---|
| P1 | **Every** top-level window of the process receives `WM_QUERYENDSESSION` (wParam 0, lParam `ENDSESSION_CLOSEAPP` = 1), then `WM_ENDSESSION` with the same lParam and wParam = 1 when everybody agreed, 0 when somebody refused. |
| P2 | 1–5 ms after `WM_ENDSESSION`(1) the **main window only** also gets **`WM_CLOSE`**. Other top-level windows of the process do not. After a refusal there is no `WM_CLOSE`. |
| P3 | After `WM_ENDSESSION` the Restart Manager waits **30 s** for the process to end (a late exit after 8 s = success after 8.0 s; never exiting = 351 after 30.0 s). |
| P4 | A window that has not answered the query after **5 s** fails the session (351 after 5.0 s). |
| P5 | A process that exits *inside* the query is accepted (success). |
| P6 | `RegisterApplicationRestart` makes `RmGetList` report `restartable=True`, and `RmRestart` starts the program again with the registered command line **even if it had been running for only three seconds**. The documented 60-second minimum applies to restarts after crashes and hangs, not to the Restart Manager. |
| P7 | *(measured during the review, dummy mode `slow-end`)* A program that stays inside its `WM_ENDSESSION` handler receives the `WM_CLOSE` **5.1 s after the instruction was sent**, while still inside the handler (if it pumps messages); otherwise right after the handler returns. |
| P8 | *(measured during the review, `rm_probe -Force`)* Under `RmForceShutdown` — Setup's `/FORCECLOSEAPPLICATIONS` — a program that **declines** the question still gets `WM_ENDSESSION` with **wParam 1**, lParam `0x1` (no critical flag), then `WM_CLOSE`, and is killed after 30 s. |
| P9 | *(measured during the review)* `RmRestart` starts the program with a **quoted image path** (`"…\tc inst with spaces\tandemcommander.exe" -t "Sp ace" -i 1`), so an installation folder with spaces is safe. With the main window hidden the process is listed as `RmOtherWindow` and is closed and restarted all the same. |

**Consequences**:

- P2 is the trap. The program turns `WM_CLOSE` into its ordinary *interactive*
  exit (`WM_USER_CLOSE_MAINWND`: exit confirmation, every question). Today the
  main window is already destroyed when that `WM_CLOSE` arrives, so nothing
  happens. As soon as the close moves out of the query stage, the
  `WM_CLOSE` that follows an agreed request must be swallowed — otherwise an
  unattended close that had to be abandoned is immediately followed by an
  interactive one.
- P4 gives the budget for the answer (FR-007: 5 s); P3 the budget for the
  close itself (FR-003: target 10 s, limit 30 s).

**Alternatives considered**: relying on the documentation alone. Rejected —
the documentation does not mention the `WM_CLOSE`, and gets the restart age
rule wrong for this use.

---

## R3 — What the program does with the request today

**Decision**: The present behaviour is wrong in three ways and each gets its
own remedy (R4–R6).

**Evidence** — code, `src/mainwnd3.cpp`, one handler for `WM_ENDSESSION`,
`WM_QUERYENDSESSION`, `WM_USER_CLOSE_MAINWND`, `WM_USER_FORCECLOSE_MAINWND`:

- `ENDSESSION_CLOSEAPP` is never looked at. The request runs the path of an
  ordinary, non-critical sign-out: the **complete interactive exit inside the
  query** — *Exiting* dialog while file operations run, Find windows asked,
  viewers closed, all plug-ins unloaded (each may ask), both panels' paths
  closed (archives and plug-in file systems may ask), configuration saved,
  `DestroyWindow` — and only then `return TRUE`.
- A comment at the end states the premise: *"all Windows versions kill the
  process as soon as the main window is destroyed during shutdown"*. Not so
  for an installer's request; the process ends only because `WM_DESTROY`
  posts the quit message.
- `WM_ENDSESSION` without the critical flag would show the *forced shutdown*
  message box (`IDS_FORCEDSHUTDOWN`). It is unreachable today only because the
  window no longer exists by then.

**Evidence** — measured with the HEAD Release build (`probe/tc_drive.ps1`):

| State | Result of `RmShutdown` |
|---|---|
| modal dialog open | 351 after 0.0 s, nothing shown — already correct |
| copy in progress | 351 after **5.0 s**; ***Exiting Tandem Commander*** stays on screen, main window disabled; when the copy ended **the program exited by itself** |
| Code Viewer window open (F3 on a text file — the default viewer, the everyday state) | 351 after **5.0 s**; the plug-in's question *"viewer windows are open"* and the *saving configuration* window stay on screen; answered *Yes* minutes later, **the program exits** |

---

## R4 — Where the close happens: question stage or instruction stage (spec FR-009)

**Decision**: Decide in `WM_QUERYENDSESSION`, act in `WM_ENDSESSION`.

- **Query stage**: a side-effect-free evaluation of *"can this instance close
  right now without asking anybody anything?"* (R5). Answer TRUE or FALSE
  within milliseconds. Nothing is closed, stopped, saved or shown.
- **Instruction stage**, wParam = 0: somebody else refused — forget the
  request, nothing to undo.
- **Instruction stage**, wParam = 1: repeat the evaluation (the state may have
  changed in between), then run the **existing exit sequence** with the
  *unattended* rule (R6), synchronously inside the handler.

**Rationale**:

- It is what the protocol asks for, and it removes the scenario the present
  behaviour cannot handle: two instances, one busy — today the idle one closes
  at the query and the update then fails anyway (spec, Edge Cases).
- **Synchronously, not posted.** Posting a private message and returning from
  `WM_ENDSESSION` would be the smaller code change, and for a real installer
  it works (P3: 30 s). But `ENDSESSION_CLOSEAPP` is also set when Windows
  itself closes programs *for servicing* — a restart for updates — and there
  the process may be ended as soon as `WM_ENDSESSION` returns. A posted close
  could then be cut off in the middle of saving the configuration. Done
  synchronously, the work happens under exactly the conditions under which the
  present code already does it (inside a sent session message, pumping
  messages, registry work on the worker thread, `SAVE_IN_PROGRESS` marking a
  half-written configuration).
- **Re-dispatch, not a second implementation.** The 600-line handler tests
  `uMsg == WM_QUERYENDSESSION` in some 25 places to mean *"session request:
  pump messages, show the wait window, use the registry worker thread"*, and
  `uMsg == WM_ENDSESSION` to mean *"continuation of a critical shutdown"*.
  The instruction stage therefore re-enters the handler as
  `WM_QUERYENDSESSION`, marked as the *execute stage* by a flag the program
  sets around that call (nothing sent from outside can select it), so every
  existing test keeps its meaning and the diff in the big handler stays
  small: one block at the top and one line at each prompt site.

**Scope guard** (spec FR-013): the new behaviour applies only when
`ENDSESSION_CLOSEAPP` is set, `ENDSESSION_CRITICAL` is **not** set, and
`GetSystemMetrics(SM_SHUTTINGDOWN)` is 0. Everything else — sign-out,
shutdown, critical shutdown, a servicing restart — takes the existing path,
untouched. `SM_SHUTTINGDOWN` cannot be exercised in an autonomous session (it
needs a real sign-out); the design does not depend on it for safety: if it
were ever 0 during a real shutdown, the request would be handled as an
unattended close, which is synchronous and never half-saves (see above).

**Alternatives considered**:

| Alternative | Why rejected |
|---|---|
| Keep closing at the query stage, only add the unattended rule and the restart (FR-009's escape clause) | Smallest change and proven to satisfy the Restart Manager (P5), but keeps the two-instance defect, and the specification only allows it if acting at the query were the *only* reliable way — the measurements show it is not. |
| Post a private message from `WM_ENDSESSION`, run the ordinary `WM_USER_CLOSE_MAINWND` path from the message loop | Cleanest context, but unsafe under a servicing shutdown (above). |
| A new message constant handled as its own `case` | Every `uMsg == WM_QUERYENDSESSION` test in the handler would need a twin; large diff in the most delicate function of the program. |

---

## R5 — Which states decline (spec FR-006)

**Decision**: One pure decision function, evaluated at both stages. It
declines — with a named reason that goes to the trace — when any of these is
true, checked in this order:

| # | State | How it is detected (all read-only) | Reason for declining |
|---|---|---|---|
| D1 | start-up not finished, or a close is already under way | `!CanClose` (unless only `CanCloseButInEndSuspendMode`), `CannotCloseSalMainWnd`, main window closed flag | nothing to close safely yet / no nested close |
| D2 | the main thread is inside something — a modal dialog, a menu, a command | `SalamanderBusy`, main window disabled | the present code already declines here; a modal dialog is the user in the middle of something |
| D3 | the main thread is inside a plug-in call | `AlreadyInPlugin > 0` | the plug-in cannot be unloaded from under itself |
| D4 | file operations running | `ProgressDlgArray.RemoveFinishedDlgs() > 0` | work in progress; today: *Exiting* dialog, timeout, surprise exit (measured) |
| D5 | a Find window is searching, or is itself busy | `CFindDialog::IsSearchInProgress()` for every window of `FindDialogQueue`, under `WindowsManager.CS` | a manual exit would ask *stop searching?* |
| D6 | files opened from an archive are waiting to be packed back | `AssocUsed` of either panel | a manual exit asks which files to update — a user decision |
| D7 | a panel shows a plug-in file system, or detached file systems exist | `Is(ptPluginFS)` of either panel, `DetachedFSList->Count > 0` | a live connection; the plug-in's own *disconnect?* dialog cannot be suppressed from the core |
| D8 | the process has a visible top-level window the core cannot account for | enumerate the process's top-level windows; ignore the main window, internal viewer windows (class `CVIEWERWINDOW_CLASSNAME`), Find windows (`FindDialogQueue`), and windows that are not real windows (no caption **and** tool-window / no-activate style: tooltips, save-bits, IME) | it belongs to a plug-in — a viewer, a transfer, a comparison — and unloading that plug-in makes it **ask** (measured with Code Viewer); see below |

States that **close silently**, deliberately: internal viewer windows (no
state to lose; closed by the existing broadcast), idle Find windows, a panel
inside an archive with nothing edited, the *Confirm on program exit* option
(it guards against an accidental key press, which this is not).

**D8 is the uncomfortable one.** A plug-in viewer holds nothing that could be
lost, and an open viewer is the everyday state. Surveying the 20 shipped
plug-ins' `Release(parent, force)`: Code Viewer, Markdown Viewer, PictView and
Database Viewer **ask** *"viewer windows are open, close them?"* when
`force` is FALSE (the last one with a raw `MessageBox` the core cannot even
see); checksum, File Comparator, Registry Editor and Renamer close their
windows without asking; FTP asks only when transfers exist. The ways to close
viewer windows without asking, and why none is taken:

| Way | Why not |
|---|---|
| `Release(parent, force = TRUE)` | for viewers exactly right, but the core cannot tell which plug-in is "only a viewer", and for FTP/SFTP `force` cancels transfers — data loss |
| answer the plug-in's question for it inside the core's `SalMessageBox` service | the same *Yes* that closes viewer windows cancels FTP transfers; *No* is the only generally safe answer and it gets nowhere |
| post `WM_CLOSE` to every foreign window (P2 shows the Restart Manager does not) | equals clicking every close button: a transfer window would raise *its* question on the unattended machine — the defect being removed — and may pause the transfer while it waits |
| tell plug-ins the close is unattended (a new plug-in event) | the right solution; an addition to the plug-in interface, excluded by FR-014. **Follow-up work.** |

So an open plug-in window declines — promptly, leaving nothing on the screen
and no time bomb — and the changelog and the manual say so.

**Rationale for a pure function**: the decision is the heart of the feature
and must be testable without a GUI. The function takes a plain snapshot
(flags, counts, a list of window descriptors) and returns a decision plus a
reason; the collector that fills the snapshot lives in the core. The function
and its tests live in `src/common/` under `saltests`, the pattern of
`saltabs` (078) and `salbugreport` (079).

**Alternatives considered**: deciding by *trying* (run the exit and abort at
the first prompt) — rejected: the abort points of the existing sequence lie
after Find windows and viewers are closed and plug-ins unloaded, so a late
abort does not leave the program "exactly as it was" (FR-006), and a late
abort cannot be reported to the requester any more.

---

## R6 — The unattended rule inside the exit sequence (spec FR-005)

**Decision**: a process-wide flag, `UnattendedClose`, TRUE only while the
execute stage runs. R5 makes prompts unreachable in practice; the flag is the
second line of defence for the states R5 cannot see in advance and for the
few milliseconds between the two stages. Every place **on the exit path in
the core** that would show something takes its **negative** branch instead,
without showing anything:

| Site | Normal exit | Unattended |
|---|---|---|
| exit confirmation (`CnfrmOnSalClose`) | asks | not reached (only for `WM_USER_CLOSE_MAINWND`) |
| file operations running — `CExitingOpenSal` | waits in a dialog | abandon the close |
| Find close query `WM_USER_QUERYCLOSEFIND` | asks *stop searching?* | sent as *quiet*; R5-D5 guarantees nothing is searching |
| `IDS_PLUGINFORCEUNLOAD` (plug-in refuses to unload) | asks *force?* | No → abandon |
| `IDS_SHELLEXTBREAK3` (shell extension locked the window) | Continue / Abort(bug report) | Continue → abandon |
| `IDS_ARCHIVECLOSEEDIT` + pack-back dialog | informs, asks | not reached (D6); guarded: abandon before either |
| `IDS_ARCHIVEFORCECLOSE`, `IDS_FSFORCECLOSE` (panel, detached FS) | asks *force?* | No → abandon |
| `LockedUIReason` message box when busy | shows | not shown |

*Abandon* means the existing refusal exits of the handler (`return 0`,
`EXIT_WM_USER_CLOSE_MAINWND`) — the program keeps running. After an abandoned
execute stage the Restart Manager times out after 30 s (P3) and the installer
fails as it does today; this can only happen in the race window or when a
plug-in refuses for a reason of its own.

**Swallowing the `WM_CLOSE`** (P2): when the execute stage starts, the
program notes the time; the **first** `WM_CLOSE` to the main window within the
following 35 s (the Restart Manager's 30 s plus margin) is ignored. One
message, one time window — a person pressing Alt+F4 afterwards is served
normally.

**Not touched**: `CriticalShutdown`. It means *"no time, force everything,
lose what must be lost"* and is visible to plug-ins through
`IsCriticalShutdown()`; setting it for an update would make FTP drop transfers
and the archive code skip packing edited files back. The unattended close is
the opposite policy: lose nothing, decline instead.

**Alternatives considered**: a generic auto-answer inside `SalMessageBoxEx`
keyed on the button set — rejected: the safe answer is not a function of the
buttons (*Continue/Abort* above), and a silent generic rule in the message box
would be invisible at the call sites it changes.

---

## R7 — Coming back after the update (spec FR-010–FR-012)

**Decision**: call `RegisterApplicationRestart` once per process, when
start-up is complete (where `CanClose` becomes TRUE), with

- flags `RESTART_NO_CRASH | RESTART_NO_HANG | RESTART_NO_REBOOT` — the update
  case only (FR-011). The crash handler ends the process itself with its own
  report; a restart on top of that would be new behaviour nobody asked for.
  `RESTART_NO_REBOOT` keeps the program out of *"restart apps after signing
  in"*: not verifiable here, unrelated to updates, a separate decision.
- a command line that carries **identity, not location**: `-t <prefix>` and
  `-i <index>` when the instance was started with them (people run several
  differently titled and coloured instances from shortcuts), nothing else.
  `-l`, `-r`, `-a`, `-p` would put the panels back where the instance
  *started*, not where it *was*; `-c` only matters on a machine without a
  configuration; `-o` would make the second of two restarted instances hand
  over to the first and vanish.

State travels through the stored configuration, as decided in the
specification. Measured (P6): the Restart Manager restarts a three-second-old
process, so an update right after a start works too.

The command line is composed by a pure function (the tokenizer's quoting rule:
an argument in double quotes, a literal quote doubled) — tested in `saltests`
together with the decision function. `RegisterApplicationRestart` is declared
for `_WIN32_WINNT >= 0x0600`; the product builds with `0x0601`. The limit is
`RESTART_MAX_CMD_LINE` = 1024 characters; a title prefix is at most
`TITLE_PREFIX_MAX`.

**Who decides**: the installer. Inno Setup restarts what it closed unless run
with `/NORESTARTAPPLICATIONS` (FR-012). Whether it also restarts after a
*failed* installation is measured in the implementation phase (quickstart V7).

**Owed to a person**: an **elevated** installer (machine-wide installation)
restarting a non-elevated program — expected to come back non-elevated, not
verifiable without answering an elevation prompt.

**Alternatives considered**: `RegisterApplicationRecoveryCallback` (state
recovery after crashes — out of scope); passing the panels' paths on the
command line (rejected in the specification: cannot carry tabs, duplicates the
configuration, 1024-character limit); a configuration option (rejected in the
specification: the installer's switch is the control).

---

## R8 — The stale helper file (spec FR-021, FR-022)

**Decision**: remove `{app}\utils\salmon.exe` from the installer's `[Code]`
section in `CurStepChanged(ssPostInstall)`, with a short retry, logging the
outcome; **not** with `[InstallDelete]`.

**Evidence** (measured, B6): the installer script plus
`[InstallDelete] Type: files; Name: "{app}\utils\salmon.exe"`, run over a
running 0.1.7: **exit 5** — *Found 12 files to register with RestartManager*
(11 without the entry), the helper is listed again, *Some applications could
not be shut down* after 20 ms. `[InstallDelete]` entries are registered with
the Restart Manager exactly like `[Files]`.

At `ssPostInstall` the old program has been closed by the Restart Manager and
the helper — which watches its parent — has ended with it (B4: nothing runs
from the folder after the upgrade). A retry of a few seconds covers a helper
that is slow to die; a file that still cannot be deleted is logged and left
(FR-022) — the uninstaller removes it later in any case, because the
uninstall log is cumulative (measured).

`CloseApplicationsFilter` is left at its default. Only this one file is
removed: it is the only file a release ever shipped and a later one dropped
inside a folder that still exists (the 079 removal). `utils\` keeps
`sqlite.dll`.

**Alternatives considered**: `[InstallDelete]` (refuted above);
`[InstallDelete]` plus a narrowed `CloseApplicationsFilter` (the filter is a
file-mask list applied to *all* registered files — excluding `*.exe` would
also stop the installer from closing the main program); leaving the file
(defeats feature 079 for every upgrader).

---

## R9 — How to verify without disturbing the machine (spec FR-018)

**Decision**:

- **Installers** are compiled with `ISCC /O<scratch> /F<name>` so nothing is
  written to `setup\output\`; the three archived installers' hashes are
  recorded before and compared after.
- **Installations** are per-user into the scratchpad
  (`/CURRENTUSER /DIR=<scratch>\tc-inst /NOICONS`), no elevation; the
  machine-wide 0.1.7 in `C:\Program Files` is never touched (its `HKLM`
  uninstall key and executable timestamp are checked at the end). The scratch
  installation's `HKCU` uninstall key is removed by its uninstaller.
- **The configuration** is one per user by design, so every test instance
  shares it. The whole `HKCU\Software\Tandem Commander` key was exported
  before the first run (two copies, hash recorded) and is restored — delete
  key, import — at the end, then re-exported and compared.
- **Driving the program**: only by posting messages to windows of the pid the
  driver itself started (`probe/tc_drive.ps1`); no synthetic keyboard input,
  no foreground changes. The probes refuse to act on any process that does
  not run from the location they were given.
- **The close itself**: `probe/rm_probe.ps1` performs the installer's exact
  Restart Manager sequence, so most scenarios need no installer; the real
  installer (`probe/upgrade_probe.ps1`) is the end-to-end gate.

**Not verifiable autonomously** (owed human steps, listed in `quickstart.md`):
the elevated machine-wide installation, a real `winget upgrade` (needs the
package in the catalogue and a newer published version), a real sign-out /
shutdown / critical shutdown before-and-after comparison (FR-013 is covered
by code review of an untouched path plus the scope guard of R4), and the
interactive installer's *Preparing to Install* page.
