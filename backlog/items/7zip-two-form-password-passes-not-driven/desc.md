---
title: 7-Zip: two-form password passes in Test, F3 view, Delete and Cancel not driven
type: tech-debt
status: open
severity: 2
area: archives
source: leftover:093
who: agent
created: 2026-10-02
updated: 2026-10-17
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# 7-Zip: two-form password passes in Test, F3 view, Delete and Cancel not driven

## Problem

Feature 093 made the 7-Zip plug-in's password Unicode and kept a fallback to the old (code-page) password form: an extract runs a first pass, a retry pass for items refused under one form and a redo pass. Its probe drove the panel session through F5 only. Not driven: (1) Cancel during the test of a large item (the poll through WM_7ZIP_POLLCANCEL / ProgressAddSize(0)) and Cancel during any pass; (2) the passes in Test archive and in F3 view, and Delete from archive; (3) RAR archives under such a password. Recorded costs with it: the test decodes the cheapest encrypted item once more (up to six tests when everything is refused) with the progress bar standing still, during an update on the main thread; a damaged item under a two-form password is decoded up to three times (the first pass's partial file is deleted and written again, the keep-or-delete question as before).

## Evidence

specs/093-unicode-dialogs/fix-log.md, section 'S2 - the 7-Zip password', 'Not driven / open' (~lines 395-410), points 1-3. NEXT-WORK §5, B-1, bullet '7zip plugin' (L1982-1985). Functions named there: extract.h/.cpp CryptoGetTextPassword, BeginRetryPass, BeginRedoPass, EndRetryPass; 7zclient.cpp TestPassword, ChooseForm, TestArchive, Decompress. The engine is 7-Zip 26.03 with RAR/RAR5 since feature 087. Migrated from specs/NEXT-WORK.md §5 (at 7993914c).

## Expected

A probe drives Test archive, F3 view, Delete from archive and Cancel in each pass on a 7z archive whose password has letters outside ASCII (and on a RAR archive if one can be made); every row passes, or each defect found becomes an item of its own.

## Approach

Extend the 093 probe (specs/093-unicode-dialogs/probe/); Cancel can be pressed by BM_CLICK on the progress window's button on the hidden desktop. Making a RAR archive needs rar.exe (WinRAR); without it the RAR row is owed to a person.

## Notes

Unsure whether still open: later features (094, 113, 131 and others touching the 7-Zip plug-in) may have driven some rows - check their probes first. A 7z archive mixing the two password forms stays mixed - decided (NW §C 'Formats and old forms'), not part of this item.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §5–§8 (feature 242)
