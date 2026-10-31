# Data model - 356-uniso-udf-rest

All in `src/common/salisotrack.h`; sectors are 2048 bytes; offsets per ECMA-167 3/7.2 (tag) etc.

- **Descriptor tag** (bytes 0-15 of a descriptor): identifier (0-1 LE), checksum (4), location (12-15
  LE). Valid for (`id`, `at`) when the identifier is `id`, the checksum matches and the location is `at`.
- **SalIsoUdfAnchor**: main sequence extent (length 16-19, location 20-23), reserve extent (24-27,
  28-31) of an anchor descriptor (tag 2). Two anchors are of one volume when all four values are equal.
- **Partition descriptor** (tag 5): start (188-191), length (192-195); end = start + length.
- **Logical volume descriptor** (tag 6): map table length (264-267), map count (268-271), maps from 440;
  a type-2 map (byte 0 = 2, byte 1 = its length) whose entity identifier (bytes 5..27 of the map) begins
  `*UDF Virtual Partition` makes the volume a VAT volume.
- **File entry** (tag 261) / **extended file entry** (tag 266): its location is partition-relative.
- **SalIsoUdfVolume**: `anchorKnown`, `anchor`, `partitionKnown`, `partitionStart` (of the first
  partition descriptor), `descriptorsEnd` (max of 257, both sequences' ends, every partition's end),
  `closedAtEnd` (the file closes with this volume's anchor or, VAT, file entry).
- **Decision** (`SalIsoUdfRestDecision`): unknown anchor or partition → MARK; `closedAtEnd` → the
  volume size is the file's whole sectors (KEEP); else `SalIsoCookedRestDecision(true, true,
  descriptorsEnd, fileSize, ...)` → KEEP / MARK / CHECK (checkFrom, checkBytes).
- **Rest sector** (`SalIsoUdfRestSectorEmpty`): zero bytes only, or a whole sector holding an anchor of
  the volume at its own location.
