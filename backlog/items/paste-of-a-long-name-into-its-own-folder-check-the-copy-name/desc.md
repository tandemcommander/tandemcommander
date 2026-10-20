---
title: Paste of a long name into its own folder: check the copy name and the too long question
type: person-step
status: new
severity: 5
area: long-paths
source: leftover:259
who: person
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Paste of a long name into its own folder: check the copy name and the too long question

## Problem

Feature 259 rebuilt the "- Copy" naming of Paste into the item's own folder (it dropped a copy name of 260+ bytes and then said "Cannot copy a file to itself."). The new rule is covered by unit checks, but the paste itself needs the clipboard, which the hidden-desktop probes do not drive - nobody has seen the fixed Paste work in the program yet.

## Evidence

Feature 259 (`specs/259-long-name-refusals/`): `quickstart.md` step 5, `fix-log.md` *Measured after* ("Paste in its own folder and the multi-item Skip: NOT DRIVEN (clipboard)") and *Review* (SHOULD 1). Code: `src/fileswn6.cpp` `CFilesWindow::BuildScriptMain2` (the copy-name loop and the `copyNameTooLong` question), rule `src/common/salcopyname.h` (`TestCopyName259` in saltests).

## Expected

Every step below checked on a Debug or Release build of feature 259 or later; a failing step becomes a bug item.

## Steps

- [ ] In a short folder create a file named 84 CJK letters + ".txt" (for example 84 times "中" + ".txt", 256 bytes of UTF-8). Select it, Ctrl+C, Ctrl+V in the same panel → a file "<the 84 letters> - Copy.txt" appears beside it; no "Cannot copy a file to itself." Ctrl+V again → "... - Copy (2).txt".
- [ ] In the same folder create a file of 250 letters "a" + ".txt". Ctrl+C, Ctrl+V → the box "Name "..." with full path is too long." with Skip / Skip all / Focus / Cancel appears; Cancel → no new file, the folder unchanged; never "Cannot copy a file to itself."
- [ ] Select both files (the 84-letter one and the 250-letter one), Ctrl+C, Ctrl+V, answer Skip → the 84-letter file gets its next copy, the 250-letter one does not; nothing else changes.
- [ ] Ctrl+C, Ctrl+V of an ordinary short file "a.txt" and of a folder "f" in their own folder → "a - Copy.txt" and "f - Copy" as before.

## Log

- 2026-10-20 — created (source leftover:259)
