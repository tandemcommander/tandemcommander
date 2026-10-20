---
title: Long names: Paste "- Copy" says "to itself"; IsSimpleSelection uses CP_ACP
type: bug
status: in-progress
severity: 4
area: long-paths
source: review:215
who: agent
created: 2026-10-15
updated: 2026-10-20
verified: 2026-10-20 7a13bdee
effort: M
feature: 259
related: []
depends-on: []
reason: -
---

# Long names: Paste "- Copy" says "to itself"; IsSimpleSelection uses CP_ACP

## Problem

Core leftovers of the long-name audits (215, 222): Paste "- Copy" naming says "cannot copy to itself" for names of about 250 bytes; Edit New File is limited to paths under 260 bytes (refused now, was cut); `IsSimpleSelection`'s too-long message and its `CP_ACP` fallback (`shellib.cpp` ~497-510).

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L702-704 and L755-756. Features 215, 222 (`specs/222-name-length-units/`).

## Expected

Paste of a ~250-byte name in its own folder either creates the "- Copy" name or refuses with "too long name"; Edit New File accepts long paths or the limit is stated; `IsSimpleSelection` never converts through `CP_ACP` and says "too long" correctly.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-20 — verified at 7a13bdee: at 7a13bdee: Edit New File probe 3 FAIL (288-byte folder, 294-byte path, 304-byte CJK name refused too long); Paste copy name and IsSimpleSelection CP_ACP fallback by reading
- 2026-10-20 — run started, feature 259
