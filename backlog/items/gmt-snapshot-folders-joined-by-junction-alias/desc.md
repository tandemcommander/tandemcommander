---
title: Two @GMT snapshot folders joined by a junction could hide a folder alias
type: bug
status: parked
severity: 3
area: data-safety
source: review:107
who: both
created: 2026-10-04
updated: 2026-10-17
verified: -
effort: ?
feature: -
related: []
depends-on: []
reason: reasoned in feature 107's re-check, not reproducible without snapshots (agent sessions have no admin rights to create them)
---

# Two @GMT snapshot folders joined by a junction could hide a folder alias

## Problem

Feature 107 decides by folder identity whether a copy or move goes into the folder itself, and gives a path a snapshot tag (an @GMT- component, or a HarddiskVolumeShadowCopyN component of the final path) so that a live folder and its snapshot are not one. Two differently named @GMT folders joined by a junction could give the two sides different tags - a missed alias. Before 107 a move into itself through an alias deleted empty subfolders or moved the whole content one level down (nothing lost, the tree gone). Recorded with it: on FAT, two views reporting different times would miss an alias (reasoned).

## Evidence

specs/107-folder-alias-move/fix-log.md ~lines 232-235, 'Recorded (re-check NITs)'; CSalFileIdentity::SnapshotTag / SalSnapshotTagFromPath (fix-log ~line 28). NEXT-WORK §5 L1311-1312. Migrated from specs/NEXT-WORK.md §5 (at 7993914c).

## Expected

Either reproduced with real snapshots and refused like every other alias, or shown impossible.

## Approach

Needs a machine with volume shadow copies (admin) - ties in with NW §B 'Environment or hardware' (snapshots and FAT volumes, 107).

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §5–§8 (feature 242)
