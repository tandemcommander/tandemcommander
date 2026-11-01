# Fix log - 372-wsl-activation-freeze

Backlog item `switching-back-to-tandem-commander-freezes-it-briefly-while`. Run started at
`main` `50c47081` (2026-11-01).

## Measurements before the fix (HEAD `50c47081`, Debug x64)

### Win32 primitives on the WSL path (`probe/wsl_primitives.ps1`, from PowerShell)

`\\wsl.localhost\Ubuntu\` (warm distribution): `GetDriveTypeW` = 4 (DRIVE_REMOTE), file system
`9P`, `GetFileAttributesW` / `GetDiskFreeSpaceExW` / `GetVolumeInformationW` 0.5-1 ms,
enumerating 71 entries 1 ms, `usr\bin` (827 entries) 2 ms. `FindFirstChangeNotificationW`
**fails** (handle -1) - the panel cannot be refreshed automatically. After `wsl --shutdown` the
first call took 1988 ms (cold start of the distribution).

### Activation probe (`probe/act372_probe.ps1`)

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <...>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <...>\act_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe ..."
```

The probe posts WM_ACTIVATEAPP FALSE / TRUE to the main window (what Windows sends on Alt+Tab)
and pings it with `SendMessageTimeout(WM_NULL)` every 2 ms for 1.5 s; every wait > 16 ms is
recorded with its start offset after the activation. Result (`probe/result_before.txt`,
`probe/result_before_offsets.txt`), 5 of 5 activations alike:

| Row | Block at +15 ms | Block at +218 ms | Max wait |
|---|---|---|---|
| LOCAL (800 files, control) | 140 ms | - | 140 ms |
| WSLROOT `\\wsl.localhost\Ubuntu\` | 140 ms | 392-408 ms | 408 ms |
| WSLBIG `...\usr\bin` (827) | 140 ms | 408-411 ms | 411 ms |

Registry restored, identical SHA-256.

### Where the time goes (temporary instrumentation, reverted)

A QPC timestamp log (`%TEMP%\tc372prof.txt`) in `WM_USER_END_SUSPMODE`, `CFilesWindow::Activate`,
`RebuildDriveBarsIfNeeded`, the refresh handler and `ChangePathToDisk`, plus the idle clipboard
check (`mainwnd1.cpp`), one activation per row:

- `WM_USER_END_SUSPMODE` as a whole: ~5 ms (both `Activate` calls with `CheckPath`: 0.4-1.1 ms
  each on a warm WSL; `InitOneDrivePath`, `GetNetworkDrives`: < 1 ms).
- 200 ms later the refresh (`IDT_REFRESH_DIR_EX` timer -> `RefreshDirectory` -> `ChangePathToDisk`):
  `SalCheckAndRestorePathWithCut` 1 ms, `CommonRefresh` 4-9 ms, then the branch
  `isRefresh && !cannotList && GetMonitorChanges() && !AutomaticRefresh` -> **`Sleep(400)`** and a
  second `CommonRefresh` (`src/fileswn2.cpp`, `ChangePathToDisk`). `REF end` 410-428 ms after
  `REF begin`. That is the second block: a fixed 400 ms sleep on the UI thread on every refresh of
  a monitored folder whose change notification failed - every WSL refresh, because 9P has no
  change notification.
- The first block (140-154 ms, also with local folders) is the idle-time clipboard check that the
  activation requests (`IdleCheckClipboard` -> `ClipboardPaste`, `IsTextOnClipboard`,
  `ClipboardPasteLinks`, `ClipboardPasteToArcOrFS` in `CMainWindow::RefreshCommandStates`,
  `mainwnd1.cpp`): 153.9 / 154.2 ms. It does not touch a panel folder's file system - out of the
  item's scope; recorded as an Inbox item (see *Findings outside the scope*). It may be specific
  to the hidden desktop (clipboard owner on another desktop); not measured on the user's desktop.

The cold-distribution case: `CFilesWindow::Activate` calls `CheckPath(FALSE)` synchronously
(`SalCheckPath`: worker thread, 200 ms grace wait, then the "ESC to cancel" wait window, loop of
200 ms waits) - a stopped WSL (2 s first answer) blocks the activation for ~2 s with the busy
cursor. Not reproduced in the probe (stopping the user's distribution is not the probe's to do);
derived from the code and the primitive measurement.

## Decisions

- D1 (the 400 ms): the synchronous `Sleep(400)` + second listing becomes a deferred
  verification: after a successful refresh listing of a folder whose automatic refresh is broken,
  the panel starts a 400 ms one-shot timer; when it fires, the folder's accessibility is checked
  on a worker thread; if it is no longer accessible, the panel posts its normal refresh
  (`WM_USER_REFRESH_DIR`), which lists, fails and leaves the folder as before. If it is
  accessible, nothing happens (no re-listing, so no refresh loop).
- D2 (activation of a network folder): `CFilesWindow::Activate` no longer calls `CheckPath`
  synchronously for a network folder (`GetNetworkDrive()`); it starts the same background
  accessibility check; the result (posted back to the panel) leads to what the synchronous code
  did: accessible -> `WM_USER_REFRESH_DIR_EX` (the refresh as today), not accessible ->
  `WM_USER_REFRESH_DIR` (as the old "another path error" branch). The ESC branch of the old code
  (switch to a fixed drive) cannot occur: there is no wait window.
- D3: at most one background check per panel; a request while one runs is served by it. A
  result is applied only if the panel still shows the same folder (`SalPathEqualOrdinalCI`, same
  panel type); otherwise it is dropped and a still wanted check restarts on the current folder.
  Pure rule in `src/common/salbkgndcheck.h` with `saltests` checks.

## speckit-analyze

- Pass 1: 0 CRITICAL, 2 HIGH (F1 scenario 1 vs SC-001; F2 sequence number vs the one-at-a-time
  design) - both fixed in spec.md / fix-log; pass 2: 0 CRITICAL, 0 HIGH. MEDIUM F3 (cold distribution has no automated
  test - a person-step, T016), LOW F4 (FR-003 names a timer) accepted.

## Implementation

- `src/common/salbkgndcheck.h` (new): `SalBkgndCheckRoute`, `SalNeedsAutoRefreshVerify`,
  `SalBkgndCheckAction` (the table of `contracts/background-path-check.md`).
- `src/salamdr5.cpp`: `SalTestPathAccessible` = the accessibility test of `ThreadCheckPathFBody`
  moved into a function (same calls and error mapping; the `*` mask of the fixed-disk fallback is
  now a heap buffer of the path's length instead of the thread's `SAL_MAX_PATH_UTF8 + 8` stack copy
  - never cut); `StartBkgndPathCheck` + worker `BkgndPathCheckThread` (call-stack and exception
  wrapper as `ThreadCheckPathF`, `AddAuxThread`, data freed when the post fails).
- `src/consts.h`: `WM_USER_BKGNDCHECK_DONE` (`WM_APP + 421`), `IDT_AUTOREFRESHVERIFY` (955) - both
  numbers unused in `src/` before; `CBkgndPathCheckData`.
- `src/fileswnd.h`, `src/fileswn1.cpp`: panel members (`BkgndCheckRunning`, `BkgndCheckWanted`,
  `AutoRefreshVerifyTimerSet`) and their initialization.
- `src/fileswn6.cpp`: `CFilesWindow::Activate` - a network disk/archive folder starts the
  background check (falls back to the old synchronous code when no worker can be started);
  `RequestBkgndPathCheck`, `OnBkgndPathCheckDone`, `StartAutoRefreshVerify`.
- `src/fileswn2.cpp`: `ChangePathToDisk` - `Sleep(400)` + second `CommonRefresh` replaced by
  `StartAutoRefreshVerify()` under the same condition.
- `src/fileswnb.cpp`: the panel handles `IDT_AUTOREFRESHVERIFY` and `WM_USER_BKGNDCHECK_DONE`.
- No UI string, menu or dialog changed: no `.slt` refresh (stop-rules §2.13 does not apply).
- clang-format: the edited legacy files were not clang-format-clean at HEAD (trailing-comment
  alignment in untouched code); the new header is clean; the edited files were left in the
  style of their surroundings.

Consumers enumerated (stop-rules §2.2): `CFilesWindow::Activate` is called only from
`WM_USER_END_SUSPMODE` (`mainwnd3.cpp`, both panels, `Activate(FALSE)`) - no other caller; the `Sleep(400)` branch existed only in `ChangePathToDisk` (`grep Sleep(400)`:
one site); `ThreadCheckPathFBody` is the only user of the extracted test besides the new worker.

## Checks

| Check | Command | Result |
|---|---|---|
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| build | `.\build.cmd` (Debug x64) | `BUILD SUCCEEDED` |
| unit rules | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 30115 checks, 0 failed` (`TestBkgndPathCheck372`) |
| probe | `act372_probe.ps1 -Label after` on the hidden desktop | PASS 12, FAIL 0, NOT DRIVEN 4 (`probe/result_after.txt`) |

### Probe after the fix (`probe/result_after.txt`)

| Row | Before (late waits) | After: late (after +100 ms) max | Longest |
|---|---|---|---|
| LOCAL | - | 0.1-2.3 ms | 126-143 ms (the clipboard block) |
| WSLROOT | 392-408 ms at +218 ms | 1.4-4.9 ms | 141-143 ms |
| WSLBIG | 408-411 ms at +218 ms | 0.4-4.7 ms | 140-143 ms |
| WSLNEW | - | 4.8 ms; a folder created while inactive was entered after the activation | PASS |
| WSLDEL | - | 0.2 ms; the panel left the deleted folder for its parent, no message | PASS |
| SHARE `\\localhost\C$\...` | - | 0.2-1.8 ms | 125-143 ms |

CURSOR rows: NOT DRIVEN (hidden desktop). Registry restored, identical SHA-256.

Negative control: the before-run (`probe/result_before.txt`, `result_before_offsets.txt`) used the
same measurement (WM_NULL pings, waits with offsets) on the build of `main`: its late waits of
392-411 ms fail the new verdict (`< 50 ms`); WSLNEW / WSLDEL / SHARE describe behaviour the old
code also had (they guard against a regression, not the defect).

### Deviation (stop-rules §2.14)

The item's *Expected* says the time from the activation until the message loop runs again stays
under ~50 ms. The ~140 ms block that every activation pays (also with local folders) remains: it is
the idle clipboard check, not a wait for a panel folder (fix-log *Where the time goes*). The
conservative way is taken: this feature removes every wait the WSL / network folder caused (late
waits now <= 5 ms); the clipboard block is the Inbox item
`every-activation-of-the-program-blocks-it-150-ms-in-the-idle` (`measure:372`).

## Findings outside the scope

- `every-activation-of-the-program-blocks-it-150-ms-in-the-idle` - the idle clipboard check blocks
  every activation ~150 ms (Inbox, measure:372).

## Review

### Review 1 (independent agent, refute-first) - no MUST

Re-ran the probe on a pre-fix build (`f2825e09`, the source of `main`) and on `167ecb96`:
WSLROOT late waits 393-407 ms -> 4.0-4.5 ms, WSLBIG 397-413 -> 2.4-4.8, WSLDEL blocked 399 ms ->
0.3 ms, LOCAL 143 -> 142 ms; saltests and the encoding guard green. Added rows VEARLY (folder
deleted at +312 ms, after the activation's refresh: left - on both builds) and VLATE (deleted at
+1505 ms, after the verification: stays - the control showing that the deferred verification is
what leaves the folder).

- SHOULD: the gain at activation itself is not measured - a warm WSL check costs ~1 ms; the
  background route pays only for a stopped distribution or a slow share, which is reasoned, not
  measured (stopping the user's distribution is not the run's). -> person-step item at closing
  (`wsl --shutdown`, then Alt+Tab back).
- NOTE: a worker hung in `GetFileAttributes` (dead redirector) kept `BkgndCheckRunning` TRUE and
  swallowed every later activation of the panel, also after a move to another network folder. ->
  **fixed** (in scope, it is this feature's code): `SalBkgndCheckAbandon` - a request abandons a
  running check of another folder or one running >= 10 s (`SAL_BKCHK_ABANDON_MS`); a generation
  number drops the abandoned worker's late result; its wanted bits carry over. saltests + 5
  checks.
- NOTE: the restart / merge branches are driven only by the pure table - accepted (the table is
  the decision; `OnBkgndPathCheckDone` only applies it).
- NOTE: the verification asks "is the folder still accessible", the old code listed it again: a
  folder that exists but can no longer be listed is not left by the verification, and content
  that changed within 400 ms after a refresh shows at the next refresh - accepted, recorded
  (clarification Q1).
- NOTE: A -> B -> A during a check counts as the same folder - one extra refresh at most; FR-005
  reworded to say so.
- NOTE: data of a result posted to a panel destroyed before it is handled leaks at exit only;
  `EndStopRefresh(TRUE)` of the synchronous check is not called for network panels - harmless
  (checked by the reviewer). Accepted.

After the fix: `build.cmd` BUILD SUCCEEDED, `saltests: 30120 checks, 0 failed`, probe
`probe/result_after2.txt` (with VEARLY / VLATE): PASS 16, FAIL 0, NOT DRIVEN 4, registry
restored identical.
