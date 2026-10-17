---
title: Long paths: the remaining 259- and 519-byte limits are kept
type: tech-debt
status: rejected
severity: 3
area: long-paths
source: leftover:097
who: agent
created: 2026-10-03
updated: 2026-10-17
verified: -
effort: L
feature: -
related: []
depends-on: []
reason: decided by features 097 (2026-10-03) and 101, listed under NEXT-WORK §C Decided - not to do: the limits sit at interfaces the program does not own or that are shared - external archivers, the plug-in interface of plug-ins older than 107, the listing structure shared with plug-ins, the layout shared between instances; a longer value is refused, never cut. Reasons in `specs/097-archive-long-path/fix-log.md` and `specs/101-small-leftovers/fix-log.md`.
---

# Long paths: the remaining 259- and 519-byte limits are kept

## Problem

These limits stay: external archivers and plug-ins built for an interface older than 107 work with paths of at most 259 bytes; the inner archive path stays at 259 bytes (the listing structure is shared with plug-ins); names relative to a packed folder stay at 259 bytes (plug-in interface); the `-L`/`-R`/`-A` command-line paths and hot paths stay at 519 bytes (layout shared between instances).

## Evidence

specs/NEXT-WORK.md item 5, *An archive whose path is longer than 259 bytes could not be opened* - *Left by 097, each with its reason* (L1532-1542 at 7993914c); `specs/097-archive-long-path/fix-log.md`; `specs/101-small-leftovers/fix-log.md` (the relative path refusal at about level 129, ~L264). Migrated from specs/NEXT-WORK.md §C *Decided - not to do* (L478, at 7993914c).

## Expected

(not stated in the source)

## Notes

Not part of this decision: clipboard copy from and drop/paste into an archive with a 260+ byte name (097 said they could be widened; done by feature 160 for drop/paste).

## Log

- 2026-10-03 — feature 097: external archivers, older plug-ins and the inner path stay at 259 bytes, -L/-R/-A and hot paths at 519 bytes
- 2026-10-17 — migrated from specs/NEXT-WORK.md §C and 'Recorded, deliberately not on the list' (feature 242)
