---
title: Drag from a ZIP or SFTP panel during a quick search acts only on the dragged item
type: person-step
status: new
severity: 7
area: data-safety
source: review:244
who: person
created: 2026-10-18
updated: 2026-10-18
verified: -
effort: S
feature: -
related: [judge-the-quick-search-tint-on-a-real-screen-and-try-shift]
depends-on: []
reason: -
---

# Drag from a ZIP or SFTP panel during a quick search acts only on the dragged item

## Problem

A drag from an archive or plug-in FS panel to the other panel posts its operation (unpack or copy/move) to the source panel; the operation reads the panel's selection. Before the review fix of feature 244, the drop ended the source panel's quick search first, so selected items the search had hidden were extracted or moved too, without a confirmation. The fix keeps the search for such a drag until the posted operation has run. A drag cannot be driven on the hidden desktop.

## Evidence

- Review round 1 of feature 244 (data safety) found it, `specs/244-quick-search-substring-filter/fix-log.md`.
- Fixed in 7536fcc2 and adjusted after review round 2: `src/shellsup.cpp` `DropEnd` passes `isFakeDataObject` as `keepOtherSearch` to `CMainWindow::FocusPanel`; `src/fileswnb.cpp` `WM_USER_DROPUNPACK` / `WM_USER_DROPFROMFS` end the search after the operation.

## Expected

Only the dragged item is extracted, copied or moved; the item hidden by the search stays where it is and stays selected.


## Steps

- [ ] Open a ZIP archive in the left panel with files `a.txt` and `b.log`; select `b.log`; type `a` (only `a.txt` is visible); drag `a.txt` with the left mouse button onto the right panel. Only `a.txt` is extracted; after Esc in the left panel `b.log` is still selected.
- [ ] The same with an SFTP panel (Docker test server `tandem-sftp`, localhost:2222) and a right-button drag choosing Move: only `a.txt` is moved.
- [ ] The same drag with the search off: the selected `b.log` is the one copied (0.1.10 behaviour of a drag of a selected item is unchanged).

## Log

- 2026-10-18 — created (source review:244)
