---
title: A plug-in's Save dialog may open the program's last folder, not the panel's
type: improvement
status: rejected
severity: 2
area: other-plugins
source: probe:117
who: agent
created: 2026-10-06
updated: 2026-10-17
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: feature 121, 2026-10-06 (listed under NEXT-WORK §C Decided - not to do): measured as Windows' per-program first-folder rule, by design; putting the folder into `lpstrFile` did not change it; only `IFileDialog::SetFolder` would - a change of API, a feature of its own if wanted. The 121 change was reverted.
---

# A plug-in's Save dialog may open the program's last folder, not the panel's

## Problem

Checksum's Save dialog (found by 117's GUI run) opened another program's last folder instead of the panel's. Windows records, per program path, the first `lpstrInitialDir` it was ever given (`ComDlg32\FirstFolder`); a later dialog given that same folder opens in the program's last-used folder instead (`LastVisitedPidlMRU`, keyed by the file name). Other folders open as asked. Changing it would mean moving Checksum and `SplGetFileNameU8` to `IFileDialog::SetFolder` (not possible for PictView's hooked dialog).

## Evidence

specs/NEXT-WORK.md item 5, queue 104 entry 4 (L1842-1856 at 7993914c): measured by feature 121 - harness named `tandemcommander.exe` + probe row K0; `specs/121-small-batch/fix-log.md` and `research.md`; origin `specs/117-checksum-lists/`. Migrated from specs/NEXT-WORK.md §C *Decided - not to do* (L475, at 7993914c).

## Expected

(not stated in the source)

## Log

- 2026-10-06 — feature 121 measured the first-folder rule and left it as it was; its change was reverted
- 2026-10-17 — migrated from specs/NEXT-WORK.md §C and 'Recorded, deliberately not on the list' (feature 242)
