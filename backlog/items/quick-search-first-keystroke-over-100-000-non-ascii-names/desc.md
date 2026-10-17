---
title: Quick search: first keystroke over 100,000 non-ASCII names takes about 335 ms
type: improvement
status: new
severity: 3
area: panels-ui
source: measure:244
who: agent
created: 2026-10-18
updated: 2026-10-18
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Quick search: first keystroke over 100,000 non-ASCII names takes about 335 ms

## Problem

With quick search in the new mode (feature 244), the first keystroke that matches nearly every item of a folder of 100,000 non-ASCII names (e.g. Czech) takes about 311-335 ms in the Release build. The Backspace that ends the search and shows the full listing again takes about 263-301 ms. Typing on takes 12-32 ms. Spec 244 SC-003 asks under 0.3 s per keystroke at 100,000 items. The time is not the matching (keys are built once per search, about 15 ms per 10,000 names in Debug): it is `RefreshListBox` measuring the width of every visible name with GDI, which is much slower for non-ASCII text (the same step for ASCII names takes 24 ms). Opening such a folder costs the same.

## Evidence

At 7536fcc2:
- `specs/244-quick-search-substring-filter/probe/result_perf_release.txt`, row `P100000cz` (`qs244_probe.ps1 -Perf`, Release build in a scratch build directory);
- `src/fileswn0.cpp` `CFilesWindow::QFApply` calls `RefreshListBox(xOffset, topIndex, focus, TRUE, FALSE)`, `QFEndView` calls `RefreshListBox(-1, -1, FocusedIndex, TRUE, FALSE)`;
- `src/fileswn2.cpp` `CFilesWindow::RefreshListBox` measures every item in the Brief and Detailed cases (`GetTextExtentPoint32W` per name).

## Expected

The first keystroke and the end of a search at 100,000 non-ASCII names under 0.3 s in Release (SC-003), measured with the same probe row.

## Approach

When the filtered view is a subset of the listing just laid out, keep the measured column widths instead of measuring the visible names again (a light relayout: item count, top index, repaint); when the search ends, reuse the widths measured for the full listing before the search started.

## Notes

Not a defect of the matching; the layout cost exists for any refresh of such a folder.

## Log

- 2026-10-18 — created (source measure:244)
