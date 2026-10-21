---
title: A rename via a temporary name can leave the source there silently after a cancel
type: bug
status: new
severity: 3
area: file-ops
source: review:281
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: [left-aside-message-names-the-entry]
depends-on: []
reason: -
---

# A rename via a temporary name can leave the source there silently after a cancel

## Problem

F6 / the worker's move of a file to another spelling of its own name (feature 198: a case change,
NFC / NFD) renames it through a temporary name. When the second rename and the way back both fail,
the worker shows the "cannot move" dialog naming the temporary name - but not after a cancel (the
dialog is skipped while the worker is cancelled), and then one last attempt to give the source its
own name back is made; if that fails too, the source stays under the temporary name with only a
trace. Also, the dialog (`CCannotMoveDlg`) paints its paths with an ellipsis, so a long temporary
path is cut (the kind of cut fixed for the 8.3 move-aside message in 281).

## Evidence

- At 39262955: `src/worker.cpp` `DoMoveFile`, the `svtLeftAtTemp` branch: `if (!*dlgData.CancelWorker)`
  around `WM_USER_DIALOG` 3 / 4; after Skip / Cancel `if (!SalMoveFile(tmp, op->SourceName))
  TRACE_E("DoMoveFile(): the source stays under the temporary name " << tmp);` - nothing shown.
- `src/dialogs.cpp` `CCannotMoveDlg` (requests 3 / 4) - paths in painted fields with path ellipsis
  (reported by the independent review of 281, not re-measured here).
- Independent review 2 of feature 281 (NOTE 3); the race is drivable only with a seam (the two
  renames fail between two moves of one operation) - 281's `TC_PROBE_MOVE_BACK_FAIL` does not reach
  this route (it acts on `SalMoveBackRetry` only).

## Expected

When the source cannot get its own name back, the user is told where it is - also after a cancel
(as 281's request 13 does for an entry moved aside: shown after the user's own cancel, not when the
program is exiting), with the path whole.

## Notes

Severity 3: nothing is lost, the file keeps its content under a temporary name; narrow (the second
rename and two returns must fail - another program holding the file). Not verified by driving.

## Log

- 2026-10-21 — created (source review:281)
