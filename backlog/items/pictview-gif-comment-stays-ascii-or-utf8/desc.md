---
title: PictView: the GIF comment stays ASCII or UTF-8
type: improvement
status: rejected
severity: 1
area: pictview
source: measure:111
who: agent
created: 2026-10-06
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: feature 120, 2026-10-06 (listed under NEXT-WORK §C Decided - not to do): GIF89a defines the comment extension as 7-bit ASCII and has no Unicode alternative; the comment stays ASCII or UTF-8.
---

# PictView: the GIF comment stays ASCII or UTF-8

## Problem

PictView writes UTF-8 bytes into the GIF comment extension although GIF89a defines 7-bit ASCII; there is no Unicode alternative in GIF. Found by 111 as (c), decided by 120.

## Evidence

specs/NEXT-WORK.md item 5, *Found by 111, not fixed* (c) and *(a)-(c) fixed or decided by feature 120* (L1670-1676 at 7993914c); `specs/120-pictview-leftovers/fix-log.md`, `specs/111-pictview-shown-image/fix-log.md`. Migrated from specs/NEXT-WORK.md §C *Decided - not to do* (L488, at 7993914c).

## Expected

(not stated in the source)

## Log

- 2026-10-06 — feature 120: GIF comment stays ASCII or UTF-8 (decided)
- 2026-10-17 — migrated from specs/NEXT-WORK.md §C and 'Recorded, deliberately not on the list' (feature 242)
