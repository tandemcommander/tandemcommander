# Feature Specification: ISO plug-in - an ISO 9660 file stored in several extents is listed once and extracted whole

**Feature Branch**: `368-uniso-multi-extent`
**Created**: 2026-11-01
**Status**: Draft
**Input**: User description: "Backlog item iso-plug-in-an-iso-9660-file-over-4-gib-stored-in-several - implement exactly what it describes." From backlog item iso-plug-in-an-iso-9660-file-over-4-gib-stored-in-several.

## Background

ISO 9660 level 3 lets a file be stored in several extents (file sections): the directory holds one record per
extent, all with the file's identifier, and every record but the last has the *multi-extent* bit (bit 7) of its
file flags set. A file of 4 GiB or more is always stored so (one record's data length is a 32-bit number; xorriso
and mkisofs write extents of 4 GiB - 2 KiB), and any authoring tool may split smaller files too. The file's content
is the extents' data in record order.

The ISO plug-in did not know the bit. Measured at 192383f1 (Debug x64 build, probe `iso368_probe.ps1` on the
hidden desktop, images by `img368.py` plus one real `xorrisofs -iso-level 3 -R -J` image with a file of 4 GiB +
3000 bytes stored as two extents of 4,294,965,248 + 5,048 bytes):

- each record is listed as a file of its own of the same name (genuine duplicate entries in the panel);
- a whole Unpack writes them one over the other - "Confirm File Overwrite" boxes, only the last part left
  (BIG.BIN 1,000 of 7,144 bytes; the 4 GiB file 5,048 bytes); since feature 338 the image is then kept
  ("Delete archive after unpacking" does not delete it), but the file is wrong;
- Copy (F5) of the file extracts one part (1,000 of 7,144 bytes) and reports success.

Plain ISO 9660, Rock Ridge (also with the Rock Ridge name only in the first record) and Joliet trees behave the
same: 10 of 10 RUN rows FAIL.

## Clarifications

### Session 2026-11-01

- Q: A chain whose last record is missing (the record after a flagged one has another identifier, is a folder, or
  the directory ends with the bit set) - list the parts found, or leave the file out? → A: Leave the whole file
  out, report it with the plug-in's existing "Error reading directory structure at sector #N - Incomplete content
  of ISO image" box, and mark the listing incomplete so a whole Unpack fails and keeps the image; the rest of the
  directory is listed as before. (autonomous run: item - "at least reported as not extracted"; conservative - no
  truncated file is ever extracted as if whole)
- Q: Should a multi-extent file on a track that stores Mode 2 Form 2 data (raw or 2336-byte Mode 2 sectors) get
  features 366/367's per-sector Form 2 reading? → A: No - such a file is left out and reported as above (fails
  closed). Discs of that layout are CDs (under 1 GB), where multi-extent files do not occur in practice; per-extent
  Form 2 handling would add risk to the stream coverage checks of 336/337 for no real case. (autonomous run:
  conservative)
- Q: Extents of one file lying in different tracks (sessions) of the image? → A: Left out and reported as above -
  the reader opens the track of the first extent and reads all sectors from it. (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A file over 4 GiB in a disc image extracts whole (Priority: P1)

A user opens a DVD / Blu-ray-sized ISO 9660 level 3 image (made by xorriso, mkisofs, ImgBurn, ...) holding a file
of 4 GiB or more and unpacks it - the whole image (Alt+F9, also with "Delete archive after unpacking"), a
selection, or the one file (F5 / F3). The file is listed once, with its whole size, and is extracted whole: the
data of all its extents, in record order. No overwrite question appears.

**Why this priority**: data loss - the extracted file is silently a fragment (5,048 bytes of a 4 GiB file).

**Independent Test**: probe row G-BIG: the real xorriso image unpacks with huge.bin of 4,294,970,296 bytes whose
SHA-256 equals the source file's, small.txt, no box, and the image deleted.

**Acceptance Scenarios**:

1. **Given** the xorriso image with huge.bin (4 GiB + 3000 bytes, two extents), **When** the user unpacks the
   whole image with "Delete archive after unpacking", **Then** huge.bin is 4,294,970,296 bytes with the source's
   content, no window appears, and the image is deleted.
2. **Given** an image with BIG.BIN of three extents stored out of disc order, **When** the user copies BIG.BIN
   with F5, **Then** the target holds one BIG.BIN of 7,144 bytes - the three extents in record order.
3. **Given** any such image, **When** the panel lists it, **Then** the file appears once, with the sum of its
   extents' lengths as its size.

---

### User Story 2 - Every name kind of the image works the same (Priority: P1)

The multi-extent file is found and joined in a plain ISO 9660 tree, a Rock Ridge tree (whether every record or
only the first carries the Rock Ridge name) and a Joliet tree, in the root and in sub-folders.

**Why this priority**: real images carry Rock Ridge and Joliet; the item's file must work in the tree the plug-in
lists.

**Independent Test**: probe rows U-PLAIN, U-RR, U-RRFIRST, U-JOLIET, U-DIRFLAG: every file whole (size and
SHA-256), no window, the image deleted.

**Acceptance Scenarios**:

1. **Given** each of the plain / Rock Ridge / Rock Ridge-first-only / Joliet images, **When** it is unpacked
   whole, **Then** BIG.BIN (7,144 bytes) and SUB\PART.BIN (2,548 bytes) are whole under the tree's names, the
   single-extent files are unchanged.
2. **Given** a folder record with the multi-extent bit set, **When** the image is listed, **Then** the folder is
   listed and walked as before (the bit means nothing on a folder).

---

### User Story 3 - A damaged chain is reported, never extracted cut (Priority: P2)

When an image's chain of records is incomplete (its last record is missing: the next record has another name or
the directory ends while the bit is still set), the plug-in does not list a part of the file as if it were the
file: it leaves the file out, reports the damaged directory, and a whole Unpack does not count as successful - the
image is kept.

**Why this priority**: the item's fallback ("at least reported as not extracted"); the project rule that a check
fails closed.

**Independent Test**: probe rows U-BRKNAME, U-BRKEND: the broken file absent, the others whole, the box "Error
reading directory structure", the image kept.

**Acceptance Scenarios**:

1. **Given** an image whose BIG.BIN chain ends in a record named BIH.BIN, **When** it is unpacked whole,
   **Then** BIG.BIN is not extracted, BIH.BIN (a file of its own, 1,000 bytes) and the other files are, the box
   "Error reading directory structure..." appears, and the image is kept.
2. **Given** an image whose PART.BIN chain runs to the end of its folder, **When** it is unpacked whole,
   **Then** PART.BIN is not extracted, the other files are, the box appears, and the image is kept.

### Edge Cases

- Extents stored out of disc order: read in record order (BIG.BIN's 60, 50, 55).
- An extent whose length is not a multiple of 2048 before the last one: only its length is taken (the rest of its
  last sector is not part of the file), as other readers do.
- An extent of length 0 inside a chain: contributes nothing.
- A read error in any extent: the file is not extracted whole - the existing read-error box (Skip / Skip all /
  Cancel) and feature 338's whole-unpack rule apply unchanged; the partly written file is deleted as before.
- A multi-extent file on a Mode 2 track that stores Form 2 data, or whose extents lie in different tracks: left
  out and reported (Clarifications).
- The panel listing's name-fit rules (features 326 / 328): the joined file counts as one entry.
- A single-extent file (no bit) and every other file system of the plug-in (UDF, HFS+, Xbox, raw tracks, audio):
  unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The ISO 9660 directory walk MUST treat a run of consecutive file records of one identifier whose
  records but the last carry the multi-extent bit as one file.
- **FR-002**: That file MUST be listed once, under the name the first record gives (Rock Ridge, Joliet or ISO 9660
  as today), with the first record's date and attributes, and with a size equal to the sum of all the records'
  data lengths (also above 4 GiB).
- **FR-003**: Extracting that file (whole Unpack, Unpack of a selection, Copy / F5, View / F3 - every route that
  reads an ISO 9660 file) MUST write the data of each extent in record order, each extent's data length bytes.
- **FR-004**: A chain whose last record is missing MUST NOT be listed; the plug-in MUST show its existing "Error
  reading directory structure at sector #N" message (no new text) and mark the listing incomplete so a whole Unpack
  fails and the image is kept; the rest of the directory and later folders MUST still be listed.
- **FR-005**: A multi-extent file whose extents do not all lie in the track of its first extent, or that lies on a
  track storing Mode 2 Form 2 data, MUST be handled as FR-004.
- **FR-006**: The multi-extent bit on a folder record MUST be ignored (as before).
- **FR-007**: Files without the bit, and all other file systems, MUST behave exactly as before (single-extent
  reading, features 366 / 367 Form 2 handling, stream coverage checks of 336 / 337).
- **FR-008**: The rule that groups records and decides a chain complete or broken, and the plan of what to read of
  each extent, MUST be a pure rule with unit checks (saltests).

### Key Entities

- **Multi-extent file**: a file of an ISO 9660 directory stored as an ordered list of extents (start sector,
  length); its size is the sum of the lengths.
- **Chain**: the consecutive records of one identifier; complete when the last one has the bit clear.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe's 10 RUN rows that failed at 192383f1 pass: a file of 4 GiB + 3000 bytes extracts with its
  source's SHA-256, the synthetic multi-extent files with their expected SHA-256, the broken chains are absent and
  the image kept.
- **SC-002**: No "Confirm File Overwrite" box appears in any whole Unpack of a valid multi-extent image (0 boxes,
  was 1-3 per image).
- **SC-003**: Earlier probes of the ISO plug-in (338, 337) keep their results.
- **SC-004**: The unit checks of the pure rule pass, and fail when the rule is mutated (negative control).

## Assumptions

- Assumption (autonomous run): the records of one multi-extent file are consecutive in their directory (ECMA-119
  6.5.1 and every authoring tool); records of one identifier separated by another record are separate files, as
  before.
- Assumption (autonomous run): records belong to one chain when their raw identifiers (bytes and length) are equal;
  the Rock Ridge / Joliet name of the first record names the file.
- Assumption (autonomous run): no new UI string - the broken chain uses the existing "Error reading directory
  structure" message, so no translation refresh is needed.
- The 4 GiB row (G-BIG) needs WSL Ubuntu with xorriso (fetched without root, as feature 327) and about 9 GB of free
  space in %TEMP%; without them it is NOT DRIVEN and the synthetic rows carry the proof.
