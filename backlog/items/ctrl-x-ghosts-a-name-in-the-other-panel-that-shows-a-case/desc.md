---
title: Ctrl+X ghosts a name in the other panel that shows a case twin folder
type: bug
status: new
severity: 2
area: panels-ui
source: review:261
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Ctrl+X ghosts a name in the other panel that shows a case twin folder

## Problem

Under a case-sensitive parent folder holding the folders `Sub` and `SUB`, the left panel shows
`Sub`, the right `SUB`. Ctrl+X on a file in the left panel also ghosts (marks as cut) the file of the
same name in the right panel - another folder, another file. Cosmetic (only the ghosted look; the
clipboard holds the right file), but the same family as feature 261.

## Evidence

By reading (review 2 of feature 261, NOTE N2 of review 1) at 0e151c5a, branch
261-case-twins-exact-match: `src/shellsup.cpp` `ShellAction`, `saCutToClipboard`: `samePaths` is
`SalPathEqualOrdinalCI(panel->GetPath(), anotherPanel->GetPath())` (~1910); with `samePaths` the
item of the same name in the other panel gets `CutToClip = 1` (~1930-1950).

## Expected

"The same folder" of the two panels is decided by identity (`src/common/salsamefile.h`, features
103 / 106) or byte-equal paths, so twin folders are never taken for one; Ctrl+X in one of them does
not ghost anything in the other. A hidden-desktop probe cannot drive the clipboard - a person step
or a seam.

## Log

- 2026-10-20 — created (source review:261)
