---
title: Opening a folder found by quick search briefly shows the whole parent folder
type: bug
status: open
severity: 2
area: panels-ui
source: manual
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Opening a folder found by quick search briefly shows the whole parent folder

## Problem

A user types to quick search a panel (the substring filter of feature 244, on by default). The panel shows only the matching items. The user focuses a matching folder and presses Enter, and the panel opens it. Sometimes, before the new folder's listing appears, the panel shows the full listing of the parent folder for a few milliseconds. The search seems to end first and the unfiltered parent folder is drawn before the new folder is entered. The result is correct; the flash is cosmetic. The maintainer reports it as intermittent.

## Evidence

Reported by the maintainer (2026-11-01); not reproduced. The cause below is suspected from reading the code at 777b3552:

- `src/fileswn2.cpp:58-73`, `CFilesWindow::Execute`: when a directory is opened while the panel is filtered (`QuickSearchMode && QFMode && QFActive`), it maps the index to the full listing and calls `EndQuickSearch()` *before* the path change. The comment says the full listing must be back before the position (top index) is remembered.
- `src/fileswn0.cpp:29-51`, `CFilesWindow::EndQuickSearch`: calls `QFEndView(TRUE)` in the new mode.
- `src/fileswn0.cpp:391-409`, `CFilesWindow::QFEndView`: with `repaint` TRUE and a filtered view it calls `RefreshListBox(-1, -1, FocusedIndex, TRUE, FALSE)` and `QFUpdateIndication()`. That lays out and invalidates the panel with the full parent listing.
- `src/fileswn2.cpp:435`, the same function: only after that does `ChangePathToDisk(HWindow, fullName, -1, NULL, &noChange, FALSE)` read the new folder. If any paint is processed before that read finishes, the unfiltered parent listing is drawn. This would explain why the flash happens only sometimes (a slow listing, a wait window, a message pump during the read).
- Feature 244 in `specs/FEATURE-HISTORY.md` (`- 244-quick-search-substring-filter`) says the search ends at a path change before `RefreshPathHistoryData`. CLAUDE.md's standing rule (244) requires `Dirs`/`Files` to be back to the full listing before a path change.

## Expected

Pressing Enter on a folder in a filtered panel goes straight from the filtered view to the new folder's listing. The unfiltered parent listing is never drawn in between. The rest stays as it is: the full listing is restored before the path change, Back history and the remembered top index are correct, the search has ended in the new folder, and the 244 probes and saltests pass.

## Log

- 2026-11-01 — created (source manual)
- 2026-11-01 — moved to Next position 2
