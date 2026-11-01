# Feature Specification: The ISO plug-in extracts Video CD / SVCD video files whole (2324 bytes of every Form 2 sector)

**Feature Branch**: `366-uniso-form2-files`  
**Created**: 2026-11-01  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-video-cd-mpeg-files-in-form-2-sectors-may` - "ISO plug-in: Video CD MPEG files in Form 2 sectors may extract cut to 2048 bytes a sector". From backlog item iso-plug-in-video-cd-mpeg-files-in-form-2-sectors-may.

## Background (measured at 308896b0)

A Video CD / SVCD keeps its video (`MPEGAV/AVSEQnn.DAT`, `MPEG2/AVSEQnn.MPG`) in CD-ROM XA Mode 2 Form 2
sectors, whose user data is 2324 bytes (a Form 1 sector carries 2048 bytes plus error correction). The
ISO 9660 directory gives such a file a size of sectors x 2048 and marks it in its CD-XA system-use record
(attribute bit "Mode 2 Form 2"). The ISO plug-in (`uniso`, on in the default build) reads every file 2048
bytes a sector, so a video file extracts cut: only the first 2048 of each sector's 2324 bytes.

Measured on the build of `main` with 335 reviewer 3's real vcdimager 2.0.1 images (VCD 2.0 and SVCD made from
ffmpeg pal-vcd / pal-svcd MPEGs, `v.mpg` / `s.mpg`, laid out as CloneCD and NRG by
`specs/335-uniso-raw-track-lost/probe/review3/gen335c.py`), hidden-desktop probe `rev335c_probe.ps1`, whole
Unpack with "Delete archive after unpacking":

- VCD (CCD and NRG): `MPEGAV/AVSEQ01.DAT` extracted as 608,256 bytes (297 x 2048) - byte for byte the first 2048
  bytes of each of its 297 sectors' user data; the image was deleted.
- The record of `AVSEQ01.DAT`: XA attributes 0x1555 (Form 2 bit 0x1000, no Form 1 bit); all 297 sectors are
  Form 2 by their subheaders. `INFO.VCD` / `ENTRIES.VCD`: 0x0D55 (Form 1 bit 0x0800); folders 0x8D55.
- The source `v.mpg` (515,928 bytes = 222 x 2324) is not in the extracted file; it lies whole in the 2324-byte
  user data of the 297 sectors (690,228 bytes; the rest - the disc's front and rear margins - zero bytes).
  The extracted file misses 276 bytes of every MPEG pack (61,272 bytes).
- SVCD: `MPEG2/AVSEQ01.MPG` extracted as 292,864 bytes (143 x 2048); its 143 sectors x 2324 = 332,332 bytes
  = `s.mpg` exactly.

With "Delete archive after unpacking" the image - the only copy of the full stream - is deleted after the
cut extraction (the decision item `keep-video-cd-images-after-a-whole-unpack-until-their-video` asks what to
do until this is fixed; its option C is this feature).

## Clarifications

### Session 2026-11-01

- Q: Is a file whose XA attributes have the Form 2 and the interleaved bits but not the Form 1 bit read as a Form 2 file? → A: Yes - the item names "a file whose ISO 9660 XA attribute says Form 2"; without the Form 1 bit every sector of it is Form 2 (autonomous run: item)
- Q: Should a Video CD video file on an image that stores only 2048 bytes a sector (a cooked `.iso`) get a message or mark the listing? → A: No - nothing more is stored to extract; it lists and extracts as before (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A Video CD's video files extract whole (Priority: P1)

A user opens a Video CD or SVCD disc image (CloneCD `.img` + `.ccd`, Nero `.nrg`, or another raw image the
plug-in reads with whole sectors) and extracts `AVSEQ01.DAT` / `AVSEQ01.MPG` - one file, or a whole Unpack
with "Delete archive after unpacking". The extracted file holds every byte of video the disc stores: all
2324 user bytes of each of its sectors, so the MPEG the disc was made from lies whole in it (an SVCD file
equals it exactly; a VCD file adds the disc's zero-filled margins around it).

**Why this priority**: it is the item - the video was silently cut and, with "Delete archive after
unpacking", the image holding the full stream deleted.

**Independent Test**: the real vcdimager VCD (CCD, NRG) and SVCD images: extract, compare with the source
MPEG.

**Acceptance Scenarios**:

1. **Given** the real VCD image as CloneCD, **When** the whole image is unpacked, **Then** `MPEGAV/AVSEQ01.DAT`
   is 690,228 bytes, equals the 2324-byte user data of its 297 sectors, and contains `v.mpg` whole.
2. **Given** the same VCD as NRG (2336-byte sectors), **When** unpacked, **Then** the same file content.
3. **Given** the real SVCD image, **When** unpacked, **Then** `MPEG2/AVSEQ01.MPG` equals `s.mpg` byte for byte.
4. **Given** any of these images, **When** listed in the panel, **Then** the video file shows the size it
   extracts with (sectors x 2324).

---

### User Story 2 - Everything else extracts as before (Priority: P1)

Files that are not Form 2 - every file of a data CD / DVD, the Form 1 files of a Video CD (`INFO.VCD`,
`ENTRIES.VCD`), files on images that store only 2048 bytes a sector (an `.iso` made of a Video CD cannot
hold the 2324 bytes) - extract and list exactly as before.

**Why this priority**: the change must not alter any other file.

**Independent Test**: the regressions probes of the ISO plug-in's Form 2 / track features (335, 336, 337,
365) and the Form 1 files of the real images.

**Acceptance Scenarios**:

1. **Given** a Video CD image, **When** unpacked, **Then** `VCD/INFO.VCD` and `VCD/ENTRIES.VCD` are 2048 bytes
   and unchanged.
2. **Given** a file whose record has XA attributes saying Form 2 but whose first sector is not a Form 2 sector
   (a Mode 1 track, a damaged or crafted record), **When** listed and extracted, **Then** it extracts as before
   (2048 bytes a sector, its record's size).
3. **Given** a cooked image (2048-byte sectors) of a Video CD, **When** unpacked, **Then** the video file extracts
   as before (the image holds nothing more).

---

### User Story 3 - A whole unpack still keeps an image only when something is missing (Priority: P2)

Features 336 / 337 keep a Video CD image after a whole unpack when its stream track holds data no listed
file extracts. With the video files now read 2324 bytes a sector, the sectors they read are counted with
that size: a real Video CD still counts as fully extracted (and is deleted, now rightly), a stream a file
covers only in part still keeps the image.

**Why this priority**: data safety of "Delete archive after unpacking" - the coverage count must follow the
new size, or a file would count as covering more sectors than it reads.

**Independent Test**: probe `iso337_probe` (partial / gap rows) and the real images.

**Acceptance Scenarios**:

1. **Given** a real VCD / SVCD image, **When** unpacked whole with "Delete archive after unpacking", **Then** every
   file is extracted whole and the image is deleted.
2. **Given** a stream whose Form 2 file covers only part of it, **When** unpacked whole, **Then** the image is kept.

### Edge Cases

- A file's record says Form 2 and Form 1 (an interleaved mixed file, as on some game discs): unchanged (2048
  bytes a sector) - per-sector sizes are out of this item's scope.
- A Form 2 file in the ISO 9660 data track itself (not in a separate stream track): read 2324 bytes a sector
  as well.
- A Form 2 file of zero bytes: stays zero bytes.
- A Form 2 file whose sectors run past the image's end or its track: the read fails as before (error / Skip),
  the incomplete file is removed - never a file with made-up bytes.
- A track stored with a sector layout whose Form 2 user data position is not where the plug-in reads the user
  data (a Mode 1 track, a 2448-byte track read with a 16-byte header): unchanged.
- No XA record in the file's directory entry (a plain ISO 9660 disc, review 2 of 335's crafted `a.txt`):
  unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A file of an ISO 9660 directory is a Form 2 file when its directory record carries a CD-XA
  system-use record whose attributes have the Form 2 bit and not the Form 1 bit (nor the directory bit; the
  interleaved bit does not matter), the
  track its first sector lies in stores the full Form 2 user data at the position the plug-in reads user data
  from, and that first sector is a valid Mode 2 Form 2 sector by its subheader (feature 335's rule).
- **FR-002**: A Form 2 file is listed with the size sectors x 2324, where sectors is the record's size in
  2048-byte units rounded up; a zero-byte record stays zero bytes.
- **FR-003**: A Form 2 file is extracted (one file, a selection, a whole Unpack, a viewer's temporary copy)
  reading 2324 bytes of user data from each of its sectors; a sector that cannot be read whole is a read error
  (the existing Skip / Cancel handling; the incomplete file is removed).
- **FR-004**: Every other file is listed and extracted exactly as before.
- **FR-005**: Features 336 / 337's stream coverage counts the sectors a Form 2 file reads with 2324 bytes a
  sector (a Form 2 file of N x 2324 bytes reads N sectors), every other file with 2048 as before.
- **FR-006**: The decisions of FR-001, FR-002 and FR-005 are pure rules in a header under `src/common/` with
  `saltests` checks.
- **FR-007**: No UI string, dialog, setting, plug-in interface or stored data changes.

### Key Entities

- **CD-XA system-use record**: 14 bytes at the start of a directory record's system-use area - owner ids (4),
  attributes (2, big-endian), the signature "XA" (2), file number (1), reserved (5). Attribute bits: 0x0800
  Mode 2 Form 1, 0x1000 Mode 2 Form 2, 0x2000 interleaved, 0x4000 CD-DA, 0x8000 directory.
- **Form 2 file**: a listed file read 2324 bytes a sector (FR-001).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On the real vcdimager images, the extracted `AVSEQ01.DAT` (CCD and NRG) contains the 515,928-byte
  source MPEG whole and equals the 297 sectors' 2324-byte user data; the SVCD's `AVSEQ01.MPG` equals its
  332,332-byte source - 0 bytes lost (before: 61,272 / 39,468 bytes lost).
- **SC-002**: The Form 1 files of those images and every file of the ISO plug-in's earlier probe images extract
  with the same sizes and verdicts as before (the regression probes' recorded results).
- **SC-003**: `saltests` passes with new checks for the XA record, the Form 2 decision, the size and the
  coverage span; a mutant of each rule fails at least one check.

## Assumptions

- Assumption (autonomous run): the decision is by the file's XA attribute (the item's first criterion),
  confirmed by its first sector's subheader; per-sector decisions for files without an XA record or with mixed
  Form 1 / Form 2 sectors are not made (the item's "or whose sectors' subheaders say Form 2" read as an
  alternative criterion; the conservative choice keeps every file without an XA Form 2 attribute unchanged).
- Assumption (autonomous run): "extracts byte for byte" means all 2324 user bytes of every sector of the file
  (the Form 2 user data, as an SVCD file equals its source exactly); the zero-filled margins a VCD keeps inside
  its file are part of the file and are extracted too (no MPEG-aware stripping).
- The real images come from 335 reviewer 3's vcdimager output kept in WSL (`~/rev335c`); no physical disc dump
  is tried (the person step `check-feature-335-with-real-nrg-and-clonecd-dumps-of-video` stays).
- The decision item `keep-video-cd-images-after-a-whole-unpack-until-their-video` is the maintainer's; this
  feature is its option C and does not change it.
