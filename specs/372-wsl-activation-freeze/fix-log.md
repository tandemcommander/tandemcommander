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
- D3: a result is applied only if the panel still shows the same folder (`SalPathEqualOrdinalCI`,
  same panel type) and no newer check of that panel started (sequence number). Pure rule in
  `src/common/salactcheck.h` with `saltests` checks.
