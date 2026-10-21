---
title: Renamer: the New name field holds only 519 bytes of a typed pattern
type: improvement
status: open
severity: 2
area: long-paths
source: leftover:282
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Renamer: the New name field holds only 519 bytes of a typed pattern

## Problem

Feature 282 (branch 282-renamer-long-new-name, blocked - not merged) makes the Renamer build a new
name of any length the file system accepts, but even then the pattern typed into the New name field is still limited to 519 bytes of UTF-8 (Search for 519,
Replace with 259): a literal new name of 175+ CJK letters (or a relative path "L\L.txt" of two
90-letter names, 545 bytes) is refused by the field itself with the system text of error 206 ("The
file name or extension is too long"). Refused, never cut; a long name is still reachable through the
pattern's variables (`$(Name)` etc.).

## Evidence

Measured in feature 282 (`specs/282-renamer-long-new-name/fix-log.md`, *Measured (before)*, "Probe
traps met"): the first long-rel row with "L\L.txt" got a "Batch Rename" box with the 206 text and
nothing renamed. Sites at the head of branch 282-renamer-long-new-name: `src/plugins/renamer/crenamer.h`
`CRenamerOptions::NewName[2 * MAX_PATH]`, `SearchFor[2 * MAX_PATH]`, `ReplaceWith[MAX_PATH]`,
`CRenamer::ReplaceWith[MAX_PATH]`; `rendlg.cpp` `Transfer` (`ti.EditLine(IDC_NEWNAME, ...,
2 * MAX_PATH)` and the histories); `renamer.cpp` `LoadHistory(..., 2 * MAX_PATH)`; `crenamer.cpp`
`CRenamerOptions::Load` (`GetValue(..., 2 * MAX_PATH)`).

## Expected

The New name field (and Search for / Replace with) accepts a pattern as long as the longest name
it can produce needs - at least the longest component (255 UTF-16 units, 765 bytes) plus room for a
relative path - stored, loaded and kept in its history at that length; a longer one refused as now.

## Notes

The stored values keep their registry names; only longer strings are written - no layout change,
but an older build reading a longer value fails to load it (its `GetValue` with 520 bytes) -
check how `GetValue` behaves then before raising the size.

## Log

- 2026-10-21 — created (source leftover:282)
- 2026-10-21 — moved to Inbox
- 2026-10-21 — moved to Next position 93
