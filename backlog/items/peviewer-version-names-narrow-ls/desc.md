---
title: PE Viewer: version-resource names printed with a narrow %ls (suspected)
type: bug
status: open
severity: 2
area: other-plugins
source: leftover:129
who: agent
created: 2026-10-13
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [decide-peviewer-dump-utf8-with-bom]
depends-on: []
reason: -
---

# PE Viewer: version-resource names printed with a narrow %ls (suspected)

## Problem

`peviewer/pefile.cpp:1819/2317/2499` prints version-resource names with a narrow `%ls`: a name with a letter above U+00FF is dropped or cut in the dump - suspected, measure first.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L593-597 (left from feature 129, `specs/129-regedt-wide-inserts/`).

## Expected

A version-resource name with letters above U+00FF appears whole in the dump (as `?` per letter outside the code page at worst, per the dump decision), not dropped or cut.

## Notes

Suspected, not measured (the source says "measure first"). The UTF-8 dump decision would change the fix.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
