---
title: Find: clicking a result column again does not reverse the sort order
type: bug
status: in-progress
severity: 4
area: panels-ui
source: github#23
who: agent
created: 2026-11-06
updated: 2026-11-07
verified: 2026-11-07 1549e06a
effort: S
feature: 407
related: []
depends-on: []
reason: -
---

# Find: clicking a result column again does not reverse the sort order

## Problem

In *Find Files and Directories* (Ctrl+F) a user searches, then clicks a column header of the results to sort them. The first click sorts once, and every further click on the same header does nothing. Elsewhere in Windows a second click reverses the order: newest first, then oldest first. The reporter also says the date sort looks wrong: the results span 2006-2016, but the sorted list starts at 2015. The original Open Salamander 4.0 behaved the same way.

## Evidence

GitHub issue #23: https://github.com/tandemcommander/tandemcommander/issues/23. Reported 2026-11-05; the version is not stated (0.2.0 was the current release); the original text and the link to the screen recording are in `issue.md`.

By reading at d18047fe, `src/finddlg1.cpp`:
- `LVN_COLUMNCLICK` (line 4435) calls `FoundFilesListView->SortItems(subItem)` for columns 0-4. There is no remembered column and no direction.
- `CFoundFilesListView::SortItems` (line 453) always sorts ascending.
  - Clicking the same column again re-sorts the same order, so "nothing happens".
  - In the non-duplicate branch it calls `QuickSort` twice (lines 488 and 496).
- `CFoundFilesListView::CompareFunc` (line 603) always puts **directories before files** (`res = f1->IsDir ? -1 : 1`) and only then compares the column. Date and Time (3 and 4) both use `CompareFileTime(&LastWrite)`.
  - With folders among the results, the date-sorted list starts with the folders, oldest folder first, and the oldest file comes only after the last folder.
  - That likely explains "starts at 2015" (not verified against the reporter's data).
- No sort arrow is set in the header: there is no `HDF_SORTUP` / `HDF_SORTDOWN` in `finddlg*.cpp`.

## Expected

- A click on a result column header sorts by that column ascending. A click on the **same** column again reverses the order, and further clicks keep toggling. A click on another column starts ascending again.
- The header shows the column and direction with the standard sort arrow (`HDF_SORTUP` / `HDF_SORTDOWN`).
- Directories and files are treated as for the panel. Whether folders stay grouped first in both directions or the list is sorted purely by the column is decided in the spec, recorded and covered by a test. The reporter's date case must sort by date as a user expects.
- Duplicate-search mode keeps its restrictions: the columns it cannot sort by still do nothing.
- The pure rules go to `src/common/` under `saltests`: the compare order, the direction toggle, and the folder rule.

## Notes

Severity 4: a function does not work as users expect (no descending order, a confusing order with folders) and a workaround exists (sort in the panel after *Feed to panel*). Every Find user who sorts results is affected. One reporter; the behaviour dates from Open Salamander 4.0. GitHub labels: bug, ai backlog.

Whether folders-first is intended for the Find list is not documented in the code. The panel's own sorting rules (`Configuration` sort options) may be the model; check `FEATURE-HISTORY.md` for the panel sort before deciding.

## Log

- 2026-11-06 — created (source github#23)
- 2026-11-06 — fields set from the issue text and labels
- 2026-11-06 — moved to Next position 2
- 2026-11-07 — verified at 1549e06a: still present at 1549e06a: hidden-desktop probe, second View>Date or Date header click keeps the order, no header arrow, folders before older files
- 2026-11-07 — run started, feature 407
