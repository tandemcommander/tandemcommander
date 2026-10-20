---
title: Archives: long member names refused by the cache, long folders skipped
type: bug
status: in-progress
severity: 4
area: archives
source: review:222
who: agent
created: 2026-10-15
updated: 2026-10-20
verified: 2026-10-20 b8d1f7d0
effort: M
feature: 260
related: []
depends-on: []
reason: -
---

# Archives: long member names refused by the cache, long folders skipped

## Problem

Left by the review of feature 222 (names up to 255 UTF-16 units): F3 / F4 of such names are refused by the disk cache's folder limit; folders over 255 bytes in archives are skipped (the listing skips a too-long item); tar's gzip name is cut at 259 bytes and extracted under the cut name.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L709-717. Feature 222 (`specs/222-name-length-units/`, `editname222_probe.ps1`; contract note there).

## Expected

F3 / F4 of a member with a long valid name works (or the refusal names the limit); a skipped folder is reported; a gzip member name that does not fit is refused, never extracted under a cut name.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-20 — verified at b8d1f7d0: at b8d1f7d0: 222 probe LONG - F4 of a 94-unit/274-byte ZIP member refused by the disk cache (byte MAX_PATH tmp path); gunzip.cpp ORIG_NAME read into char[MAX_PATH], rest dropped; long folders already reported by every archiver
- 2026-10-20 — run started, feature 260
