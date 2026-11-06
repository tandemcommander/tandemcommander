---
title: Switching away from an FTP tab leaves the tab strip in drag mode
type: bug
status: open
severity: 5
area: panels-ui
source: github#22
who: both
created: 2026-11-06
updated: 2026-11-06
verified: 2026-11-06 09eaa097
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Switching away from an FTP tab leaves the tab strip in drag mode

## Problem

A user has several panel tabs and one of them shows an FTP connection. They click another tab of the same panel. The FTP plug-in asks what to do with the connection, and the user answers *keep* (detach). From then on the strip behaves as if a tab were being dragged: the black insert mark follows the mouse cursor although no button is held. The next click drops the tab at the mark, so a tab can be moved where the user never meant to put it. The reporter's screen recording shows it.

## Evidence

GitHub issue #22: https://github.com/tandemcommander/tandemcommander/issues/22. Reported 2026-11-05; the version is not stated (0.2.0, released 2026-10-25, was current); the original text and the link to the recording are in `issue.md`.

Cause by reading at d18047fe, `src/tabwnd.cpp`:
- `CTabWindow::OnLButtonDown`, `case tspTab:` (line 507) first calls `FilesWindow->SwitchToTab(index)`, which runs `ChangeDir` and with it the leave rules of the plug-in file system.
- For FTP those rules show a modal question. The user releases the mouse button while the dialog is open, so the strip never gets that `WM_LBUTTONUP`.
- Only then does the code arm the drag (`WaitForDrag = TRUE`, `DragIndex`, `SetCapture(HWindow)`, lines 511-520).
- With the capture held and no button-up pending, the next mouse movement past `SM_CXDRAG` turns it into `Dragging` (`OnMouseMove`, line 527). `PaintInsertMark` (line 434) then draws the mark at the cursor. The next button-up calls `MoveTab` (`OnLButtonUp`, line 572).

Not reproduced in this session. The same path is expected for any leave prompt during a tab switch (another plug-in file system, an archive asking whether to update).

## Expected

Switching tabs with a click never leaves the strip in drag mode:
- When `SwitchToTab` showed any window (or the left button is no longer down when it returns), no drag is armed and the capture is not taken.
- A tab moves only while the left button is actually held from the press to the release.
- A probe reproduces it before the fix: a click on a tab whose switch raises a modal prompt, the prompt answered, then mouse movement. The strip must not be in drag mode, and no tab may move on the next click. After the fix the probe passes. The real FTP prompt with a real mouse is a person's check.

## Notes

Severity 5: a function does not work and a workaround exists (Esc does not help, but clicking elsewhere drops the tab and it can be dragged back). It happens on every tab switch away from an FTP tab that keeps its connection. One reporter. GitHub labels: bug, ai backlog.

Related to `panel-tabs-rounded-windows-11-look-with-icons-and-roomier` (first in *Next*), which rewrites this mouse handling with Chrome-like live dragging and close-on-release. Its new code must keep this rule: arm a drag only while the button is still down after `SwitchToTab`. If that item runs first, its feature meets this defect, which by `stop-rules.md` rule 11 (severity 5) is fixed there. Then close this item with that feature.

## Log

- 2026-11-06 — created (source github#22)
- 2026-11-06 — fields set from the issue text and labels
- 2026-11-06 — moved to Next position 2
- 2026-11-06 — related item panel-tabs-rounded-windows-11-look-with-icons-and-roomier done in feature 404
- 2026-11-06 — verified at 09eaa097: reproduced at 09eaa097 by probe tabs405: after an error box during the tab switch the strip keeps the capture and a later move+release moves the tab
