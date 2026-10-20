---
title: Undelete and ZIP wrap the core's UTF-8 texts in their own code-page sentences
type: bug
status: blocked
severity: 4
area: encoding
source: leftover:127
who: agent
created: 2026-10-13
updated: 2026-10-20
verified: 2026-10-20 86b7992b
effort: M
feature: -
related: []
depends-on: []
reason: not reproduced at 86b7992b: fixed by 130 (ZIP extText), 131 (salamdr3 templates LoadStrU8), 134 (GetCommonFSOperSourceDescr UTF-8, Undelete label wide)
---

# Undelete and ZIP wrap the core's UTF-8 texts in their own code-page sentences

## Problem

Mixed templates, the rest of feature 127, point (1): `CSalamanderGeneral::GetCommonFSOperSourceDescr` (`src/zip.cpp`) and the `salamdr3.cpp` texts `IDS_NAMEUSEDFORFILE` / `IDS_CREATEDIRFAILED` hand a code-page template with a UTF-8 name to plug-ins (FTP, Undelete, ZIP) that wrap it in their own code-page sentences - one change with those plug-ins. Feature 134 made `GetCommonFSOperSourceDescr` give UTF-8 and fixed FTP; still listed later: Undelete's `dialogs.cpp:836-864` wraps the core's `GetCommonFSOperSourceDescr` (Copy / Move / Delete subjects).

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L553-556, L608-609 and L778. Features 127, 130 (`specs/130-plugin-mixed-templates/triage/undelete.md`, `zip.md`), 131, 134.

## Expected

Undelete's and ZIP's messages that include the core's subject text or `IDS_NAMEUSEDFORFILE` / `IDS_CREATEDIRFAILED` show the file name and the sentence correctly in Czech (no mojibake).

## Notes

Partly done by 134 (FTP, and the core's `GetCommonFSOperSourceDescr` now gives UTF-8). Unsure what is left for ZIP and for the two `salamdr3.cpp` texts - verify first; Undelete is named open at L778.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-20 — verified at 86b7992b: not reproduced: read at 86b7992b - core GetCommonFSOperSourceDescr UTF-8 and Undelete label read wide (134); salamdr3 IDS_NAMEUSEDFORFILE / IDS_CREATEDIRFAILED via LoadStrU8 + whole-letter copy (131); ZIP ProcessError takes extText as UTF-8 (130)
- 2026-10-20 — blocked: not reproduced at 86b7992b: fixed by 130 (ZIP extText), 131 (salamdr3 templates LoadStrU8), 134 (GetCommonFSOperSourceDescr UTF-8, Undelete label wide)
