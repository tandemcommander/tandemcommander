---
title: ISO plug-in: a UDF folder of several blocks in a VAT partition is read past its mapping
type: bug
status: open
severity: 3
area: archives
source: review:364
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: [iso-plug-in-a-udf-vat-whose-descriptors-cover-less-than-its]
depends-on: []
reason: -
---

# ISO plug-in: a UDF folder of several blocks in a VAT partition is read past its mapping

## Problem

The UDF folder walk translates only the first block of each folder extent and reads the following blocks physically in sequence, which is wrong where a partition maps every block on its own (VAT, metadata).

## Evidence

- Review 1 of feature 364 (`specs/364-uniso-udf-folder-extents/fix-log.md`, *Review*, NOTE 4), branch
  `364-uniso-udf-folder-extents` at 2e9c8cbc: `CUDF::ReadFolderWindow` (`src/plugins/uniso/udf.cpp`) computes
  `LogSector(folder.Ext[e].Location, folder.Ext[e].Partition) + block` and reads the window with `ReadBlockPhys` -
  only the extent's first block goes through `CUDF::LogSector`. For a virtual partition (`mapVirtual`) `LogSector`
  translates each block through the VAT (`PartitionMapping.Translation[lbNum]`), so consecutive virtual blocks of a
  folder need not be consecutive physical sectors.
- The same holds before feature 364 for the first extent (`ScanDir` stepped `++lbNum` on the physical number);
  feature 364 only extends it to later extents.
- `LogSector` returns `INVALID_SECTOR_NUMBER` (-11111111) for a block the VAT does not translate; `ReadBlockLog`
  refuses that value, but the folder walk passes it (plus the block offset) to `ReadBlockPhys`, which adds
  `PD.Start` and reads whatever sector the wrapped number gives.
- Not measured: every mkudffs VAT image of features 356 - 360 has single-block folders (the probes pass); a VAT
  folder larger than one block was not built.

## Expected

Each folder block is translated on its own (and an untranslatable block refused like a read error), or a folder
that cannot be read so is refused and the listing marked incomplete (feature 330).

## Notes

- Whether `CUDF::UnpackFile` has the same pattern for a file's blocks in a VAT partition was not verified.
- Probably reachable only on packet-written media whose folders grew past one block after rewrites.

## Log

- 2026-11-01 — created (source review:364)
- 2026-11-01 — moved to Next position 86
