---
title: Change Attributes on a junction compresses / re-times the target folder
type: bug
status: open
severity: 5
area: data-safety
source: leftover:213
who: agent
created: 2026-10-15
updated: 2026-10-17
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Change Attributes on a junction compresses / re-times the target folder

## Problem

Left by feature 213: the link's own Change Attributes operation reaches the target FOLDER - for compression `worker.cpp` 1645 / 1683 open without `FILE_FLAG_OPEN_REPARSE_POINT`; for the times `DoChangeAttrs` ~8125; probably encryption too.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L788-793. Feature 213 (`specs/213-attrs-case-links/`, `attrs_case_link_probe.ps1`).

## Expected

Change Attributes on a junction / directory symbolic link changes only the link (or refuses what a link cannot take); the target folder's compression, times and encryption stay.

## Notes

Encryption is "probably" affected per the source - measure. The walk into the target was fixed by 213; this is the link's own entry.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
