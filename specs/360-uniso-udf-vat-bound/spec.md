# Feature Specification: ISO plug-in - a damaged UDF VAT file entry no longer writes past the table buffer

**Feature Branch**: `360-uniso-udf-vat-bound`
**Created**: 2026-10-31
**Status**: Draft
**Input**: User description: "Backlog item iso-plug-in-a-damaged-udf-vat-entry-writes-past-its-buffer - implement exactly what it describes." From backlog item iso-plug-in-a-damaged-udf-vat-entry-writes-past-its-buffer.

## Clarifications

### Session 2026-10-31

- Q: Should an entry refused by the new bounds get its own message, or end the search? → A: neither - it is "not a VAT": the search continues and, without another VAT, the volume does not open with feature 358's "Missing virtual allocation table." (autonomous run: item)
- Q: Should a VAT whose descriptors cover less than its information length (the table's tail uncovered) be refused too? → A: no - accepted as before; the item names only descriptors that exceed the length; the uncovered tail goes to an Inbox item (autonomous run: conservative)
- Q: Should the reserved descriptor types 4 - 7, measured to write past the buffer through an uninitialised descriptor, be refused in this feature? → A: yes - the same defect the item describes ("never writes past the table buffer") (autonomous run: item)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A damaged VAT entry does not corrupt memory (Priority: P1)

A user has a disc image of a sequentially written medium (CD-R, DVD-R, BD-R in UDF with a virtual allocation
table, VAT) whose VAT file entry is damaged or crafted: it claims more table bytes than the file's length, a
descriptor area longer than its sector, a reserved descriptor type, or a length over 4 GB. The user presses
Enter on it in a panel, or unpacks it whole (Alt+F9). Today the ISO plug-in copies the claimed bytes into a
table buffer that is too small - a heap write past the buffer (the Debug build stops with "HEAP CORRUPTION
DETECTED"; the Release build may crash later or work on corrupted memory). After the fix such an entry is not
taken as a VAT: the image does not open ("Missing virtual allocation table.", feature 358), nothing is
extracted, "Delete archive after unpacking" keeps the image, and the program keeps running.

**Why this priority**: memory corruption from a file the user opens - the item's whole point.

**Independent Test**: probe `iso360_probe` rows R-ILM4, R-NILM4, R-V150ILM4, R-LADBIG, R-ADT5, R-LEAHUGE,
R-ILHUGE (Unpack) and L-ILM4, L-ADT5, L-LADBIG (Enter) on the hidden desktop, Debug build.

**Acceptance Scenarios**:

1. **Given** an mkudffs cdr image whose VAT entry's information length is 4 bytes lower than its embedded
   table (review 1 of feature 358), **When** the user unpacks it whole with "Delete archive after unpacking",
   **Then** only "Missing virtual allocation table." boxes appear, nothing is extracted, the image is kept, no
   heap-corruption box or bug report.
2. **Given** the same damage in a plain file entry, or in a UDF 1.50 VAT, **When** unpacked, **Then** the same.
3. **Given** a VAT entry whose descriptor area is longer than its sector (L_AD 4096), **When** listed or
   unpacked, **Then** the same.
4. **Given** a VAT entry with a reserved descriptor type (5), **When** listed or unpacked, **Then** the same -
   no uninitialised descriptor is used and the walk does not loop.
5. **Given** a VAT entry whose extended-attribute length would wrap the area's 32-bit offset, or whose
   information length is over 2^32, **When** unpacked, **Then** the same - the length is refused, not cut.

---

### User Story 2 - Well-formed VAT images open as before (Priority: P2)

Plain mkudffs VAT images (cdr open and closed, dvdr, bdr, UDF 1.50 open and closed, VAT 2.00 in a plain file
entry) list and unpack as today; the rows of features 358 and 359 stay as they are.

**Why this priority**: no regression of the readable case.

**Independent Test**: probe rows C-MKCDR, C-MKCDRC, C-MKDVDR, C-MKBDR, C-MK150, C-MK150C, C-MKNOEFE, L-MKCDR;
probes 358 (52 rows) and 359 re-run.

**Acceptance Scenarios**:

1. **Given** mk_cdr.img, **When** listed, **Then** no window appears and the archive opens.
2. **Given** each plain VAT image, **When** unpacked whole with "Delete archive after unpacking", **Then** no
   window appears and the image is deleted (the volumes are empty).

### Edge Cases

- The descriptors cover exactly the information length (mkudffs: embedded table, L_AD equal to the length):
  taken, as before.
- The descriptors cover less than the information length: taken as before (no write past the buffer); the
  table's uncovered tail stays as today (Assumptions).
- A descriptor that starts in the area but ends past it (a partial descriptor at the area's end): not a VAT.
- A zero-length area (L_AD 0): no descriptor is read; the later VAT checks decide as before.
- The information length is exactly 2^32 - 1: accepted by the length rule (the buffer holds it); the
  descriptors decide the rest.
- An unknown allocation strategy keeps its existing box ("unknown allocation strategy"), checked first.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The VAT reader MUST NOT write past the table buffer: every copy (embedded data or an extent read
  from the image) MUST fit the bytes left in the buffer; a copy that does not fit means the entry is not a VAT.
- **FR-002**: The VAT reader MUST NOT read past the sector it parses: the descriptor area (its start after the
  entry's fixed part and extended attributes, and its length) MUST lie within the 2048-byte sector, computed
  without 32-bit wrap; every descriptor read MUST lie within the area. Otherwise the entry is not a VAT.
- **FR-003**: An information length over 2^32 - 1 MUST be refused (the entry is not a VAT), never cut to 32 bits.
- **FR-004**: A reserved descriptor type (ICB flags' type 4 - 7) MUST make the entry not a VAT; no descriptor is
  used uninitialised and the descriptor walk always advances.
- **FR-005**: An entry refused by FR-001 - FR-004 MUST be treated as "not a VAT" (the search continues; without
  another VAT the volume does not open - feature 358's "Missing virtual allocation table." path); no new
  message.
- **FR-006**: The rules of FR-001 - FR-004 MUST be pure in `src/common/salisoudfvat.h` with `saltests` checks.
- **FR-007**: No UI string, dialog or message changes; well-formed VAT images list and unpack as before.

### Key Entities

- **VAT file entry**: the file entry (plain or extended) of the VAT file - its information length, extended
  attributes length (L_EA), descriptors length (L_AD) and ICB descriptor type.
- **Table buffer**: the bytes the reader allocates for the VAT, the file's information length.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The rows that failed at ddf0465a - R-ILM4, R-NILM4, R-V150ILM4, R-LADBIG, R-ADT5, R-ILHUGE, L-ILM4,
  L-ADT5, L-LADBIG (heap corruption, run-time check failures, a bug report) - PASS: only the missing-VAT box,
  image kept, program alive.
- **SC-002**: R-LEAHUGE and the controls (C-MK*, L-MKCDR) stay PASS; probe 358 stays 52 / 0 and probe 359 at
  its recorded result.
- **SC-003**: `saltests` passes with the new checks; a negative control that drops a bound fails a check.

## Assumptions

- Assumption (autonomous run): descriptors covering **less** than the information length are accepted as
  before - the item names only descriptors that exceed it; the uncovered tail of the table (heap content, noted
  by review 2 of feature 358) is a separate, lesser defect recorded as an Inbox item (conservative; scope,
  stop-rules 2.11).
- Assumption (autonomous run): the reserved descriptor types 4 - 7 are refused in this feature - the measurement
  showed they write past the buffer through an uninitialised descriptor and never advance the walk, the same
  defect the item describes (item: "never writes past the table buffer").
- Assumption (autonomous run): extent types (recorded / not recorded / continuation) inside short, long and
  extended descriptors keep today's handling; only their lengths are bounded (conservative).
- The block size of the VAT search is 2048 bytes (the reader reads one 2048-byte sector into a 2048-byte
  buffer).
