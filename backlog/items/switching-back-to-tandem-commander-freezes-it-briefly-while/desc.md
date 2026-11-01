---
title: Switching back to Tandem Commander freezes it briefly while a panel shows a WSL folder
type: bug
status: in-progress
severity: 5
area: panels-ui
source: manual
who: both
created: 2026-11-01
updated: 2026-11-01
verified: 2026-11-01 50c47081
effort: M
feature: 372
related: []
depends-on: []
reason: -
---

# Switching back to Tandem Commander freezes it briefly while a panel shows a WSL folder

## Problem

A user has a panel open on a WSL folder, for example `\\wsl.localhost\Ubuntu`. Each time they switch to another window and then back to Tandem Commander, the program stops responding for a moment and the mouse pointer turns into the busy circle. This happens on every activation, not now and then. Switching back to the window must never make the program wait for the file system.

## Evidence

Reported by the maintainer (2026-11-01). It happens on every switch back to the program with `\\wsl.localhost\Ubuntu` in a panel. Not reproduced by an agent yet. The cause below comes from reading the code at 777b3552.

- `src/mainwnd3.cpp:6479-6543`, `WM_ACTIVATEAPP`: when the program is activated it posts `WM_USER_END_SUSPMODE` (line 6539).
- `src/mainwnd3.cpp:6282-6349`, `WM_USER_END_SUSPMODE`: sets the cursor to `IDC_WAIT` (line 6299), which is the busy circle the user sees. It then calls `LeftPanel->Activate(FALSE)` and `RightPanel->Activate(FALSE)` (lines 6348-6349) on the UI thread.
- `src/fileswn6.cpp:262-324`, `CFilesWindow::Activate`: for a disk path it calls `CheckPath(FALSE)` synchronously (line 274). For a network drive it then posts `WM_USER_REFRESH_DIR_EX` to re-read the whole folder on every activation (lines 300-315), unless `Configuration.DrvSpecRemoteDoNotRefreshOnAct` is set.
- `src/fileswnd.h:626`: `GetNetworkDrive()` returns true when `DriveType == DRIVE_REMOTE`. A WSL UNC path is presumably treated as remote (not verified).
- `src/dialogs4.cpp:399`: `DrvSpecRemoteDoNotRefreshOnAct` defaults to `FALSE`, so a remote path is checked and listed again on every activation by default.

WSL's 9P file server answers slowly, so the path check and the full re-listing on the UI thread are the likely source of the pause.

## Expected

Switching back to Tandem Commander with a WSL folder (and any slow network share) in a panel shows no busy cursor and does not block input. The panel content is still brought up to date, either in the background or after the window is already responsive. Measured on `\\wsl.localhost\<distro>`: the time from activation until the message loop runs again stays below a perceptible threshold (for example under 50 ms), compared with the time measured before the fix.

## Log

- 2026-11-01 — created (source manual)
- 2026-11-01 — moved to Next position 1
- 2026-11-01 — verified at 50c47081: reproduced at 50c47081: hidden-desktop probe, WM_ACTIVATEAPP cycles; WSL panel blocks UI ~140 ms at activation + ~400 ms at the 200 ms refresh timer; local control 140 ms
- 2026-11-01 — run started, feature 372
