---
title: Copying a folder into itself or its own subfolder makes a snapshot copy
type: improvement
status: rejected
severity: 2
area: data-safety
source: leftover:107
who: agent
created: 2026-10-04
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [identity-limits-without-file-ids]
depends-on: []
reason: feature 107, 2026-10-04: recorded under Decisions recorded (spec.md) in specs/107-folder-alias-move/fix-log.md L142-145 and listed under NEXT-WORK §C Decided - not to do: a folder COPY into itself or its own subfolder stays a snapshot copy (by name and through an alias alike, as before); nothing is lost, the script is built before anything is written - only Move into itself is refused.
---

# Copying a folder into itself or its own subfolder makes a snapshot copy

## Problem

F5 of a folder into itself or into one of its own subfolders copies a snapshot of the folder there instead of being refused (a Move into itself is refused since 107).

## Evidence

specs/NEXT-WORK.md item 5, the 107 entry, *Found by 107, decided or small (no loss)* (L1296-1298 at 7993914c: "a decision to confirm"); `specs/107-folder-alias-move/fix-log.md`. Migrated from specs/NEXT-WORK.md §C *Decided - not to do* (L493, at 7993914c).

## Expected

(not stated in the source)

## Notes

Item 5 called it "a decision to confirm"; §C lists it as decided. No dated maintainer confirmation was found in the source.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §C and 'Recorded, deliberately not on the list' (feature 242)
- 2026-10-17 — migration review N6: reason cites the recorded decision of 107
