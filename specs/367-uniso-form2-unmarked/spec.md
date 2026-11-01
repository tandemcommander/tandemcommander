# Feature Specification: ISO plug-in - a video file in Form 2 sectors without an XA Form 2 attribute extracts whole

**Feature Branch**: `367-uniso-form2-unmarked`
**Created**: 2026-11-01
**Status**: Draft
**Input**: User description: "Backlog item iso-plug-in-a-video-file-in-form-2-sectors-without-an-xa - implement exactly what it describes." From backlog item iso-plug-in-a-video-file-in-form-2-sectors-without-an-xa.

## Background

Feature 366 made the ISO plug-in read a Video CD / SVCD video file whole - 2324 user bytes of each of its Mode 2
Form 2 sectors instead of 2048 - but only when the file's ISO 9660 directory record carries a CD-XA attribute that
says Form 2 only, and the file's first sector is a Form 2 sector. A file stored in Form 2 sectors that does not
meet this is still read 2048 bytes a sector: 276 bytes of every sector are lost without a message, the stream
coverage check (feature 337) counts the sectors as extracted, and a whole Unpack with "Delete archive after
unpacking" deletes the image - the only copy of the full stream. Three shapes are known:

- **no XA record** (a plain ISO 9660 directory pointing into a Video CD stream; 335's crafted X-VCDFILE);
- **mixed attributes** 0x3D55 (Form 1 + Form 2 bits, as interleaved game streams);
- **a Form 1 first sector** followed by Form 2 sectors.

Measured at 56a44fba (Debug x64 build, images by `specs/366-uniso-form2-files/probe/img366.py` from real
vcdimager 2.0.1 output, probe `iso366_probe.ps1 -Only C-MIXED,C-NOXA,C-F1SUB` on the hidden desktop): the
affected file extracts as 608,256 bytes (the 2048-byte read of its 297 sectors; the 2324-byte read is 690,228
bytes and holds the source MPEG whole) and the image is deleted in all three rows.

The item allows two outcomes: read such a file whole (decided per sector by its subheader, with a listed size
that matches), or - when that cannot be decided at listing - fail closed. This feature takes the first: every
case can be decided at listing by reading the sectors' subheaders, so the cut is removed instead of only
keeping the image. That is option C of the open decision `keep-video-cd-images-after-a-whole-unpack-until-their-video`
("fix the cut first") and needs no maintainer decision.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A video file without an XA Form 2 record extracts whole (Priority: P1)

A user opens a Video CD disc image (CloneCD, Nero, raw .bin) whose video file's directory record has no CD-XA
record, or one with mixed Form 1 + Form 2 attributes, and unpacks it (whole, a selection, or one file / F3). The
file is listed and extracted with all 2324 user bytes of each of its Form 2 sectors - the same content as a
file feature 366 recognises.

**Why this priority**: data loss - 276 bytes of every sector silently missing, and the image with the full stream
deleted by "Delete archive after unpacking".

**Independent Test**: probe rows C-NOXA and C-MIXED: AVSEQ01.DAT extracts as 690,228 bytes = the 2324-byte user
data of its 297 sectors and contains the source `v.mpg` whole.

**Acceptance Scenarios**:

1. **Given** a Video CD image whose AVSEQ01.DAT record has no XA record, **When** the user unpacks the whole
   image with "Delete archive after unpacking", **Then** AVSEQ01.DAT is 690,228 bytes, equals the 2324-byte
   user data of its sectors, and the other files are as before.
2. **Given** the same image with AVSEQ01.DAT's XA attributes 0x3D55, **When** it is unpacked, **Then** the same
   result.
3. **Given** either image, **When** the panel lists it, **Then** AVSEQ01.DAT shows the size it extracts with
   (690,228 bytes).

---

### User Story 2 - A file whose sectors mix Form 1 and Form 2 extracts every sector's user data (Priority: P1)

A file whose sectors are partly Form 1 and partly Form 2 (a Form 1 first sector followed by Form 2 sectors;
interleaved game streams) is read sector by sector: 2048 bytes of each Form 1 sector, 2324 bytes of each Form 2
sector, as each sector's subheader says, and is listed with the sum.

**Why this priority**: the same loss; the item names the Form 1 first sector shape explicitly.

**Independent Test**: probe row C-F1SUB: AVSEQ02.DAT extracts as 2048 + 296 x 2324 = 689,952 bytes - the
first sector's 2048 user bytes followed by the 2324 user bytes of each of the other 296 sectors.

**Acceptance Scenarios**:

1. **Given** a Video CD image whose AVSEQ02.DAT's first sector is Form 1 and the rest Form 2, **When** it is
   unpacked, **Then** AVSEQ02.DAT is 689,952 bytes with that content, and the listed size is the same.
2. **Given** a file of mixed sectors whose last sector is Form 1 and whose record length ends inside that sector,
   **When** it is unpacked, **Then** only the record's remaining bytes of that last sector are written (as
   before for any 2048-byte sector), and the listed size counts exactly what is written.

---

### User Story 3 - The image is deleted only when its streams were extracted whole (Priority: P1)

A whole Unpack with "Delete archive after unpacking" counts a stream sector as extracted only by what the file
really reads of it: a sector read with all its 2324 Form 2 user bytes counts; the coverage check (feature 337)
uses the same per-sector decision as the reader.

**Why this priority**: the deletion is what makes the cut unrecoverable.

**Independent Test**: probe rows C-NOXA, C-MIXED, C-F1SUB: the files extract whole and the image is deleted
(as for a real Video CD, 366's R-VCD-CCD); a shortened record (366's C-SHORT240) still keeps the image.

**Acceptance Scenarios**:

1. **Given** the rows above, **When** the whole image is unpacked with "Delete archive after unpacking",
   **Then** every video file extracts whole and the image is deleted, as for 366's real Video CD rows.
2. **Given** a file whose record spans only part of its stream, **When** it is unpacked, **Then** the image is
   kept (feature 337 unchanged).

---

### User Story 4 - Everything else unchanged (Priority: P2)

Files of a plain data disc (Mode 1, cooked .iso), the Form 1 files of a Video CD (INFO.VCD, ENTRIES.VCD) and
366's Form 2 files (XA Form 2 attribute, Form 2 first sector) are listed and extracted exactly as before.

**Independent Test**: 366's probe rows R-VCD-CCD, R-VCD-NRG, R-SVCD-CCD, R-VCD-BIN, C-COOKED, C-CUT, C-SHORT240,
D-DIFF2-CCD, D-DIFF2-NRG unchanged; 337's, 365's and 334's probes unchanged.

**Acceptance Scenarios**:

1. **Given** any of those images, **When** listed and unpacked, **Then** the files, sizes and the image's fate
   are as on main.

### Edge Cases

- A sector of the file lies past the image's end (a cut image): at listing it counts as a 2048-byte sector (its
  form cannot be read); the unpack then fails to read it (read-error box, as on main - 366's C-CUT) and the whole
  unpack fails, the image kept.
- A sector whose subheader is damaged (not a valid Form 2 subheader): read as 2048 bytes (Form 1 / unknown) - the
  same rule feature 335 uses to decide a Form 2 sector; its 276 bytes past 2048 are not counted as extracted, so
  in a stream track feature 337's gap check finds them (data) and keeps the image.
- The image changes between listing and unpack: the reader never writes more than the listed size; an unpack
  that reads a different form than the listing saw writes different bytes (no worse than main).
- An empty file (record length 0): unchanged, nothing read.
- A file whose first sector is Form 1, whose record has no XA Form 2 bit and which does not start in a Form 2
  stream track: not examined (see Assumptions) - unchanged.
- A folder record: never examined.
- Out of memory while listing: the listing is marked as before; nothing new.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: An ISO 9660 file of more than zero bytes that feature 366 does not read as Form 2, on a track that
  stores Form 2 user data where the plug-in reads user data (366's rule), MUST be examined sector by sector
  when any of these holds: it starts in a Form 2 stream track (feature 336's `Form2Stream`), its record's CD-XA
  attributes carry the Form 2 bit (also with the Form 1 bit - mixed), or its first sector is a Form 2 sector.
- **FR-002**: Examining a file reads the subheader of each of the sectors its record spans (record length in
  2048-byte blocks, rounded up) and decides per sector by feature 335's Form 2 sector rule: a Form 2 sector
  yields 2324 bytes; any other (Form 1, damaged, unreadable) yields 2048 bytes - for the last sector, the
  record's remaining bytes (length - (sectors - 1) x 2048) when it is not Form 2.
- **FR-003**: When every examined sector is Form 2, the file MUST be listed and read exactly as a feature 366
  Form 2 file (sectors x 2324 bytes).
- **FR-004**: When no examined sector is Form 2, the file MUST stay as before (record length, 2048 bytes a
  sector).
- **FR-005**: When the sectors are mixed, the file MUST be listed with the sum of FR-002 and both readers (the
  ISO 9660 reader, the raw-track reader) MUST read it sector by sector by the same rule, never writing more
  than the listed size.
- **FR-006**: The stream coverage check (features 336/337) MUST count, for an examined file, exactly the sectors
  the reader reads whole: all of them for an all-Form-2 file; for a mixed file, every sector except a last
  non-Form-2 sector whose record ends inside it.
- **FR-007**: Files not examined (FR-001 not met) and 366's Form 2 files MUST be listed, read and counted as
  before.
- **FR-008**: No UI text, dialog or option changes.
- **FR-009**: The pure rules (which files are examined, the per-sector size, the listed size of a mixed file,
  the whole sectors it covers) MUST be in `src/common/salisotrack.h` with `saltests` checks.

### Key Entities

- **Examined file**: an ISO 9660 file record (extent, record length, XA attributes) whose sectors' forms decide
  its listed size and read.
- **Sector form**: Form 2 (2324 user bytes) or not (2048) - by feature 335's subheader rule.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe rows C-NOXA and C-MIXED extract AVSEQ01.DAT as 690,228 bytes containing `v.mpg` whole
  (was 608,256 bytes); C-F1SUB extracts AVSEQ02.DAT as 689,952 bytes with the per-sector content (was 608,256).
- **SC-002**: In those rows the listed size equals the extracted size, and the image's fate is that of a real
  Video CD (deleted, every stream extracted whole).
- **SC-003**: Every other row of 366's probe and the regression probes 337, 365, 334 give the same results as on
  main (334: S-RAW as recorded since 335).
- **SC-004**: `saltests` passes with new checks for the rules of FR-009; each rule mutated makes at least one
  check fail.
- **SC-005**: Listing an image whose files are not examined does no extra reads beyond one subheader read per
  file on a track that stores Form 2 data.

## Assumptions

- Assumption (autonomous run): the read-whole variant of the item's *Expected* is implemented; the fail-closed
  variant is not needed (every case can be decided at listing - an unreadable sector counts as 2048 and fails at
  unpack) and its Note asks for the maintainer's decision first. This realises option C of the decision item.
- Assumption (autonomous run): a mixed file is written as the concatenation of each sector's user data (2048 or
  2324 bytes) - all user data of every sector, nothing else (no subheaders); the item's Expected ("2324 bytes of
  each Form 2 sector, decided per sector by its subheader").
- Assumption (autonomous run): a file is examined only by FR-001's triggers, so a plain Mode 2 Form 1 disc costs
  one 24-byte read per file at listing, never a read of every sector. A file whose first sector is Form 1, whose
  record has no Form 2 bit and which lies outside a stream track (crafted only) stays as before - recorded as a
  limit.
- Assumption (autonomous run): 366's Form 2 files (XA Form 2 only, Form 2 first sector) are not re-examined -
  the item says they stay unchanged (366's NOTE 4: later Form 1 sectors of such a file stay a crafted-image
  limit).
- The probe uses 366's images (`img366.py`, real vcdimager 2.0.1 output in `%TEMP%\rev335c\data`).
