---
title: ISO plug-in: an unknown UDF partition map type leaves its translation undefined
type: bug
status: open
severity: 3
area: archives
source: review:378
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: an unknown UDF partition map type leaves its translation undefined

## Problem

A UDF disc image whose logical volume descriptor holds a partition map of a type the ISO plug-in does not know
(a type other than 1 or 2), or a type 2 map whose identifier is none of the virtual / sparable / metadata
partitions, gets a partition map whose kind is never set: the plug-in then translates every block of that
partition by an undefined value (Debug builds: the heap fill 0xCDCDCDCD; Release: whatever the heap held).
Depending on that value the partition is read as physical, virtual, sparable, metadata or not at all - the
listing of such a damaged or unusual image is not predictable.

## Evidence

- `CUDF::ReadPartitionMap` (`src/plugins/uniso/udf.cpp` at 8548919e on branch 378-uniso-udf-partition-maps;
  unchanged from main 514396d3): `partMap->Type` is set only in `case 1` and in the three recognised type 2
  identifiers; the `switch (partType)` has no `default`, the type 2 branch no `else`; then
  `PartitionMapping.Type = partMap->Type` copies it. `CUDF::LogSector` switches on `PartitionMaps[part]->Type`;
  `ReadSupportingTables` switches on it too.
- Found by the refute-first review 2 of feature 378 (`specs/378-uniso-udf-partition-maps/fix-log.md`,
  *Review*, NOTE 3); review 1 of 377 noted the unset type already (377 then guarded only the metadata read with
  `HasMetadataFile`). Since 378 such maps are accepted when they fit the descriptor (length >= 2). Not
  measured.

## Expected

A partition map of an unknown kind gets a defined kind: the volume either does not open (refused, the listing
marked as for 378's refusal) or that partition's blocks are never translated (a read through it fails and the
listing is marked) - never a translation by an undefined value. Well-formed images list as before.

## Notes

- Candidate: a `mapUnknown` value set by default in `ReadPartitionMap`, with `LogSector` returning
  `INVALID_SECTOR_NUMBER` for it; 377's review chose not to set a default type because it would change how
  an unknown map translates - with an undefined value there is no defined behaviour to keep. Not verified.
- A probe can craft it with `specs/378-uniso-udf-partition-maps/probe/img378.py` as a model (change the map's
  type byte of an IMAPI2FS image).

## Log

- 2026-11-01 — created (source review:378)
- 2026-11-01 — related cleared (set by mistake at creation)
- 2026-11-01 — moved to Next position 86
