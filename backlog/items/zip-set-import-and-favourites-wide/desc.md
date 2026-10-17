---
title: ZIP: a code-page .set file that looks like UTF-8 is misread on import
type: bug
status: open
severity: 3
area: archives
source: leftover:131
who: agent
created: 2026-10-13
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ZIP: a code-page .set file that looks like UTF-8 is misread on import

## Problem

Left by feature 131: an imported code-page `.set` file (self-extractor settings, `iosfxset.cpp`) whose bytes happen to be valid UTF-8 is misread on import; the wide messages to controls of an `A` dialog (favourites) were not seen running - a CJK name is the test.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L774-776. `specs/131-plugin-defect-batch/items/zip.md` (rows 1, 4), `fix-log.md` section 6.

## Expected

A code-page `.set` is imported with its own letters; the favourites dialog shows and keeps a CJK favourite name (driven by a probe).

## Notes

The self-extractor routes stay code page by decision (NW §C); the `.set` import is reachable from the ZIP plug-in's settings.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
