---
title: Case-sensitive folders: several features take the first case-insensitive twin
type: bug
status: open
severity: 4
area: panels-ui
source: leftover:232
who: agent
created: 2026-10-15
updated: 2026-10-20
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Case-sensitive folders: several features take the first case-insensitive twin

## Problem

Left from features 230-232 (a.txt and A.txt in a case-sensitive folder): Compare Directories may pair the wrong twin in case-sensitive folders (compare with `CmpNameExt` when both panels are case-sensitive); remembered folder sizes are case-insensitive (`salamdr6.cpp:1148/1196`, `stricmp`); the viewer's next / previous file (`fileswnb.cpp:1211/1217`), the User Menu's compare names (`mainwnd3.cpp:2829`) and Ctrl+X greying in the other panel (`shellsup.cpp:1934/1949`) take the first case-insensitive twin. Also (upstream): in Turkish / Azeri locales "index.html" / "INDEX.HTML" never compare equal.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L738-751. Features 230, 231, 232 (`specs/232-compare-dirs-case-only-names/`).

## Expected

In a case-sensitive folder each of the listed features addresses the exact twin; Compare Directories pairs a.txt with a.txt.

## Notes

The Turkish / Azeri comparison is upstream behaviour (rule 092 uses ordinal CI) - possibly to park. A timed listing on an SMB share is a person step (`real-file-server-person-rows`).

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-20 — related item archive-plugins-declare-case-sensitivity done in feature 252
