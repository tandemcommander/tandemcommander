---
title: Unpack into a subfolder named after an archive whose name starts with a space drops the space
type: bug
status: in-progress
severity: 4
area: archives
source: review:315
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: 2026-10-23 b125acf7
effort: S
feature: 316
related: []
depends-on: []
reason: -
---

# Unpack into a subfolder named after an archive whose name starts with a space drops the space

## Problem

With "Use the archive name as a subfolder" on, the Unpack dialog (Alt+F9) offers the archive's
name as a relative subfolder (for example when the other panel is not a disk, or since feature 315
when the other panel's path + the name do not fit). For an archive whose name starts with a space
(` ssss.zip`) the entry shows ` ssss`, but OK unpacks into `ssss`: `SalGetFullName` strips leading
spaces of the relative name. The files land in another folder than the one shown (an existing
`ssss` folder is merged into; overwrite questions are still asked).

## Evidence

Review 1 of feature 315 (branch `315-unpack-default-whole`), a scratch hidden-desktop row
`subdir-space`: archive ` ssss....zip`, UA=1 SD=1, the other panel 245 bytes: the entry offered
was 21 characters (with the space), the files were unpacked into the 20-character folder. Sites:
`CFilesWindow::Unpack` (`src/fileswn7.cpp`, the empty-entry branch after `CUnpackDialog`) and
`SalGetFullName` (`src/salamdr3.cpp`, the loop skipping characters <= ' ' at the start). Already
reachable before 315 with "Use the other panel" off.

## Expected

OK unpacks into the folder the entry shows (the leading space kept), or the program refuses with a
message - never a differently named folder. A probe row with such an archive, before FAIL / after
PASS.

## Log

- 2026-10-23 — created (source review:315)
- 2026-10-23 — related item unpack-dialog-offers-a-long-target-panel-path-cut-and done in feature 315
- 2026-10-23 — auto-triage: severity 3 -> 4: a function gives a wrong result (unpacks into another folder than the one shown), a workaround exists
- 2026-10-23 — moved to Next position 2
- 2026-10-23 — verified at b125acf7: reproduced at b125acf7: hidden-desktop probe unpack316, 4 relative rows with a leading space unpacked into the folder without it (5 FAIL / 9)
- 2026-10-23 — run started, feature 316
