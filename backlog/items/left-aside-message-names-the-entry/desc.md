---
title: The left-aside message names only the salNNN entry, not the entry it was
type: improvement
status: open
severity: 3
area: file-ops
source: review:281
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

# The left-aside message names only the salNNN entry, not the entry it was

## Problem

When an entry moved aside for an 8.3 clash cannot be moved back, the user is told
"Error Renaming File - Path: "...\salNNN" - Error: <reason>" (Quick Rename and the worker's move
since 221, every create route since 281). The message names only the temporary entry, not the
entry it was ("longfilename.txt"): the user learns that some file now sits under `salNNN`, but
has to open it to find out which one, and what name to give it back.

## Evidence

- Feature 281's final code (branch 281-moved-aside-leftovers, after its review 1): `FormatMovedAsideLeft` / `ReportMovedAsideLeft`
  in `src/salamdr3.cpp` use `IDS_PATHERRORFORMAT` ("Path: ""%s""\nError: %s", one path); the
  worker sends the same text through `WM_USER_DIALOG` 13 (`ReportMovedAsideLeftWorker`,
  `src/worker.cpp`); Quick Rename (`src/fileswn5.cpp`, `RenameFileInternal`, feature 221) the same.
  The original full name (`origFullName`) is known at every site.
- Independent review of 281 (SHOULD 2): the backlog item behind 281 asked to tell "which entry was
  left under which salNNN name"; 221's review had kept the one-path form for the same reason ("the
  existing string has one path").
- No existing string names two paths for this (searched `src/lang/texts.rc2` for rename strings).

## Expected

The message names both: the entry's own full name and the `salNNN` path it stays under, with the
reason - e.g. ""longfilename.txt" could not get its name back; it is now "...\salNNN"". Paths
whole (never cut).

## Approach

A new string in a free slot of an existing bundle (CLAUDE.md: new UI strings need the two-stage
`.slt` refresh, `translate.merge --templates`); `CMovedAsideLeft` gets the original name next to
the path; the core sites and PictView / Renamer (their own boxes) use it.

## Notes

Severity 3: nothing is lost and the path is shown - a clearer message. Needs the translation
refresh, which an autonomous run does not do - a run would stop on it.

## Log

- 2026-10-21 — created (source review:281)
- 2026-10-21 — related item moved-aside-restore-leftovers done in feature 281
- 2026-10-21 — moved to Next position 47
