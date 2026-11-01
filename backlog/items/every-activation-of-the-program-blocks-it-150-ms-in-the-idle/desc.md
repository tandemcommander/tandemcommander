---
title: Every activation of the program blocks it ~150 ms in the idle clipboard check
type: bug
status: open
severity: 3
area: panels-ui
source: measure:372
who: both
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Every activation of the program blocks it ~150 ms in the idle clipboard check

## Problem

Each time the user switches back to Tandem Commander, the program stops answering for about
150 ms, also with local folders in both panels. Feature 372 removed the waits a WSL or network
panel folder caused; this block remained and is the largest part of what an activation still
costs.

## Evidence

- Measured by feature 372 (`specs/372-wsl-activation-freeze/fix-log.md`, *Where the time goes*;
  probe `specs/372-wsl-activation-freeze/probe/act372_probe.ps1`, row LOCAL): on every
  activation a wait of 125-143 ms starts ~15 ms after `WM_ACTIVATEAPP` (Debug x64, hidden desktop,
  `main` 50c47081 and after the fix).
- Temporary QPC instrumentation (reverted) put it in `CMainWindow::RefreshCommandStates`
  (`src/mainwnd1.cpp`, the `if (IdleCheckClipboard)` block: `ClipboardPaste(FALSE, TRUE)`,
  `IsTextOnClipboard()`, `ClipboardPasteLinks(TRUE)`, `ClipboardPasteToArcOrFS(TRUE, ...)`):
  153.9 / 154.2 ms. `WM_ACTIVATEAPP` sets `IdleCheckClipboard = TRUE` (`src/mainwnd3.cpp`,
  `case WM_ACTIVATEAPP`), so the next idle runs the check on the UI thread.

## Expected

Switching back to the program does not block it for the clipboard check: the enabled state of
the paste commands is computed without a perceptible wait (for example under 30 ms), or off the
UI thread, or only when a paste command is about to be shown. Measured with the probe of
feature 372 (row LOCAL) before and after.

## Notes

- Not verified on the user's own desktop: the hidden desktop may make the clipboard queries
  slower (another desktop's clipboard owner, OLE). A person should time it there first (who:
  both); if it is far shorter there, the item may be closed.
- Which of the four queries costs the time was not split further.

## Log

- 2026-11-01 — created (source measure:372)
- 2026-11-01 — related item switching-back-to-tandem-commander-freezes-it-briefly-while done in feature 372
- 2026-11-01 — moved to Next position 3
