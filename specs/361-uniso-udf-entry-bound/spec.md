# Feature Specification: ISO plug-in - a damaged UDF file entry no longer hangs the listing or reads past its sector

**Feature Branch**: `361-uniso-udf-entry-bound`
**Created**: 2026-10-31
**Status**: Draft
**Input**: User description: "Backlog item iso-plug-in-a-damaged-udf-file-entry-hangs-the-listing-or - implement exactly what it describes." From backlog item iso-plug-in-a-damaged-udf-file-entry-hangs-the-listing-or.

## Clarifications

### Session 2026-10-31

- Q: How is a file whose entry is refused reported at unpack? → A: with the existing box "File ... cannot be extracted. Mismatch between file size and ICB blocks." (`IDS_UDF_ICB_AND_FILESIZE_MISMATCH`), the file not extracted, the unpack failing - no new UI string (autonomous run: conservative)
- Q: Is a descriptor area that is not a whole number of descriptors (a descriptor cut by the area's end) refused, or its tail ignored? → A: refused, as feature 360 refuses it for the VAT - the item asks for the rules shared with 360 (autonomous run: item)
- Q: Is a reserved descriptor type with an empty area (L_AD 0, no hang today) refused too? → A: yes - the entry is invalid, and listing it as an empty folder or file would let a whole unpack succeed and delete the image (autonomous run: conservative)
- Q: What does a refused metadata-partition entry (UDF 2.50) leave? → A: no metadata extents (the count 0, not the refusal value): the volume's metadata blocks are not translated, its folders cannot be read, as an unreadable metadata entry today (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A damaged folder entry does not hang the program (Priority: P1)

A user has a damaged or crafted UDF disc image: the file entry of its root folder or of a sub-folder declares a
reserved allocation-descriptor type (4 - 7), or an extended-attribute / descriptor length that reaches past the
entry's 2048-byte sector. The user presses Enter on it in a panel, or unpacks it whole (Alt+F9). Today the ISO
plug-in's general file-entry reader loops for ever on the reserved type (Tandem Commander stops answering and
must be killed - other work in the program is lost) or reads past its sector buffer (an access violation, or
garbage taken as the folder's location). After the fix such an entry is refused the way an unreadable entry is
refused today: the root folder shows "Bad root ICB" and nothing of that UDF volume is listed; a sub-folder is
listed empty and the listing is marked incomplete (feature 330), so a whole unpack with "Delete archive after
unpacking" fails and keeps the image. The program keeps answering.

**Why this priority**: the item's main point - a hang and a read past a buffer from a file the user opens.

**Independent Test**: probe `iso361_probe` rows on the hidden desktop, Debug build: Enter and whole unpack on
mk_cdr.img whose root entry has descriptor type 5 (review 1 of 360's `rootadt5`), and on a genisoimage UDF
image whose folder `a` has descriptor type 5 or an L_EA past the sector.

**Acceptance Scenarios**:

1. **Given** mk_cdr.img whose root folder's entry has descriptor type 5, **When** the user presses Enter on
   it, **Then** the program answers, "Bad root ICB" is shown, no bug report.
2. **Given** the same image, **When** it is unpacked whole with "Delete archive after unpacking", **Then** the
   program answers and the image is kept.
3. **Given** a UDF image whose folder `a`'s entry has descriptor type 5, or an L_EA that puts the descriptor
   area past the sector, **When** unpacked whole with "Delete archive after unpacking", **Then** the program
   answers, the files outside `a` are extracted, and the image is kept (the listing is incomplete).

---

### User Story 2 - A damaged file entry does not hang the unpack (Priority: P1)

The file entry of a file inside the image has the same damage. The listing shows the file (it reads only the
file's size and time). When the user unpacks it, today the reader loops for ever (reserved type) or reads past
its buffer. After the fix the file is not extracted: the existing box "File ... cannot be extracted. Mismatch
between file size and ICB blocks." names it, the unpack reports failure and "Delete archive after unpacking"
keeps the image.

**Why this priority**: the same hang, reached by Unpack instead of Enter.

**Independent Test**: probe row with a genisoimage UDF image whose file `top.txt` has descriptor type 5.

**Acceptance Scenarios**:

1. **Given** a UDF image whose file `top.txt`'s entry has descriptor type 5, **When** it is unpacked whole with
   "Delete archive after unpacking", **Then** the program answers, the box names `top.txt`, `top.txt` is not
   extracted, the other files are, and the image is kept.

---

### User Story 3 - Well-formed images list and unpack as before (Priority: P2)

Plain UDF images (genisoimage `-udf` hybrids, mkudffs images of every media type, VAT images) list and unpack
as today; the probes of features 330, 358, 359 and 360 keep their recorded results.

**Why this priority**: no regression of the readable case.

**Independent Test**: control rows of `iso361_probe`; probes 330 and 360 re-run.

**Acceptance Scenarios**:

1. **Given** the intact genisoimage UDF image, **When** unpacked whole with "Delete archive after unpacking",
   **Then** every file is extracted with its content, no window appears and the image is deleted.

### Edge Cases

- An entry with data embedded in it (descriptor type 3) whose area reaches past the sector: refused (the unpack
  copied the bytes after the sector buffer into the extracted file).
- A descriptor area whose length is not a whole number of descriptors (a descriptor cut by the area's end):
  refused, as feature 360 refuses it for the VAT.
- A reserved descriptor type with an empty area (L_AD 0): refused too - the entry is invalid; refusing keeps a
  whole unpack from reporting success.
- More descriptors than the caller holds (32 at unpack and for the metadata partition, 1 when a folder is
  mapped): unchanged - the reader stops at the caller's limit as today.
- An empty area of a valid type (an empty file or folder): unchanged - no descriptor, one terminating entry.
- The metadata-partition file entry of a UDF 2.50 volume with the same damage: refused - the volume has no
  metadata extents, its folders cannot be read (as an unreadable metadata entry today), no hang.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The general file-entry reader MUST NOT loop on a reserved descriptor type (4 - 7): such an entry
  is refused.
- **FR-002**: The reader MUST NOT read past the 2048-byte sector it parses: the descriptor area (after the
  fixed part of 176 bytes, 216 in an extended entry, and L_EA bytes; L_AD bytes long) MUST lie within the
  sector, computed without 32-bit wrap; otherwise the entry is refused. Every descriptor read MUST lie within
  the area; an area that is not a whole number of descriptors is refused.
- **FR-003**: A refused entry MUST be reported the way each caller reports an unreadable entry today: the root
  folder - "Bad root ICB", listing incomplete; a sub-folder - listed empty, listing incomplete (feature 330);
  a file at unpack - the existing "cannot be extracted" box naming it, the file not extracted, the unpack
  failing; the metadata partition - no metadata extents. No new UI string.
- **FR-004**: The area and descriptor rules MUST be shared with feature 360 (its rules reused or generalised in
  `src/common/`) and covered by `saltests` checks, including a model of the reader's walk that shows it always
  ends and stays in the sector.
- **FR-005**: Well-formed entries MUST be read exactly as before (the same descriptors, the same count, the same
  terminating entry, the embedded-data offset and length).

### Key Entities

- **File entry**: a UDF file entry (plain or extended) - its ICB descriptor type, extended-attributes length
  (L_EA) and descriptors length (L_AD).
- **Descriptor area**: the bytes of the entry's sector holding its allocation descriptors (or its embedded data).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The damaged rows (root entry type 5 - Enter and unpack; folder entry type 5; folder L_EA past the
  sector; file entry type 5) fail on the build before the fix (a hang or a bug report) and PASS after it: the
  program answers, the image is kept.
- **SC-002**: The control rows extract every file and delete the image, before and after; probes 330 and 360
  keep their recorded results.
- **SC-003**: `saltests` passes with the new checks; a negative control that drops a bound or the reserved-type
  refusal fails a check.

## Assumptions

- Assumption (autonomous run): a refused file at unpack reuses `IDS_UDF_ICB_AND_FILESIZE_MISMATCH` ("File ...
  cannot be extracted. Mismatch between file size and ICB blocks.") - the allocation descriptors are what is
  wrong, the box names the file, and no new string is needed (conservative: no new UI string).
- Assumption (autonomous run): a descriptor area that is not a whole number of descriptors is refused, as
  feature 360 refuses a cut descriptor for the VAT (conservative: refuse rather than guess).
- Assumption (autonomous run): a reserved type is refused also with L_AD 0 (the entry is invalid; listing it as
  an empty folder or file would let a whole unpack succeed and delete the image).
- Assumption (autonomous run): the second reader `ReadFileEntry(BYTE*, bool, CFileEntry*)` (size and time only,
  no descriptors) and the folder walk's other limits are outside the item.
- Assumption (autonomous run): the metadata-partition caller is covered by the shared rule's `saltests` checks
  only - the one UDF 2.50 writer on the machine (Windows IMAPI2FS; mkudffs here refuses 2.50) makes images the
  plug-in fails to open before it reads the metadata entry ("Cannot read sector #00000000" - the older limit of
  feature 356, Inbox `iso-plug-in-a-udf-2-50-image-written-by-windows-imapi2fs`); probe row L-META5 shows only
  that the program answers (deviation, measured before and after).
- The block size of these readers is 2048 bytes (one sector into a 2048-byte buffer).
