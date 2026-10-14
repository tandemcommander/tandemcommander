# Fix log: 143 - Disk Map closes safely while one of its loops is open

Backlog: `specs/NEXT-WORK.md`, *Open items at a glance* A.1 (queue 104 entry 6; 118 R7).

## Before (measured 2026-10-14, `probe/result_pre143.txt`, build `Debug_x64_pre143` = `8e5d6c8a`)

Probe `probe/release_guard_probe.ps1 -Expect before`: PASS 19, FAIL 4.

- E1 (normal exit, file context menu open): **crash** - access violation, read on
  0xFFFFFFFFFFFFFFFF, `WindowThreadBody`; the bug-report box; the process hangs.
- E4 (normal exit, the shell's "permanently delete?" of Delete from the map's menu): **crash**.
- U1 (installer's close, menu open): **agreed** (a popup menu is no undeclared window), then the
  same crash; Restart Manager failed after 40 s.
- E0, E2 (About), E3 (Esc confirmation): clean exit; U2-U4: declined.
- The shell's confirmation runs on the map's thread (same thread id) - inside `InvokeCommand`.

So 118's record ("milliseconds in an unattended close") understated it: the menu row is fully
reachable for an installer, and a normal exit crashes from a menu or a shell command.

## Work

- `src/common/salloopclose.h` (new, header-only): `CSalLoopCloseState` with three counters
  (menu, own box, shell command) and `ClosePending`; `SalLoopEnter` (reports the first loop),
  `SalLoopLeave` (reports the last one: close now once, or declare again),
  `SalLoopCloseRequest` (no loop: close now; else pending + end the menu + cancel own boxes when
  no shell command runs). `saltests` `TestLoopClose143`: 27 checks.
- `GUI.LoopGuard.h` (new): `CMapLoopOwner` + RAII `CMapLoopScope`.
- `GUI.ShellMenu.h`: menu scope around both `TrackPopupMenuEx`, shell scope around the three
  `InvokeCommand` (`ShowFileMenu`, `ShowDirMenu`, `InvokeDefaultCommand`).
- `GUI.MainWindow.h/.cpp`: `WM_CLOSE` first in `WndProc` (before the shell menu's
  `HandleMenuMessage`, which is handed every message while a menu is open); `OnClose` -
  `EndMenu`, `IDCANCEL` posted to the thread's enabled `#32770` dialogs owned by the map; the
  About command and the Esc confirmation in own-box scopes; `LoopLeave` posts `WM_CLOSE` when a
  close was pending.
- `DiskMapPlugin.cpp`: `DiskMapLoopsOpen`; `DiskMapLoopStateChanged` withdraws the 107
  declaration on the first loop and gives it back on the last one (not while a close is
  pending); `Release` refuses an unattended close while the counter is above 0.
- The probe got row E5 (the person forces the unload before answering the shell): measured on
  the first run of the fixed build, E4 had answered the force question first - the forced
  unload terminates the map's thread inside the shell (`KillAll(TRUE)`, every release) and the
  Debug build shows its leak reports (monitored handles, CRT), recorded as a Debug note there.

## Review (refute-first agent, 2026-10-14)

No critical finding; the measured paths confirmed closed. Fixed:

- MEDIUM: File > Exit and Esc called `Destroy()` directly - inside a shell command whose loop
  leaves the map enabled the same use-after-free. Both go through `CloseOrDefer`.
- LOW: after "force? No" the pending close still fired when the shell command returned (the map
  closed by itself). `SalLoopCloseAbandon` + `WM_APP_CLOSEABANDONED`, posted by `Release` when
  `KillAll` gives up.
- LOW: the scopes were narrower than the code using the window's objects (shell extensions may
  pump messages in `GetUIObjectOfFile`, `QueryContextMenu`, `Release` - an STA call). One shell
  scope over the whole of `ShowFileMenu` / `ShowDirMenu` / `InvokeDefaultCommand`.
- LOW (probe): a force question in a non-shell row now fails the row; rows E6, M1-M3 added.
- NITs: clang-format; the BOM the edit had added to `saltests.cpp` removed.

Second round (the same reviewer on the fixes): all five correct; one new LOW fixed - the abandon
also dropped a close the PERSON asked for during the same shell command (`ClosePending` did not
record who asked). Now two flags (`ClosePendingRelease`, `ClosePendingOther`); `Release` posts
`WM_CLOSE` with `wParam` = `DISKMAP_CLOSE_FROM_RELEASE`; the abandon clears only Release's
(saltests +4). Recorded, not driven (no tool on the hidden desktop makes them happen):
- the route `CloseOrDefer` exists for - File > Exit / Esc while a shell command keeps pumping with
  the map enabled (needs such a shell extension); code review only;
- E6 shows the map stays after "force? No", but its control crashes earlier - a control with the
  abandon message disabled was not built; M1-M3 are regression rows (they pass on the control).

## After

- Debug build clean; `saltests` 21,794 -> 21,829, 0 failed; `check_encoding.py` TOTAL 0.
- `probe/result.txt` (`Debug_x64` with the review fixes, `-Expect fixed`): **PASS 34, FAIL 0** -
  E1 (menu) and E2/E3 exit in 1.2-1.4 s without the core's force question, E4 (shell
  confirmation answered, then the force question) in 5.0 s with the file kept, E5 (force
  first) in 5.2 s without a crash, E6 (force No): the program and the map stay; M1-M3 (File >
  Exit, Esc Yes / No) as before; U1-U4 decline in 0.0 s.
- `probe/result_pre143.txt` (control, same probe): PASS 27, FAIL 7 - E1, E4, E5, E6, U1:
  access violation; M1-M3 pass there too (unchanged behaviour).
- `probe/result_118_regress.txt` (118 probe `-Only M1,M2,M3,M4,X1`): PASS 11, FAIL 0 - as in 118.
