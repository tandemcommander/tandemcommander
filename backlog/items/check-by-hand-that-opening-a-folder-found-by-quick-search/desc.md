---
title: Check by hand that opening a folder found by quick search shows no flash (376)
type: person-step
status: new
severity: 2
area: panels-ui
source: leftover:376
who: person
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Check by hand that opening a folder found by quick search shows no flash (376)

## Problem

Feature 376 stopped quick search from drawing the whole parent folder when a found folder is opened: the panel goes from the tinted filtered view straight to the new folder. The hidden-desktop probe proved it by sampling the panel window's pixels; nobody has looked at it on a real screen with a real keyboard and a slow folder.

## Evidence

`specs/376-qs-enter-no-flash/quickstart.md` V4 (a person, not driven); probe `specs/376-qs-enter-no-flash/probe/qs376_probe.ps1` FLASH 35-39 PARENT samples per round before, 0 after (`fix-log.md`, *Measurements after*).

## Expected

Pressing Enter (or double-clicking) on a folder found by quick search shows no frame of the unfiltered parent folder; the new folder appears untinted, without the search text.

## Steps

- [ ] Make a folder with five subfolders, one of them holding 30,000 files (or use a large folder
      on a network share). Open the parent in the left panel, Detailed view, quick search on
      (*Configuration > Panels*, default).
- [ ] Type part of the large subfolder's name so that only it (and perhaps a few others) is shown
      on the tinted background, put the cursor on it and press Enter: the panel goes from the
      tinted view straight to the new folder - no frame of the whole parent folder in between.
- [ ] The new folder is untinted and the directory line shows no `Search:` text.
- [ ] Press Backspace: the parent folder is shown with the cursor on the folder just opened.
- [ ] Repeat with a double click on the found folder and with Ctrl+PageDown: the same.

## Log

- 2026-11-01 — created (source leftover:376)
