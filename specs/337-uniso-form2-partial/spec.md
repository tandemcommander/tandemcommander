# Feature Specification: A file covering part of a Form 2 stream no longer lets Unpack delete the image

**Feature Branch**: `337-uniso-form2-partial`  
**Created**: 2026-10-24  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-a-file-covering-part-of-a-form-2-stream-lets-the` - "ISO plug-in: a file covering part of a Form 2 stream lets the image be deleted". From backlog item iso-plug-in-a-file-covering-part-of-a-form-2-stream-lets-the.

## Background (traced and measured at 1c43d7d8)

The ISO plug-in (`uniso`, on in the default build) reads disc images with a track table (NRG, CCD/IMG).
Feature 335 takes a data track without a file system whose sectors 16..31 are Mode 2 Form 2 as a Video
CD's MPEG stream; feature 336 marks the listing incomplete (a whole unpack fails, "Delete archive after
unpacking" keeps the image) when no listed file *starts* in such a stream. A file that starts in it
counts as covering the whole stream, however few of its sectors the file holds.

Measured on the current build (hidden desktop, `specs/336-uniso-form2-uncovered/probe/iso336_probe.ps1
-Only S-VCDPART,S-VCDCOV,C-VCDCOV`): S-VCDPART (`avseq01.dat` of 2048 bytes = 1 of the stream's 64
sectors) extracts one sector and **deletes the image**; 336's own "covered" rows S-VCDCOV (NRG) and
C-VCDCOV (CloneCD) hold a file of 8 of the 64 data-filled sectors and **delete the image** too - 56
sectors lost each.

Real vcdimager 2.0.1 Video CD / SVCD images (feature 335's reviewer-3 images, `%TEMP%\rev335c\imgs`):
every `AVSEQnn` file starts at its stream track's first sector (INDEX 01) and covers it up to 150
sectors before the track's end (the next track's pregap, or the post-gap before the lead-out). Those
150 sectors are empty Form 2 sectors: subheader `00 00 20 00`, 2324 zero bytes of user data. The files'
own front / rear margins (inside the files) are zero too. A sector-count tolerance alone cannot tell
the cases apart (S-VCDPART leaves 63 data sectors uncovered, a real VCD 150 empty ones); the content of
the uncovered sectors can.

The unpack reads a listed file from the track its start extent maps to (`GetTrackFromExtent`), as
`ceil(size / 2048)` sectors from that extent on; sector *i* of a track is stored at the track's start
offset plus *i* stored sectors and has the disc address `ExtentOffset + i`.

## Clarifications

### Session 2026-10-24

- Q: What makes a stream track "covered (nearly to its end)"? → A: every sector of the track that no
  listed file starting in it reads (before, between or after the files) is an empty sector - its
  2324-byte Form 2 user data area is all zero - and there are at most 300 such sectors (two 2-second
  CD gaps of 150 sectors; vcdimager leaves 150). More uncovered sectors mark the listing without
  reading them; a sector that holds data, cannot be read, or is not stored whole marks it (autonomous
  run: item - *Expected* "reach (nearly) its end", *Notes* "a tolerance measured on real images";
  the measurement chose content over a count; conservative - fails closed)
- Q: Where does the stream track end? → A: at its track-table end (`End`) when that lies after its
  start; an end at or before the start is unknown and is replaced by the image file's end; when the
  next track starts later in the file than that end, the bytes up to the next track's start belong to
  the check too; nothing past the image file's end is counted. A wrong end that is too large can only
  add sectors to check (fails closed: kept); one that is too small is extended by the next track's
  start (autonomous run: item *Notes* "a wrong end must fail closed")
- Q: Which sectors does a listed file cover? → A: those the unpack reads: from its extent, `ceil(size /
  2048)` sectors, clipped to the track; only a file of more than zero bytes, with an ISO 9660 disc
  address, starting in a track numbered up to 255 (feature 336's guards); a file whose extent lies
  before the track's first sector covers nothing (autonomous run: rule of 336, conservative)
- Q: Does the unchanged 336 rule (no file starts in the stream → marked) stay? → A: yes (autonomous
  run: item)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A partly covered stream keeps the image (Priority: P1)

A user unpacks a whole disc image (NRG, CCD/IMG) with "Delete archive after unpacking". A listed file
starts in a Form 2 stream track but holds only part of it (a damaged or crafted directory record): the
rest of the stream is extracted nowhere. The listed files are extracted, but the image is kept.

**Why this priority**: it is the item's data loss - the image is the only copy of the rest of the stream.

**Independent Test**: probe rows S-VCDPART (1 of 64 sectors) and S-VCDCOV / C-VCDCOV / M-FORM2COV (8 of
64) - files extracted, the image kept.

**Acceptance Scenarios**:

1. **Given** an NRG image whose `avseq01.dat` covers 1 of its stream's 64 data sectors, **When** the
   whole image is unpacked with "Delete archive after unpacking", **Then** `a.txt` and `avseq01.dat`
   are extracted and the image is kept.
2. **Given** NRG, CloneCD and two-session NRG images whose file covers 8 of 64 data sectors, **When**
   unpacked likewise, **Then** the image is kept.
3. **Given** a stream whose file covers it fully except a tail of sectors that hold data, **When**
   unpacked likewise, **Then** the image is kept.

---

### User Story 2 - A fully covered stream and real Video CDs are still deleted (Priority: P1)

A stream whose listed file covers every sector, or whose uncovered sectors are only empty gap sectors
(a real Video CD / SVCD made by vcdimager), still lets the image be deleted after a whole unpack, as
before.

**Why this priority**: the item's *Expected* - real Video CDs keep today's behaviour.

**Independent Test**: new rows S-VCDFULL (a file over all 64 sectors) and S-VCDGAP (a file over 48
sectors, the last 16 empty Form 2 sectors) - deleted; feature 335's real vcdimager rows R-VCD-CCD,
R-SVCD-CCD, R-VCD-NRG - deleted; R-VCD-HOLE, X-SHORT - kept as before.

**Acceptance Scenarios**:

1. **Given** an NRG or CloneCD image whose file covers its whole stream, **When** unpacked with "Delete
   archive after unpacking", **Then** the files are extracted and the image deleted.
2. **Given** a real vcdimager VCD (CCD, NRG) or SVCD (CCD), **When** unpacked likewise, **Then** every
   file is extracted and the image deleted.
3. **Given** a stream whose file covers it except a tail of empty Form 2 sectors, **When** unpacked
   likewise, **Then** the image is deleted.

### Edge Cases

- A gap in the middle (two files with uncovered data sectors between them): marked; empty sectors
  between them are allowed (same rule).
- More than 300 uncovered sectors, even if empty: marked without reading them.
- A sector that cannot be read, or a stored sector not wholly inside the image file: marked.
- A stream track whose end is unknown (end at or before its start): measured to the image file's end
  (or the next track's start).
- Files from another track whose extent runs into the stream: do not cover it (the unpack reads them
  from their own track).
- Several stream tracks: each is decided on its own; any one marks the listing.
- "Session NN" folders on or off: the check runs once after the listing, as in 336.
- Memory exhausted while collecting the covered ranges: marked (fails closed).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A Form 2 stream track (feature 335) MUST mark the listing incomplete unless every one of
  its sectors that no listed file starting in it reads is an empty Form 2 sector, and there are at
  most 300 such sectors.
- **FR-002**: The sectors a listed file reads MUST be determined by the unpack's own rule: from its
  start extent, `ceil(size / 2048)` sectors, in the track its extent maps to; only files of more than
  zero bytes with an ISO 9660 disc address in a track up to 255 count.
- **FR-003**: A sector is empty only when it is stored wholly in the image and its 2324-byte user data
  area (after the subheader) is all zero; a failed or short read is not empty.
- **FR-004**: The stream track's extent MUST be taken so that a wrong track-table end fails closed
  (Clarification Q2).
- **FR-005**: The feature 336 rule (no listed file starts in a stream → marked) and every other track's
  handling MUST stay unchanged.
- **FR-006**: The coverage rules MUST be pure functions in `src/common/salisotrack.h` with `saltests`
  checks.
- **FR-007**: No UI text changes.

### Key Entities

- **Stream track**: a track-table data track without a file system whose sectors 16..31 are Mode 2
  Form 2; has a first disc address, a stored sector size and a sector count.
- **Covered range**: the track-relative sectors `[first, end)` a listed file reads.
- **Gap**: a run of the track's sectors no covered range includes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The rows S-VCDPART, S-VCDCOV, C-VCDCOV, M-FORM2COV, MF-FORM2COV (folders off) and the new
  data-tail row keep the image (deleted before).
- **SC-002**: S-VCDFULL, C-VCDFULL, S-VCDGAP and the real vcdimager images R-VCD-CCD, R-SVCD-CCD,
  R-VCD-NRG still delete the image after extracting every file.
- **SC-003**: Feature 335's and 336's other rows give the same verdicts as before.
- **SC-004**: saltests grow by the new checks, 0 failed; a mutant that ignores the gaps' content fails
  saltests and the probe.

## Assumptions

- Assumption (autonomous run): the 300-sector bound is two 150-sector CD gaps (pregap + post-gap);
  vcdimager leaves 150; another authoring tool with larger empty gaps keeps its image (fails closed, no
  data lost).
- Assumption (autonomous run): reading up to 300 stored sectors per stream track at listing time is
  cheap (under 1 MB); it happens only when a file starts in a stream.
- Assumption (autonomous run): the 2048-byte cut of Form 2 payloads (backlog item
  `iso-plug-in-video-cd-mpeg-files-in-form-2-sectors-may`, decision item
  `keep-video-cd-images-after-a-whole-unpack-until-their-video`) is out of scope; this feature decides
  coverage by sectors read.
- The track-table readers' own errors (Inbox `iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables`)
  stay out of scope; this feature only fails closed on them.
