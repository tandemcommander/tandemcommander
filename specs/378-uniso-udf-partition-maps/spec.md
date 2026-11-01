# Feature Specification: A UDF volume whose partition maps do not fit its descriptor does not open

**Feature Branch**: `378-uniso-udf-partition-maps`
**Created**: 2026-11-01
**Status**: Draft
**Input**: Backlog item iso-plug-in-a-crafted-udf-partition-map-count-reads-past-the (backlog/items/iso-plug-in-a-crafted-udf-partition-map-count-reads-past-the/desc.md) - implement exactly what it describes. From backlog item iso-plug-in-a-crafted-udf-partition-map-count-reads-past-the.

## Background

A UDF disc image names its partitions in the partition map table of its logical volume descriptor: a
table length (byte 264), a map count (byte 268) and, from byte 440, the maps one after another, each
giving its own length in its second byte. The ISO plug-in reads that table while it opens the image
(Enter on it, a whole Unpack with Alt+F9) and takes as many maps as the count says, moving on by each
map's own length, without comparing either with the 2048-byte sector it holds or with the table length.
A damaged or crafted image whose count is larger than the maps in the sector, or whose map length is 0,
makes the reader read past its sector buffer (bytes of other data taken as partition maps; far enough,
an access violation), and with a map length of 0 it records one partition map per declared map without
moving on - up to four billion of them (memory and time without a bound).

Measured at `514396d3`: the reading code is unchanged at HEAD; reachable from Enter / Alt+F9 on any image
whose track is UDF or ISO 9660 + UDF (the ISO plug-in is on in the default build). Crafted images were
derived from images written by Windows' IMAPI2FS (one partition map of 6 bytes, table length 6).

## Clarifications

### Session 2026-11-01

- Q: Which message does the user see when the volume is refused? → A: the plug-in's existing "Error reading directory structure at sector #%08X. Incomplete content of ISO image." with the descriptor's sector - no new text, no translation change (autonomous run: conservative)
- Q: A table length that reaches past the sector, while every declared map lies inside the sector? → A: the maps are read inside the smaller of the two bounds; such a volume opens as before when its maps fit (autonomous run: conservative - keeps the behaviour for a case the item does not name)
- Q: How long must a map be? → A: at least its two header bytes, and at least the bytes the reader takes from a map of its type (type 1: 6, type 2: 44); a map length of 0 or 1 is refused (autonomous run: item - "a map length that does not fit (or a map length of 0) is refused")
- Q: A map count of 0? → A: unchanged (no map is read; the volume behaves as today) (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A damaged partition map table is refused, never read past (Priority: P1)

A user opens or unpacks a damaged or crafted UDF disc image whose logical volume descriptor declares
more partition maps than its sector or its map table holds, or a map of length 0. The ISO plug-in does
not read past the descriptor and does not record partition maps without a bound: the UDF volume does not
open. A UDF-only image then does not open; an ISO 9660 + UDF image lists its ISO 9660 part with the
listing marked incomplete. A whole unpack with "Delete archive after unpacking" keeps the image.

**Why this priority**: it is the item's whole point - a read past a buffer and an unbounded allocation
loop on input from a file.

**Independent Test**: craft each damaged descriptor from an IMAPI2FS image, unpack it whole with "Delete
archive after unpacking"; nothing is extracted from the UDF volume, a message is shown, the program does
not fail, the image is kept.

**Acceptance Scenarios**:

1. **Given** a UDF 2.01 image whose map count is 100000 (the bytes after its one map are zero),
   **When** the user unpacks it whole with "Delete archive after unpacking", **Then** nothing is
   extracted, a message is shown, the image is kept and the program keeps running.
2. **Given** the same image with its one map's length byte 0, or its map table length 4 (shorter than
   the map), **When** unpacked the same way, **Then** the same.
3. **Given** the same image with the rest of its descriptor sector filled with maps of length 255 and a
   count of 100000, or a full sector of 268 six-byte maps and a count of 300, **When** unpacked the same
   way, **Then** the same - no read past the sector.
4. **Given** an ISO 9660 + UDF image with a map count of 100000, **When** unpacked the same way, **Then**
   a message is shown and the image is kept (the listing is incomplete without its UDF part).

---

### User Story 2 - Well-formed images behave as before (Priority: P2)

UDF images written by real tools (one physical map; a physical and a metadata map in UDF 2.50; ISO 9660
+ UDF bridges) list and unpack exactly as before.

**Why this priority**: the refusal must not touch any valid image.

**Independent Test**: unpack IMAPI2FS UDF 2.01, UDF 2.50 and ISO 9660 + UDF 2.01 images whole with
"Delete archive after unpacking"; `a.txt` is extracted, no window appears, the image is deleted - before
and after the change; the regression probes of features 356, 358, 361 and 377 pass as recorded.

**Acceptance Scenarios**:

1. **Given** each of those images, **When** unpacked whole with "Delete archive after unpacking", **Then**
   `a.txt` ("A1") is extracted, no window appears and the image is deleted.

### Edge Cases

- A map count larger than the maps that fit, with zero bytes after the real maps (length 0): refused.
- A map whose length runs past the table length or past the sector: refused.
- A map shorter than the bytes the reader takes from a map of its type (a type 2 map shorter than 44
  bytes, a type 1 map shorter than 6): refused.
- A table length larger than the sector: the maps are bounded by the sector; maps that fit are read.
- A map count of 0: unchanged.
- An unknown map type with a length of at least 2 that fits: read as before (only its two header bytes).
- The descriptor appears twice in the sequence: each one is checked when it is read.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The plug-in MUST read partition maps only inside the descriptor sector it holds and inside
  the declared map table (440 + table length), whichever ends first.
- **FR-002**: A declared map count, map length or table length under which a declared map does not lie
  wholly inside that area, and a map length of 0 or 1, or shorter than the bytes read from a map of its
  type, MUST make the UDF volume refuse to open - with no partition map recorded from that descriptor and
  no read past the sector.
- **FR-003**: The refusal MUST take the existing failure path of a volume that does not open: a UDF-only
  track is not opened; an ISO 9660 + UDF image's listing is marked incomplete (feature 330), so a whole
  unpack with "Delete archive after unpacking" keeps the image. A message is shown unless the reader is
  quiet (existing text, no new UI string).
- **FR-004**: The decision MUST be a pure rule under `src/common/` with `saltests` checks, including a
  check that a walk the rule accepts ends and stays inside the area for every input of a grid.
- **FR-005**: Every well-formed volume (all declared maps fit) MUST open and list exactly as before.

### Key Entities

- **Logical volume descriptor**: one 2048-byte sector of the volume descriptor sequence; holds the map
  table length, the map count and the partition maps.
- **Partition map**: type (byte 0), length (byte 1), then the type's fields (type 1: 6 bytes; type 2:
  64 bytes of which the reader takes 44).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 6 crafted images (5 UDF-only, 1 bridge) are refused: nothing extracted from the UDF
  volume, the image kept, no program failure - on the hidden-desktop probe.
- **SC-002**: The 3 well-formed images unpack completely with no window and are deleted, before and after.
- **SC-003**: `saltests` passes with the new checks; the rule's grid shows every accepted walk ends inside
  the area.
- **SC-004**: The regression probes of features 356, 358, 361 and 377 give the results they recorded.

## Assumptions

- Assumption (autonomous run): the volume refusal reuses `IDS_ERROR_LISTING_IMAGE` with the descriptor's
  sector number, so no UI string, dialog or translation changes.
- Assumption (autonomous run): the bytes the reader takes from a type 2 map are 0 - 43 (entity identifier
  at 4, volume sequence number 36, partition number 38, metadata file location 40); the minimum for
  type 2 is therefore 44, not the standard 64 - a type 2 map of 44 - 63 bytes that fits opens as before.
- Assumption (autonomous run): the GUI probe needs Tandem Commander closed on the machine (the probe
  refuses to run beside another instance); the before run uses a copy of the HEAD build made at the
  start of the run.
