---
title: ISO plug-in: a crafted UDF partition map count reads past the descriptor buffer
type: bug
status: open
severity: 5
area: archives
source: review:377
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: 2026-11-01 514396d3
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: a crafted UDF partition map count reads past the descriptor buffer

## Problem

A damaged or crafted UDF disc image whose logical volume descriptor declares more partition maps than its
sector holds (or maps whose length byte is 0) makes the ISO plug-in read past the 2048-byte sector buffer on
the stack of `CUDF::Open` while the image is opened (Enter, Unpack); a map length of 0 with a huge count
allocates one `CPartitionMap` per declared map without moving on (memory and time without a bound).

## Evidence

- `CUDF::ReadLVD` (`src/plugins/uniso/udf.cpp` at 46961e17): `mapCount = GET_DWORD(sector, 268)` from the image,
  `for (i = 0; i < mapCount; i++) offset += ReadPartitionMap(sector + offset);` - neither `mapCount` nor
  `offset` is bounded by the sector (or by the map table length `mapLen` at 264, read and unused);
  `ReadPartitionMap` returns the map's own length byte (`GET_BYTE(data, 1)`) and reads up to 64 bytes of it.
- Found by the refute-first review of feature 377 (`specs/377-uniso-udf-metadata-order/fix-log.md`, *Review*,
  NOTE N1); older than 377 (the loop is unchanged), not measured.

## Expected

Partition maps are read only inside the descriptor sector and the declared map table length; a count or a
map length that does not fit (or a map length of 0) is refused - the volume does not open (the track counts
as not opened, the listing is marked, a whole unpack keeps the image), never a read past the buffer.

## Notes

- Not measured: reasoned from the code by the review. A probe can craft it from an IMAPI2FS image
  (`specs/377-uniso-udf-metadata-order/probe/img377.py` shows how to change the LVD and fix its CRC).
- Pure rule candidate for `src/common/` (in the style of 360 / 361's `salisoudf*.h`).

## Log

- 2026-11-01 — created (source review:377)
- 2026-11-01 — moved to Next position 1
- 2026-11-01 — verified at 514396d3: present at 514396d3: ReadLVD loop unbounded by sector and table; crafted IMAPI2FS images made, GUI probe waits for the user TC to close
