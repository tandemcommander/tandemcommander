# Feature Specification: ISO plug-in - a UDF image with a VAT that is not found no longer crashes

**Feature Branch**: `358-uniso-udf-vat-missing`
**Created**: 2026-10-31
**Status**: Draft
**Input**: User description: "Backlog item iso-plug-in-a-udf-image-with-a-vat-and-data-past-it-crashes - implement exactly what it describes." From backlog item iso-plug-in-a-udf-image-with-a-vat-and-data-past-it-crashes.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Unpacking a VAT image with data past its volume does not close the program (Priority: P1)

A user has a disc image of a sequentially written medium (CD-R, DVD-R, BD-R written in UDF with a virtual
allocation table, VAT - as `mkudffs --media-type=cdr` writes it, or a dump of a packet-written disc) whose
file holds more than the UDF volume (for example 100 sectors of other data after it). The user selects it and
runs Unpack (Alt+F9) of the whole image with "Delete archive after unpacking". Today Tandem Commander shows
"Missing virtual allocation table." and then closes with "A problem has occurred, forcing Tandem Commander to
close" (access violation reading address 0). After the fix the program keeps running: the plug-in reports the
missing table, nothing is extracted, the unpack fails and the image is kept.

**Why this priority**: the program closes and the user's other work in it is interrupted - the item's whole point.

**Independent Test**: probe `iso358_probe` rows R-VCDR100, R-VCLAIM16, R-VCLAIM100Z on the hidden desktop.

**Acceptance Scenarios**:

1. **Given** an mkudffs cdr image + 100 sectors of 0x5A, **When** the user unpacks it whole with "Delete
   archive after unpacking", **Then** only the box "Missing virtual allocation table." appears, no bug report,
   nothing is extracted and the image is kept.
2. **Given** the same image filled with data up to the size its partition descriptor claims + 16 sectors, or +
   100 zero sectors, **When** unpacked the same way, **Then** the same outcome.

---

### User Story 2 - Opening such an image in the panel does not close the program (Priority: P1)

The same image opened with Enter in a panel (the listing alone) crashes the program today. After the fix the
missing table is reported and the image does not open; the program keeps running.

**Why this priority**: the same defect reached by the most common action.

**Independent Test**: probe row L-VCDR100.

**Acceptance Scenarios**:

1. **Given** the R-VCDR100 image, **When** the user presses Enter on it, **Then** only the box "Missing virtual
   allocation table." appears, the program stays alive with no bug report.

---

### User Story 3 - VAT images that end with their VAT list as before (Priority: P2)

Plain mkudffs images of sequential media (cdr open, cdr closed, dvdr, bdr), whose VAT is found, list and
unpack as today; so does an image filled exactly to its claimed size ("Error reading virtual allocation
table", kept) and a non-VAT image.

**Why this priority**: no regression of the readable case.

**Independent Test**: probe rows C-MKCDR, C-MKCDRC, C-MKDVDR, C-MKBDR, C-MKHD, C-VCLAIM, L-MKCDR; the 356
probe's C-MK rows.

**Acceptance Scenarios**:

1. **Given** each plain mkudffs image, **When** unpacked whole with "Delete archive after unpacking", **Then**
   no window, nothing extracted (the volumes are empty), the image deleted - as before.

### Edge Cases

- The VAT search ends with a terminating error (an unknown allocation strategy, no memory): the volume does not
  open either (today it is treated as found and crashes the same way).
- A UDF + ISO 9660 hybrid whose UDF part is a VAT volume without its VAT: the UDF part is dropped, the ISO 9660
  part still lists, and the listing is marked incomplete when a UDF anchor shows the part was there (330's
  rule, unchanged).
- A VAT is found: a block number equal to the number of entries (one past the table) is not translated - it
  is an invalid sector, as any number past the table.
- A VAT whose header claims more bytes than the table holds: it is not taken as a VAT (the entry count is
  never larger than the table read).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When a UDF volume has a virtual partition map and no VAT is found, the UDF volume MUST NOT open:
  the missing-table message is shown as today (not in quiet opens), nothing of the volume is listed, and the
  listing is marked incomplete by the existing rule for a track or part that does not open (a whole unpack
  fails, "Delete archive after unpacking" keeps the image).
- **FR-002**: The same MUST hold when the VAT search ends with a terminating error.
- **FR-003**: The virtual-to-physical block translation MUST NOT read the table when there is none, and MUST
  NOT read at or past the number of entries (`block < entries`); such a block is an invalid sector.
- **FR-004**: The number of VAT entries MUST NOT exceed what the read table holds; a VAT 2.00 header longer
  than the table makes the sector not a VAT.
- **FR-005**: The translation state MUST start empty (no table, zero entries) for every UDF volume object.
- **FR-006**: VAT images whose VAT is found MUST list and unpack as before; no UI string, no dialog changes.
- **FR-007**: The decision of FR-003 / FR-004 MUST be a pure rule in a header under `src/common/` checked by
  `saltests`.

### Key Entities

- **Virtual allocation table (VAT)**: the table a sequentially written UDF volume keeps at its end, mapping
  virtual block numbers to physical sectors; its entry count and the table bytes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The four crash rows of the probe (R-VCDR100, R-VCLAIM16, R-VCLAIM100Z, L-VCDR100) go from a bug
  report to PASS (no bug report, the image kept, only the missing-table box).
- **SC-002**: Every regression row (C-VCLAIM, C-MKCDR, C-MKCDRC, C-MKDVDR, C-MKBDR, C-MKHD, L-MKCDR) stays
  PASS; probe 356 stays 56 / 0.
- **SC-003**: `saltests` passes with new checks for the rule; a mutant of the bound (`<=`) fails them.

## Assumptions

- Assumption (autonomous run): "lists nothing and marks the listing incomplete" is reached by the volume not
  opening, as an unreadable VAT ("Error reading virtual allocation table") already does today - the track is
  "not opened" and 334's rule marks the listing; for a single-volume image the archive does not open and a
  whole unpack fails with the image kept (conservative: the existing behaviour of the nearest case).
- Assumption (autonomous run): finding a VAT that is not near the claimed partition end or the file's last
  sectors (searching the file for it) is out of scope - the item asks for no crash, not for listing such images.
- Assumption (autonomous run): bounds of the VAT reader's copy of allocation descriptors into the table buffer
  (crafted images) are a separate defect, recorded as an Inbox item if confirmed.
- The ISO plug-in (`uniso`) is enabled in the default build; the fix changes only `udf.cpp` and a new pure header.
