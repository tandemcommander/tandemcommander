---
title: User Menu list commands refused when the first selected item does not fit 259 bytes
type: improvement
status: open
severity: 2
area: long-paths
source: leftover:280
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# User Menu list commands refused when the first selected item does not fit 259 bytes

## Problem

A User Menu command that handles the items as a group (`$(ListOfSelectedNames)`,
`$(ListOfSelectedFullNames)`) is still expanded with the FIRST selected item's folder and name
(for `$(FullName)`-like variables and the Initial Directory). When that first item's folder + name
has 260 or more bytes, the command is refused with "too long name" although the list itself holds
every name whole (feature 280 made the panel's full-name list whole). The same selection with a
short item sorting first runs. In a folder of 260 or more bytes the list is built but always
refused (the item's folder is the command's current folder - MAX_PATH).

## Evidence

Feature 280, review 1 NOTE (`specs/280-user-menu-long-paths/fix-log.md`, section *Review*):
`s3` holding `0<90 CJK letters>.txt` and `a.txt`, both selected, an item with
`$(ListOfSelectedFullNames)` - "too long name"; the same pair where `a.txt` sorts first - runs.
Sites at the merge of 280: `src/mainwnd4.cpp` `CMainWindow::UserMenu` (the refusal of an item of
MAX_PATH+ bytes after `getNextFile`) and `ExpandCommand2` (folder + name over 259 bytes).
Behaviour unchanged from before 280 (not a regression).

## Expected

A group command whose variables do not use the item's own name (only the lists, panel paths,
compare names) runs when the lists hold the names whole, as long as the folder it runs in fits;
otherwise "too long name" as now. Or a recorded decision that the current refusal stays.

## Notes

Low severity: only selections whose first item has a 260+ byte full name; the user can reorder
the selection. Not verified beyond the review's reproduction.

## Log

- 2026-10-21 — created (source leftover:280)
- 2026-10-21 — moved to Next position 111
