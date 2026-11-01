# Fix log - 375-idle-clipboard-check

Backlog item `every-activation-of-the-program-blocks-it-150-ms-in-the-idle`. Run started at
`main` `e1b1e2c9` (2026-11-01).

## Measurements before the change (HEAD `e1b1e2c9`, Debug x64)

### Feature 372's probe, row LOCAL, unchanged

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <tmp>\local_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\372-wsl-activation-freeze\probe\act372_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before375 -Only LOCAL"
```

PASS, longest 3.1 ms, **no wait > 16 ms** on any of 5 activations. The 140 ms block that 372
recorded on the same row (15+140..142 ms, `specs/372-.../probe/result_after2.txt`) did not occur.
No code on the path changed since (`git log 50c47081..HEAD -- src/mainwnd1.cpp src/mainwnd3.cpp
src/fileswn9.cpp src/salamdr1.cpp`: nothing). So the block depends on the machine's state.

### Clipboard primitives (`probe/clip_primitives.ps1`, read-only)

OpenClipboard / GetClipboardData(CF_TEXT) / CloseClipboard, the `IsTextOnClipboard` loop as
written, `IsClipboardFormatAvailable`, `OleGetClipboard` + `EnumFormatEtc`; the clipboard held
text owned by Chrome:

- user's desktop and hidden desktop (`probe/primitives_free_hidden.txt`): every query <= 1.1 ms
  (first call), then <= 0.1 ms. The hidden desktop is **not** slower (the item's note).
- another process holding the clipboard open (`probe/clip_hold.ps1`: `OpenClipboard` with a hidden
  form window, content unchanged) (`probe/primitives_held.txt`): `OpenClipboard` fails with
  error 5 (ERROR_ACCESS_DENIED) at once; `OleGetClipboard` fails at once with `0x800401D0`
  (CLIPBRD_E_CANT_OPEN, 0.6 ms); the `IsTextOnClipboard` loop (10 x `Sleep(10)`, each ~15.5 ms at
  the default timer resolution) **155-165 ms** - the 153.9 / 154.2 ms of 372's instrumentation.
  (A holder that opens with a NULL window did not block other openers on this Windows build - the
  helper uses a window.)

### New probe `probe/act375_probe.ps1` (`probe/result_before.txt`)

Row LOCAL of act372 (800-file local folder, WM_ACTIVATEAPP FALSE/TRUE, WM_NULL pings every 2 ms),
twice: FREE (clipboard as it is) and HELD (the helper holds the clipboard open for the row).

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <...>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <...>\act375_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib <...>\fix_probe_lib.ps1"
```

| Row | Waits per activation | Longest | Verdict (< 30 ms) |
|---|---|---|---|
| FREE | none > 16 ms | 0.4-2.3 ms | PASS |
| HELD | 15+142, 15+142, 15+142, 15+140, 15+141 | 142 ms | FAIL |

Registry restored, identical SHA-256. HELD reproduces 372's signature exactly: the block happens
whenever another program keeps the clipboard open at the activation (at 372's time some program
did so on this machine for hours). Probe trap met: a local `$holder` variable in a function
shadowed the script parameter `$Holder` (PowerShell names are case-insensitive) - the parameter is
now `$HoldScript`.

### Where the wait is

`CMainWindow_RefreshCommandStates` (`src/mainwnd1.cpp`), block `if (IdleCheckClipboard)`:
`ClipboardPaste(FALSE, TRUE)` (OleGetClipboard - fails fast), `IsTextOnClipboard()` (the retry
loop - **the wait**), `ClipboardPasteLinks(TRUE)` (= ClipboardPaste, fast), 
`ClipboardPasteToArcOrFS(TRUE, ...)` (OleGetClipboard - fast). Result when busy today: every value
FALSE after the 150 ms (ClipboardPaste also clears the panels' cut-to-clipboard marks because no
files were seen - existing behaviour, unchanged, out of scope).

Consumers (stop-rules §2.2): `IsTextOnClipboard` is called by `CMainWindow_RefreshCommandStates`
(idle, the activation path) and by `CFilesWindow::RestoreGlobalSelection` (`fileswn1.cpp`, the
user's *Restore Selection* command opening a dialog) - the latter keeps its retry.
`IdleCheckClipboard = TRUE` is set by 19 sites (activation, dialogs closing, paste operations,
...); no clipboard change listener exists (`grep WM_CLIPBOARDUPDATE|WM_DRAWCLIPBOARD`: none).
`WM_USER_ENTERMENULOOP` calls `OnEnterIdle` so menus show fresh enablers.

## speckit-analyze

- Pass 1: 0 CRITICAL, 0 HIGH. LOW C1 (FR-004 has no dedicated task - the success path of the
  query is unchanged; the review checks it) and LOW C2 (SC-004 is a person step) accepted.

## Implementation

- `src/common/salclipcheck.h` (new): `SalClipCheckNextLook(busy, wasRetry, &retries)` - the delay of
  the next look (500 ms, at most 10 in a series; a free clipboard or a non-retry check resets).
- `src/fileswn9.cpp` / `fileswnd.h`: `IsTextOnClipboard(BOOL noWait = FALSE, BOOL* busy = NULL)` -
  with `noWait` a failed `OpenClipboard` ends the loop at once (FALSE, `*busy = TRUE`); without it
  (default, `RestoreGlobalSelection`) the 10 x `Sleep(10)` retry is unchanged.
- `src/mainwnd1.cpp` (`CMainWindow_RefreshCommandStates`): the text query in the no-wait form; then
  the rule decides; `SetTimer(main, IDT_CLIPCHECKRETRY, 500)` or `KillTimer` of a pending one.
  The other three queries and every result are unchanged (a busy clipboard gives FALSE for all,
  as today after the wait).
- `src/mainwnd3.cpp`: `WM_TIMER` `IDT_CLIPCHECKRETRY` -> kill, mark retry, request the check
  (`IdleRefreshStates`, `IdleCheckClipboard`); `WM_USER_ENTERMENULOOP` with a look pending ->
  request the check before its `OnEnterIdle` (the menu shows the current clipboard).
- `src/consts.h`, `src/salamdr1.cpp`: `IDT_CLIPCHECKRETRY` (956, unused before) and the three
  globals of the series.
- No UI string, menu or dialog changed: no `.slt` refresh (stop-rules §2.13 does not apply).

## Checks

| Check | Command | Result |
|---|---|---|
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| build | `.\build.cmd` (Debug x64) | `BUILD SUCCEEDED` (3 warnings, all in untouched lines of `salamdr2.cpp` / `zip.cpp`) |
| unit rules | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 30237 checks, 0 failed` (`TestClipCheck375`) |
| probe | `act375_probe.ps1 -Label after` on the hidden desktop | PASS 4, FAIL 0 (`probe/result_after.txt`) |

### Probe after the change (`probe/result_after.txt`)

| Row | Before (`result_before.txt`) | After |
|---|---|---|
| FREE | longest 0.4-2.3 ms | 0.3-2.2 ms |
| HELD | 15+140..142 ms on 5 of 5 activations (FAIL) | 0.4-1.5 ms, no wait > 16 ms (PASS) |

Registry restored, identical SHA-256. Negative control: the same probe on the build of `main`
(`result_before.txt`) fails HELD - the row detects the defect.

NOT DRIVEN: the enabled state of the paste commands (the program's own menus and toolbars cannot
be read on the hidden desktop) - the later looks are covered by `TestClipCheck375` and owed to a
person on a real desktop (T012 -> person-step item at closing).

## Review

### Review 1 (independent agent, refute-first) - no MUST

Re-ran build, saltests (30237 / 0), encoding guard (0) and the probe on the branch build (FREE
2.3 ms, HELD 2.9 ms, PASS 4); negative control = `e1b1e2c9` built in a worktree: HELD 15+141,
16+142, 16+141, 16+141, 15+141 ms (FAIL) - the probe detects the defect. It also proved the later
looks, which neither saltests nor the probe show: a cdb breakpoint on `IsTextOnClipboard` counted
11 checks 500 ms apart after one activation with the clipboard busy for 7 s (pre-fix: 1), the
series restarting on a menu-loop message, and 0 checks in 3 s with nothing pending.

- SHOULD 1: FR-003 held only for the main menu - the archive item / archive panel context menus
  (`shellsup.cpp`, `OnEnterIdle` + `UpdateItemsState` before `Track`) and the disk panel background
  menu (reads `EnablerPaste*` before `Track`) read the enablers before `WM_USER_ENTERMENULOOP`.
  -> **fixed**: `RequestIdleClipCheckIfBusy()` (`mainwnd1.cpp`) requests the check when the last
  check found the clipboard busy; called in `WM_USER_ENTERMENULOOP` and before the two archive
  menus' `OnEnterIdle`; the disk background menu calls it and then `RefreshCommandStates()` before
  its Paste items. FR-003 and the contract updated.
- NOTE 4 (menus stale after an exhausted series): **fixed** by the same helper - it keys on
  `IdleClipCheckLastBusy` (the last check's result), not on a pending look.
- NOTE 2 (holds < ~150 ms: all four states FALSE for up to 500 ms instead of the text state being
  right after the wait; then all corrected, *Paste* of files included, which the old code left
  wrong) - accepted, the spec's FR-005 / clarification Q1.
- NOTE 3 (only the text query reports busy; a hold released between `OleGetClipboard` and
  `OpenClipboard` leaves *Paste* of files disabled without a retry) - a race that existed before;
  accepted, recorded (the next trigger corrects it).
- NOTE 6 (a trigger between the timer message and the idle counts as a retry; a timer during a
  modal dialog only sets flags) - bounded, accepted.
- NOTE 5 (machine state): from ~15:17 (`LogonUI.exe` started - the session was locked) no process
  could open the clipboard (`OpenClipboard` error 5, `GetOpenClipboardWindow` NULL). Confirmed by
  this run at 15:28 (`probe/clip_primitives.ps1`: error 5, `IsTextOnClipboard` loop 151.7 ms).

After the fix: `build.cmd` BUILD SUCCEEDED, `saltests: 30237 checks, 0 failed`. With the
clipboard held by the locked session (the helper cannot open it then, so row HELD cannot run; row
FREE meets the external hold):

| Build | Row FREE under the external hold | File |
|---|---|---|
| this branch | 0.3-1.9 ms, no wait > 16 ms - PASS | `probe/result_after_review1.txt` |
| pre-fix `e1b1e2c9` (reviewer's worktree build) | 14+141, 15+140, 30+126, 15+143, 15+141 ms - FAIL | `probe/result_neg_locked.txt` |

The pre-fix range 125-143 ms is exactly feature 372's LOCAL row: 372's "every activation" block was
very likely measured while the workstation was locked (the unattended loop runs while the
maintainer is away) - the item's note "the hidden desktop may make the queries slower" is answered:
not the desktop, the clipboard being unopenable. On a user's unlocked desktop the block occurs
while another program keeps the clipboard open (clipboard managers, remote-desktop clipboard
sharing, a hung program); the change removes it in every case. A second review was not required
(no MUST); the SHOULD fix is small and follows the archive menus' existing `OnEnterIdle` pattern.
