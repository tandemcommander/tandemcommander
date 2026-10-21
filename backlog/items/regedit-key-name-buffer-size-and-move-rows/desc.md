---
title: Registry Editor: fs3.cpp passes a third of the key-name buffer size
type: bug
status: open
severity: 3
area: other-plugins
source: leftover:129
who: agent
created: 2026-10-13
updated: 2026-10-21
verified: 2026-10-21 243174e4
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Registry Editor: fs3.cpp passes a third of the key-name buffer size

## Problem

Left from feature 129: `regedt/fs3.cpp:218` passes `MAX_KEYNAME` as the size of a `3 * MAX_KEYNAME` buffer (a long key name with non-ASCII letters may be refused or cut although it fits); Move of a key and the "class name differs" question were not driven.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L597-598. Feature 129 (`specs/129-regedt-wide-inserts/fix-log.md`).

## Expected

`fs3.cpp:218` passes the real buffer size; a probe drives Move of a key and the "class name differs" question with a Czech key name.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-21 — verified at 243174e4: partly: fs3 buffer size fixed by 131; class-name question unreachable (fs5 queries the source key twice); Move and the question not driven
