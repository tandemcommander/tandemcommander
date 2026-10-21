# Closing report - 281-moved-aside-leftovers
Backlog item: moved-aside-restore-leftovers - A file moved aside to salNNN can stay there silently on the create paths
Outcome: closed

## What changed

- Every create route that moves another entry aside for an 8.3 clash (worker copy of a file and a
  folder, F7, Edit New File, an unpack's member folders and files, the plug-in interface's
  `SalCreateFileEx` / `SalCreateDirectoryEx`) now tells the user, when the move back keeps
  failing, where the entry stays: "Error Renaming File - Path: "...\salNNN" - Error: reason"
  (existing strings, the path whole), before the create's own error. Mechanism: an out record
  `CMovedAsideLeft` (`src/consts.h`); without one the create shows it itself (owner: a window of
  the calling thread). The worker sends the new progress request 13 (`src/dialogs.cpp`) - shown
  also after the user's own cancel, never when the program is exiting or closing unattended.
- PictView's and the Renamer's move back are retried for about a second (`src/common/salmoveback.h`,
  221's rule now shared with the core's `SalMoveFileBack`).
- 221's worker-move report uses the same whole-path form (its error dialog cut long paths).
- Debug-only probe seam `TC_PROBE_MOVE_BACK_FAIL` (`contracts/probe-seam.md`); Release binaries
  hold none of it.

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\281-moved-aside-leftovers\probe\result_<label>.txt -CommandLine "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File specs\281-moved-aside-leftovers\probe\left281_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"`

- Before (the seam only): PASS 8 / FAIL 6 - every `*-left` route left the entry under `salNNN`
  with no message naming it (`result_before.txt`, `result_before_copy.txt`).
- After: PASS 26 / FAIL 0, 13 rows (cp-left, cp-long, cp-cancel, cp-cancel-late, cp-exitcancel,
  cp-brief, dir-left, zip-left, zipdir-left, f7-left, new-left, mv-left, qr-left;
  `result_after.txt`); captures `shot_*_after.png`.
- Renamer `ren281_probe`: PASS 4 / 0 (retry recovers a short hold; a lasting one is named).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `build.cmd`: BUILD SUCCEEDED; `build.cmd release`: BUILD SUCCEEDED (seam variable in Release
  binaries: 0).
- saltests: 25,011 checks, 0 failed (`TestMoveBack281`; negative control: 4 failed).
- Probes: left281 26 / 0; ren281 4 / 0; regression 203 14 / 0, 201 6 / 0. Negative controls: the
  before run; `cp-exitcancel` fails with the outside-cancel rule removed; review 2's control for the
  user cancel.

## Reviews (findings and what was done)

- Review 1: MUST 1 (a long path cut by the error dialog's ellipsis) - fixed, whole-path message box
  and request 13; SHOULD 2 (the entry's own name not shown) - needs a new string, Inbox item;
  SHOULD 3 (a cancel swallowed the report) - fixed; NOTEs recorded in `fix-log.md`.
- Review 2: no MUST; SHOULD 1 (a session end could show a box nobody answers) - fixed (only the
  user's own cancel shows it); NOTE 3 (feature 198's temp-name route) - Inbox item; others
  recorded.

## Owed to a person (with the new person-step items)

- Nothing. PictView's retry and FTP / SFTP were checked by reading (the Renamer drove the same
  wrapper and retry code); recorded in `fix-log.md`, no person step needed.

## New Inbox items (slug - title)

- left-aside-message-names-the-entry - The left-aside message names only the salNNN entry, not the entry it was
- rename-via-temp-left-silently - A rename via a temporary name can leave the source there silently after a cancel
