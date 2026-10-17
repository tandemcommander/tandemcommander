---
title: File masks fold accented letters through the code page
type: bug
status: open
severity: 3
area: encoding
source: review:068
who: agent
created: 2026-08-24
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [archive-listing-display-encoding]
depends-on: []
reason: -
---

# File masks fold accented letters through the code page

## Problem

The panel's mask matcher folds UTF-8 name bytes through the code-page `LowerCase` table (068 finding F-P3-06, `acp-byte-table-on-name`), so a mask with an accented letter can miss the other case of that letter (e.g. a lower-case accented letter in the mask against an upper-case one in the name). 068 found `AgreeMask`'s path itself correct (ASCII fast path, else NFC + wide match); the byte-table sites are the other matching functions and the extension hash. The mask matcher was left out of B-2's identity work (092).

## Evidence

Migrated from specs/NEXT-WORK.md §A item 19 (L414) and §5 (L1935) (at 7993914c). specs/068-encoding-regression-review/findings/P7.md (~line 233, F-P3-06 `masks.cpp:49,52,327`), findings/P3.md (S-X-P3-031: `AgreeMask` verified correct); specs/069-finish-encoding-fixes/REMAINING-WORK.md §1. At 7993914c: `src/masks.cpp` ~52, ~56, ~227 (`LowerCase[*filename] == LowerCase[*mask]`), ~391-396 (the extension hash).

## Expected

Masks match names by whole letters with the file system's case rule (or each remaining byte site proven unreachable for UTF-8 names), with saltests checks.

## Approach

Measure first which callers reach the byte-table functions with UTF-8 names (selection masks, Find, filters, associations); the B-2 decision of 2026-10-04 (NW §C) left the systemic comparison as is - confirm the mask matcher is outside it (NW §5 L1935 says so).

## Notes

Unsure how much is reachable: 068 marked `AgreeMask` correct; the item may shrink to the hash and one function after measuring.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
