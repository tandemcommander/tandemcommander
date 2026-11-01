---
title: ISO plug-in: a UDF 2.50 image written by Windows (IMAPI2FS) does not list
type: bug
status: in-progress
severity: 5
area: archives
source: measure:356
who: agent
created: 2026-10-31
updated: 2026-11-01
verified: 2026-11-01 aac7105e
effort: M
feature: 377
related: []
depends-on: []
reason: -
---

# ISO plug-in: a UDF 2.50 image written by Windows (IMAPI2FS) does not list

## Problem

A UDF-only image of revision 2.50 (a metadata partition) written by Windows' own image writer IMAPI2FS
(`IMAPI2FS.MsftFileSystemImage`, `FileSystemsToCreate = 4`, `UDFRevision = 0x250`) does not list in the
ISO plug-in: opening it (Enter, or a whole Unpack) shows "Cannot read sector #00000000." and "Error
reading directory structure at sector #FF567539. Incomplete content of ISO image." and lists no file. The
same files written as UDF 1.02 - 2.01 list and unpack. No data is lost (the listing is marked incomplete,
an unpack with "Delete archive after unpacking" keeps the image), but the image's files cannot be
extracted. UDF 2.50 is the revision of Blu-ray discs.

## Evidence

- Feature 356 (`specs/356-uniso-udf-rest/fix-log.md`, *Probes*): probe `iso356_probe.ps1` row `N-U250`
  (seed `u250.iso` by `probe/imapiudf356.ps1 -Revision 0x250`, `a.txt` "A1") - on main at 7afab447
  (before 356) and with 356 alike: no file extracted, the two error boxes above, the image kept.
- Measured layout (`probe/udfmeasure.py`): the main descriptor sequence at sectors 32..47 holds the
  logical volume descriptor at 34 **before** the partition descriptor at 35. `CUDF::Open`
  (`src/plugins/uniso/udf.cpp`) reads the sequence in order; `ReadLVD` → `ReadPartitionMap` for a
  `*UDF Metadata Partition` map calls `ReadBlockLog(icb.Location, ...)`, which reads `PD.Start + lbNum` -
  `PD` is not read yet (start 0), so the metadata file entry is read from the wrong sector. Not verified
  in a debugger: reasoned from the order and the messages.

## Expected

A UDF 2.50 image whose logical volume descriptor precedes its partition descriptor lists and unpacks
like the UDF 2.01 image of the same files (probe row `N-U250` becomes a `C` row: `a.txt` extracted, the
image deleted with "Delete archive after unpacking"); images whose partition descriptor comes first
unchanged.

## Approach

Read the whole main descriptor sequence first and resolve the metadata partition map after the
partition descriptor is known (or defer the metadata file entry read to `ReadSupportingTables`).

## Notes

- Found while measuring feature 356 (UDF-only images); outside its scope (356 changes only whether a
  whole unpack counts as complete).
- mkudffs 2.3 refuses `--udfrev=2.50` for a plain file (`hd`), so it gives no second 2.50 sample; a real
  Blu-ray image was not available.

## Log

- 2026-10-31 — created (source measure:356)
- 2026-10-31 — moved to Next position 8
- 2026-11-01 — verified at aac7105e: reproduced at aac7105e: iso356_probe N-U250 - Cannot read sector #00000000 and directory error, nothing extracted; LVD at 34 before PD at 35
- 2026-11-01 — run started, feature 377
