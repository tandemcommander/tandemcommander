# Feature Specification: A UDF 2.50 image whose volume descriptor precedes its partition descriptor lists and unpacks

**Feature Branch**: `377-uniso-udf-metadata-order`
**Created**: 2026-11-01
**Status**: Draft
**Input**: Backlog item iso-plug-in-a-udf-2-50-image-written-by-windows-imapi2fs (backlog/items/iso-plug-in-a-udf-2-50-image-written-by-windows-imapi2fs/desc.md) - implement exactly what it describes.  From backlog item iso-plug-in-a-udf-2-50-image-written-by-windows-imapi2fs.

## Background

A UDF-only disc image of revision 2.50 (a metadata partition) written by Windows' own image writer
IMAPI2FS (`IMAPI2FS.MsftFileSystemImage`, `FileSystemsToCreate = 4`, `UDFRevision = 0x250`) does not list
in the ISO plug-in: opening it (Enter, or a whole Unpack) shows "Cannot read sector #00000000." and
"Error reading directory structure at sector #FF567539. Incomplete content of ISO image." and lists no
file. The same files written as UDF 1.02 - 2.01 list and unpack. No data is lost (the listing is marked
incomplete, an unpack with "Delete archive after unpacking" keeps the image), but the image's files
cannot be extracted. UDF 2.50 is the revision of Blu-ray discs.

Measured at `aac7105e` (hidden desktop, current Debug build): probe `iso356_probe.ps1 -Only N-U250,C-PLAIN`
- N-U250 shows both error boxes above, nothing extracted, image kept; C-PLAIN (UDF 1.02) extracts `a.txt`
and is deleted. The image's main descriptor sequence (sectors 32..37) holds the logical volume descriptor
(sector 34: map 0 a physical partition, map 1 a `*UDF Metadata Partition`, metadata file at partition
block 0) **before** the partition descriptor (sector 35: start 288, length 160). The reader resolves the
metadata partition's file entry while it reads the logical volume descriptor, i.e. before the partition's
start is known, and so reads the wrong place.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open and unpack a UDF 2.50 image written by Windows (Priority: P1)

A user has a UDF 2.50 disc image (for example one written by Windows' IMAPI2FS, the revision of Blu-ray
discs). They press Enter on it in a panel, or unpack it whole with Alt+F9, and get its folders and files
as they get them from the same files written as UDF 2.01.

**Why this priority**: it is the item's whole point - today none of the image's files can be extracted.

**Independent Test**: write a UDF 2.50 image of `a.txt` ("A1") with IMAPI2FS, unpack it whole with "Delete
archive after unpacking"; `a.txt` with "A1" is extracted, no error box appears, the image is deleted (the
listing is complete).

**Acceptance Scenarios**:

1. **Given** an IMAPI2FS UDF 2.50 image of `a.txt` ("A1"), **When** the user unpacks it whole with "Delete
   archive after unpacking", **Then** `a.txt` is extracted with its content, no window appears and the
   image is deleted.
2. **Given** an IMAPI2FS UDF 2.50 image of `a.txt` and `sub\b.txt`, **When** the user opens it with Enter
   and copies everything out, **Then** both files and the folder appear with their contents and no error
   box is shown.

---

### User Story 2 - Every other UDF image behaves as before (Priority: P2)

UDF images whose partition descriptor comes before the logical volume descriptor (UDF 1.02 - 2.01 from
IMAPI2FS, mkudffs images, genisoimage UDF hybrids, sequentially written VAT images) list, unpack and are
kept or deleted exactly as before.

**Why this priority**: the change touches the reader every UDF image goes through.

**Independent Test**: the regression probes of features 356, 358 and 361 give their recorded results.

**Acceptance Scenarios**:

1. **Given** a UDF 1.02 IMAPI2FS image (`C-PLAIN`), **When** unpacked whole with "Delete archive after
   unpacking", **Then** `a.txt` is extracted and the image deleted, as before.
2. **Given** the probes of 356 / 358 / 361, **When** run on the new build, **Then** every row passes as
   recorded by those features.

### Edge Cases

- The metadata partition's file entry cannot be read (its sector lies past the file) or is not a file
  entry: the volume behaves as before - the listing fails and is marked incomplete, a whole unpack keeps
  the image; no crash.
- The metadata file entry is refused by 361's rule (reserved descriptor type): no metadata extents, as
  before.
- A partition descriptor that comes first: the metadata file entry is read from the same sector as
  before.
- A volume with no partition descriptor at all: unchanged (356 marks it).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The ISO plug-in MUST resolve a UDF metadata partition (read its metadata file entry) only
  after the whole main volume descriptor sequence has been read, so the partition's start is known
  whatever the order of the logical volume and partition descriptors.
- **FR-002**: An IMAPI2FS UDF 2.50 image MUST list and unpack (Enter and a whole Unpack) with the same files
  and contents as the UDF 2.01 image of the same files, without an error box, and a whole unpack with
  "Delete archive after unpacking" MUST delete it (the listing is complete).
- **FR-003**: Images whose partition descriptor precedes the logical volume descriptor, images without a
  metadata partition and images with a VAT MUST give the same listings, extractions, messages and
  keep/delete decisions as before.
- **FR-004**: A metadata file entry that cannot be read or is refused MUST leave the volume as it is
  today (no metadata extents; the listing fails and is marked incomplete; the image is kept), never a
  crash, never a read outside the image.
- **FR-005**: No UI string, dialog or plug-in interface change.

### Key Entities

- **Main volume descriptor sequence**: the descriptors a UDF volume lists at the anchor's location - the
  partition descriptor (where the partition starts) and the logical volume descriptor (the partition maps,
  among them the metadata partition map naming the metadata file's block).
- **Metadata file**: the file (file type 250) in the physical partition whose extents hold the metadata
  partition's blocks (folders, file entries).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe row for the IMAPI2FS UDF 2.50 image (356's `N-U250`) turns from "nothing
  extracted, two error boxes, image kept" into "`a.txt` extracted with 'A1', no window, image deleted".
- **SC-002**: A UDF 2.50 image with a sub-folder extracts every file with its content (2 of 2).
- **SC-003**: The regression probes of 356, 358 and 361 pass with their recorded counts (except 356's
  `N-U250`, which becomes a passing extraction row, and 361's metadata rows whose results are re-recorded).
- **SC-004**: Encoding guard `TOTAL: 0`, build succeeds, saltests 0 failed.

## Assumptions

- Assumption (autonomous run): the fix defers the metadata file entry read to the stage after the whole
  sequence is read (the item's *Approach*, second option); the read itself (sector, checks, the error box
  shown when it fails) stays as it is.
- Assumption (autonomous run): only one metadata partition per volume is supported, as today; the
  metadata mirror file is still not used when the main metadata file is damaged (not named by the item).
- Assumption (autonomous run): no real Blu-ray image is available; IMAPI2FS is the only 2.50 source
  (mkudffs 2.3 refuses `--udfrev=2.50` for a plain file).
