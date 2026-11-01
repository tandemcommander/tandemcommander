---
title: Leaving a folder by other ways during quick search briefly shows the whole folder
type: bug
status: new
severity: 2
area: panels-ui
source: measure:376
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

# Leaving a folder by other ways during quick search briefly shows the whole folder

## Problem

While quick search filters a panel (feature 244), the panel shows only the matches. Opening a matching folder with Enter no longer shows the whole current folder on the way (feature 376). Other ways of leaving the folder while the search runs still do: choosing a drive (Alt+F1/F2), going Back or Forward in the history, Change Directory (Shift+F7), a hot path, a path typed into the directory line. Each ends the search first, and ending it draws the whole unfiltered listing of the current folder before the new folder is read. A person sees the unfiltered folder flash when the new folder takes longer than a screen refresh to read (a large or slow folder, a network share). The result is correct; the flash is cosmetic.

## Evidence

Code at 376-qs-enter-no-flash (main after feature 376): `CFilesWindow::QFEndAtPathChange` (src/fileswnd.h) calls `EndQuickSearch()` with the default `deferPaint = FALSE`; `QFEndView(TRUE)` (src/fileswn0.cpp) then calls `RefreshListBox(-1, -1, FocusedIndex, TRUE, FALSE)`, which ends with `ListBox->PaintAllItems(NULL, 0)` - a synchronous drawing of the whole listing. Call sites that end a search right before reading another folder: `ChangePathToDisk`, `ChangePathToArchive`, `ChangePathToPluginFS` and the history paths (src/fileswn2.cpp, `QFEndAtPathChange(); // feature 244: the history records the full listing's position`), src/fileswn3.cpp, src/fileswnb.cpp, src/mainwnd3.cpp, src/mainwnd4.cpp. Feature 376 measured the same mechanism for Enter with specs/376-qs-enter-no-flash/probe/qs376_probe.ps1: 35-39 samples of the whole parent folder over ~290 ms per round before its fix, 0 after. Not measured for the other routes (code reading only).

## Expected

Every way of leaving a folder while quick search filters it goes from the filtered view straight to the new folder's listing; the unfiltered listing is never drawn in between. The full listing is still back before the path change (rule 244: Back history and remembered positions describe the whole folder), and a change that fails draws the whole current folder once afterwards.

## Log

- 2026-11-01 — created (source measure:376)
- 2026-11-01 — related item opening-a-folder-found-by-quick-search-briefly-shows-the done in feature 376
