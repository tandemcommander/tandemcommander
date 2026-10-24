# Feature Specification: A disc image with a data track whose file system is lost is kept by Unpack with "Delete archive after unpacking"

**Feature Branch**: `335-uniso-raw-track-lost`  
**Created**: 2026-10-24  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-a-data-track-in-which-no-file-system-is-found` - "ISO plug-in: a data track in which no file system is found lists nothing and is not marked". From backlog item iso-plug-in-a-data-track-in-which-no-file-system-is-found.

## Background (traced and measured at e363177e)

The ISO plug-in (`uniso`, on in the default build) reads disc images that carry a track table (NRG,
CCD/IMG, ...). A data track in which it finds no file system it knows is taken as a "raw data track":
it opens, lists nothing, and - since feature 334 - marks the listing incomplete only when the track
lies past the end of the image. A raw data track inside the image was left unmarked on purpose: a
Video CD / Super Video CD carries its MPEG video in such tracks, and marking them would make every
Video CD's whole unpack fail. The same rule leaves a data session whose file system was damaged
(its volume descriptors destroyed) unmarked: Unpack with "Delete archive after unpacking" extracts
the other sessions and deletes the image - the files of the damaged session are lost.

Measured on the Debug build at e363177e on the hidden desktop (probe `iso335_probe.ps1`; two ISO 9660
sessions by genisoimage - session 1 `a.txt`, session 2 `b.txt` - put into NRG images by `img335.py`).
Unpack (Alt+F9) of the whole image with "Delete archive after unpacking":

- two sessions, session 2's track (Mode 1) with every volume descriptor destroyed: `Session 01/a.txt`
  extracted, no message, **the image deleted - `b.txt` lost** (row M-NOFS);
- the same with session 2 a Mode 2 track of 2336-byte Form 1 sectors: **the image deleted** (M-NOFS-F1);
- one session of two tracks, track 2 with destroyed descriptors: `a.txt` extracted, **the image
  deleted** (S-NOFS); track 2 all zeros (feature 334's control S-RAW): **the image deleted**;
- controls: session 2 a Mode 2 / 2336 Form 1 track, intact: both files, the image deleted (M-OK-2336);
  session 2 a Mode 2 Form 2 stream: the image deleted (M-FORM2); a Video CD layout (an ISO 9660 track,
  then a Form 2 MPEG-like track): `a.txt`, the image deleted (S-VCD).

The distinction the item asks for exists: on a CD, a file system's volume descriptors are always in
Form 1 sectors (Mode 1, or Mode 2 Form 1 on CD-ROM XA); a Video CD's MPEG stream is in Mode 2 Form 2
sectors, whose subheader says so. The sector where every file system the plug-in reads is looked for
(the track's sector 16) tells them apart when the image stores the sector's header (raw sectors of
2352 bytes or more, or Mode 2 sectors of 2336 bytes). An image that stores only the 2048 bytes of user
data a sector cannot hold Form 2 data (2324 bytes a sector) at all - such a track is never a Video
CD's stream.

## Clarifications

### Session 2026-10-24

- Q: Can a data track whose content is lost be told apart from a legitimate raw track (the item's
  *Notes*: otherwise a decision for the maintainer)? → A: yes, by the track's sector 16 - a Mode 2
  Form 2 sector (both copies of its subheader's submode say Form 2) is a stream that never holds a
  file system (not marked, as today); anything else - Mode 1, Mode 2 Form 1, a sector whose header is
  destroyed or cannot be read, or a track stored as 2048-byte user data - is a file system area no
  reader understands: the track marks the listing (autonomous run: item - its *Expected* names this
  distinction; rule - CLAUDE.md "a safe to delete? check fails closed")
- Q: Does the mark apply in every listing mode? → A: yes, as feature 334's mark of a track past the end
  of the image: in the "Session NN" listing, in the single listing of a multi-session image, and in
  a one-session image's listing (the other tracks of one session are not in the listed track's
  directory) (autonomous run: rule - the track's files are not in any listing; conservative)
- Q: Feature 334's control S-RAW (a one-session image whose second track is Mode 1 zeros) expected the
  image deleted - keep that? → A: no; a Mode 1 track cannot be a Video CD's stream, and a track of zeros
  cannot be told from one whose content was zeroed - it is kept now (the row was 334's stand-in for a
  Video CD; the real Video CD layout is row S-VCD, still deleted) (autonomous run: item)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A damaged data session is not deleted with the image (Priority: P1)

A user unpacks a whole multi-session disc image (NRG, CCD/IMG) with "Delete archive after unpacking".
One session's file system is damaged - the plug-in finds none in its track and lists nothing for it.
The other sessions are extracted, but the image is kept, because the listing missed a track whose
content it could not show.

**Why this priority**: it is the data loss of the item - the image is the only copy of the damaged
session's files.

**Independent Test**: probe rows M-NOFS and M-NOFS-F1 - a two-session NRG whose session 2 has its
volume descriptors destroyed (Mode 1, and Mode 2 / 2336 Form 1): `Session 01/a.txt` extracted, no new
window, the image kept.

**Acceptance Scenarios**:

1. **Given** a two-session image whose session 2 track (Mode 1) has no file system the plug-in finds,
   **When** the user unpacks the whole image with "Delete archive after unpacking", **Then** session
   1's files are extracted and the image is kept.
2. **Given** the same with session 2 a Mode 2 track of Form 1 sectors, **When** unpacked the same way,
   **Then** the image is kept.
3. **Given** a two-session image whose sessions are intact (Mode 1, or session 2 Mode 2 / 2336 Form 1),
   **When** unpacked the same way, **Then** both sessions' files are extracted and the image is
   deleted (unchanged).

---

### User Story 2 - Video CDs unpack as before (Priority: P1)

A user unpacks a Video CD image (an ISO 9660 track, then MPEG tracks in Mode 2 Form 2 sectors) with
"Delete archive after unpacking". The listing is as before, the unpack succeeds and the image is
deleted - the MPEG stream tracks are not marked.

**Why this priority**: the item's *Notes* - marking every raw track would make every Video CD's whole
unpack fail.

**Independent Test**: probe row S-VCD (a one-session NRG: an ISO 9660 track, then a Mode 2 / 2336
Form 2 track) - `a.txt` extracted, the image deleted; row M-FORM2 (session 2 a Form 2 stream) - the
image deleted.

**Acceptance Scenarios**:

1. **Given** a Video CD layout image, **When** unpacked whole with "Delete archive after unpacking",
   **Then** the listed files are extracted and the image is deleted (unchanged).

---

### User Story 3 - A damaged track of a one-session image is not lost (Priority: P2)

A one-session image of several data tracks whose later track shows no file system: the plug-in lists
the track it can read; the track whose file system is lost marks the listing; a whole unpack keeps the
image.

**Why this priority**: the same loss in a less common layout.

**Independent Test**: probe rows S-NOFS (track 2 with destroyed descriptors) and S-RAW (track 2 Mode 1
zeros): `a.txt` extracted, the image kept.

**Acceptance Scenarios**:

1. **Given** a one-session image whose track 2 (Mode 1) shows no file system, **When** unpacked whole
   with "Delete archive after unpacking", **Then** `a.txt` is extracted and the image is kept.

### Edge Cases

- The track's sector 16 cannot be read, or its sync / header is destroyed: not a Form 2 stream - marked
  (fails closed).
- Only one copy of the subheader's submode says Form 2: not a Form 2 stream - marked.
- The track lies past the end of the image: marked, as feature 334 does (unchanged).
- A track stored as 2048-byte user data (NRG modes 0x00 / 0x02, ...): never a Form 2 stream - marked when
  no file system is found.
- An image without a track table (a plain `.iso`, ...): unchanged - this rule is for tracks of a track
  table only.
- A one-session image whose only data track has no file system does not open ("Unknown file format"):
  unchanged.
- A Form 2 stream in its own session (row M-FORM2): not marked - it holds no file system (limit, as
  today).
- Messages, the listing and the panel are unchanged; a kept image gets no explanation (as features 330
  - 334).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A data track of a track table in which no file system is found, lying within the image,
  MUST mark the listing incomplete (a whole unpack then fails and "Delete archive after unpacking"
  keeps the image) unless its sector 16 is a Mode 2 Form 2 sector.
- **FR-002**: A sector MUST count as Mode 2 Form 2 only when the image stores its header (2352 bytes or
  more a sector: a valid sync pattern and mode byte 2; 2336 bytes a sector: no sync) and its subheader
  is a valid CD-ROM XA subheader (both copies equal, channel below 32, at most one of the data / audio /
  video bits - review 1: a sector overwritten with 0xFF or text passed) whose submode has the Form 2
  bit; every other case (2048-byte sectors, Mode 1, Form 1, a destroyed or unreadable header) is not
  Form 2.
- **FR-003**: The mark MUST apply in every listing mode (session folders, the single listing of a
  multi-session image, a one-session image), as feature 334's mark of a track past the end does.
- **FR-004**: A track past the end of the image MUST stay marked (feature 334); tracks with a file
  system, audio and unknown tracks keep feature 334's rule unchanged.
- **FR-005**: The decision MUST be a pure rule in a header under `src/common/` with `saltests` checks.
- **FR-006**: No message, listing, panel or UI string changes; images without a track table are not
  affected.

### Key Entities

- **Raw data track**: a data track of a track table in which the plug-in finds no file system; its
  sector 16 decides whether its content is lost to the listing (marked) or a stream (not marked).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe `iso335_probe`: the four rows that delete the image at e363177e (M-NOFS, M-NOFS-F1,
  S-NOFS, S-RAW) keep it; the controls M-OK-2336, M-FORM2 and S-VCD still delete it - 14 / 14 PASS.
- **SC-002**: Probes of features 322, 329, 330, 333 and 334 pass as before, except feature 334's S-RAW,
  which now keeps the image (the intended change).
- **SC-003**: `saltests` passes with new checks of the rule; a mutant that takes every raw track as a
  stream (or none) fails them.

## Assumptions

- Assumption (autonomous run): real Video CD / SVCD images store their MPEG tracks with the sector
  header (CCD/IMG: 2352 bytes; NRG: 2336 or 2352 bytes) - a Video CD track stored as 2048-byte user
  data would have lost its Form 2 data already. No real Video CD image was tried (none in the
  repository; a person step records it).
- Assumption (autonomous run): the probe drives NRG images (ETNF chunk: Mode 1 / 2048 and Mode 2 / 2336);
  the 2352-byte layout (CCD/IMG, NRG DAO raw) is covered by the rule's `saltests` checks, not by a probe
  row.
