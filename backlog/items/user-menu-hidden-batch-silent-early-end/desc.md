---
title: A hidden User Menu batch that stops at its chcp or cd line tells nobody
type: bug
status: open
severity: 3
area: panels-ui
source: manual
who: agent
created: 2026-10-20
updated: 2026-10-23
verified: -
effort: M
feature: -
related: [user-menu-errors-name-the-file-or-folder]
depends-on: []
reason: -
---

# A hidden User Menu batch that stops at its chcp or cd line tells nobody

## Problem

A User Menu item "Execute Through Shell" without "Open Shell Window" runs its batch file in a hidden cmd window. Two guards of feature 226 end the batch early - `@"<system>\chcp.com" <cp>>nul || exit /b 1` (the code-page switch failed) and `@cd /d "<folder>" || exit /b 1` (the Initial Directory or an item folder is not there) - so nothing runs in a wrong folder or code page, but with the window hidden the user sees nothing at all: the command just does not happen. Also left from 226: a shell window kept open (`/K`) ends at the OEM code page (the batch's last line switches back to it), not at the code page the console had before the batch (e.g. one set by cmd's AutoRun).

## Evidence

At 50cf9e7d (by reading):

- `src/common/salbatchtext.h` `SalBatchCodePageLine` (~104-122): the first code-page line gets ` || exit /b 1`; the closing line switches to the OEM code page.
- `src/mainwnd4.cpp` `CMainWindow::UserMenu` (~1038-1043): the `@cd /d "..." || exit /b 1` lines; ~1136 `si.wShowWindow = UseWindow ? SW_SHOWNORMAL : SW_HIDE`; ~1173 the process handle goes to `DiskCache.AssignName` - nobody reads its exit code.
- `src/mainwnd4.cpp` `WriteUserMenuBat` (~398-442): `SALBATCH_UTF8` writes the 65001 line, the text, then the OEM line.
- `specs/226-user-menu-batch-encoding/fix-log.md`, *Known limits*: "a failed code-page switch or `cd` ends the batch file silently when its window is hidden; a shell window kept open ends at the OEM code page". Probe row CDFAIL of `um226_probe.ps1` (nothing copied - and nothing shown).
- Split from `user-menu-messages-and-folder-leftovers`.

## Expected

- A hidden batch that ends at its chcp or `cd` guard is reported to the user (which folder or which code page), or the condition is refused before the batch is started; the guard itself stays (never run in another folder or code page).
- A kept shell window ends at the code page its console had before the batch, or the limit stays documented by a decision.
- A probe row with a missing Initial Directory in a hidden batch shows the report; 226 / 229 / 234 probes stay green.

## Approach

Options to measure: (a) a pre-check in the program of every folder the batch will `cd` into when its text holds no `%` left for cmd (the common case; see `user-menu-errors-name-the-file-or-folder`); (b) the program waits for / is notified of the hidden process's exit code (the handle is the disk cache's - a watcher must not hold the cache lock); (c) a distinct exit code per guard. For the kept shell: save the console's code page at the batch's start (the output of `chcp` is localised - parse with care) or restore through `mode con cp select`, measure first.

## Notes

The pre-check of (a) covers most cases; an Initial Directory with a `%VAR%` typed by the user is only known to cmd. A new message string would need the two-stage `.slt` refresh.

## Log

- 2026-10-20 — created (source manual)
- 2026-10-20 — moved to Next position 53
- 2026-10-23 — related item user-menu-messages-and-folder-leftovers closed: split into: user-menu-errors-name-the-file-or-folder, user-menu-hidden-batch-silent-early-end, user-menu-shortcut-start-in-folder, user-menu-unc-folder-pushd, command-line-comspec-read-wide, user-menu-long-paths - the parts replace it; maintainer 2026-10-23
