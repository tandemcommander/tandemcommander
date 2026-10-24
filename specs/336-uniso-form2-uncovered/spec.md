# Feature Specification: A Form 2 track that no listed file covers keeps the image after Unpack with "Delete archive after unpacking"

**Feature Branch**: `336-uniso-form2-uncovered`  
**Created**: 2026-10-24  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-a-form-2-track-that-no-listed-file-covers-is` - "ISO plug-in: a Form 2 track that no listed file covers is deleted with the image". From backlog item iso-plug-in-a-form-2-track-that-no-listed-file-covers-is.

## Background (traced and measured at e2e41399)

The ISO plug-in (`uniso`, on in the default build) reads disc images that carry a track table (NRG,
CCD/IMG, ...). Since feature 335, a data track in which no file system is found marks the listing
incomplete (a whole unpack fails, "Delete archive after unpacking" keeps the image) unless its
sectors 16..31 are Mode 2 Form 2 - a Video CD's MPEG stream. Such a Form 2 track is taken as safe
whether or not any listed file covers it. On a real Video CD / Super Video CD the stream is extracted
through the `MPEGAV/AVSEQnn.DAT` / `MPEG2/AVSEQnn.MPG` entries of track 1's ISO 9660 directory, whose
extents start in the stream tracks. A Form 2 track that no directory references - a stream in a
session of its own, a Video CD whose ISO 9660 track lost those file entries - lists nothing, the
listing is not marked, and the whole unpack deletes the image with the stream.

Measured: the plug-in's sources are unchanged since d9406b9b (the last commit of feature 335);
feature 335's probe on that code (`specs/335-uniso-raw-track-lost/probe/result_after_review4.txt`)
shows the rows S-VCD (one session; track 2 a 64-sector Form 2 stream that no directory references)
and M-FORM2 (the stream in a session of its own) extracting `a.txt` only and **deleting the image**;
C-VCD and C-VCDREAL (CloneCD images, the same: no file covers track 2) likewise. Reviewer 3 of 335
measured real vcdimager images (VCD and SVCD as CloneCD, VCD as NRG): every file extracted, the image
deleted - the files `AVSEQ01.DAT` / `AVSEQ01.MPG` carry the streams.

## Clarifications

### Session 2026-10-24

- Q: Which listed entries cover a Form 2 track? → A: a listed file (not a folder) whose start extent
  maps to the track by the same rule the unpack uses to find the track it reads the file from
  (`GetTrackFromExtent`); its size must be above zero - a file of zero bytes extracts nothing of the
  track (autonomous run: item - *Approach* "a listed file's extent starts in the track"; conservative
  for the zero-size file: it fails closed)
- Q: The item's *Expected* names feature 335's synthetic rows C-VCD and C-VCDREAL as still deleted,
  but their stream track is referenced by no file - keep them deleted? → A: no; the item's rule
  (a Form 2 track no listed file starts in marks the listing) decides, and those images now keep
  the image like S-VCD and M-FORM2. The deletion controls are the real vcdimager images (R-VCD-CCD,
  R-SVCD-CCD, R-VCD-NRG) and new synthetic images whose track 1 holds a file whose extent starts in the
  stream track (autonomous run: item - its main rule; conservative - keeping the image loses no data)
- Q: Does the rule apply to images without a track table? → A: no; only tracks that feature 335
  decided to be Form 2 streams (a track table's data track with no file system whose sectors 16..31
  are Form 2) are checked; every other track keeps its present handling (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A Form 2 stream no file covers is not deleted with the image (Priority: P1)

A user unpacks a whole disc image (NRG, CCD/IMG) with "Delete archive after unpacking". One of its
data tracks is a Mode 2 Form 2 stream that no listed file refers to - its content appears nowhere in
the listing. The other files are extracted, but the image is kept, because the stream would be lost
with it.

**Why this priority**: it is the data loss of the item - the image is the only copy of the stream.

**Independent Test**: probe rows S-VCD, M-FORM2, C-VCD, C-VCDREAL - `a.txt` extracted, no new window,
the image kept.

**Acceptance Scenarios**:

1. **Given** a one-session image whose track 1 holds ISO 9660 with `a.txt` and whose track 2 is a
   Form 2 stream that no file refers to, **When** the user unpacks the whole image with "Delete archive
   after unpacking", **Then** `a.txt` is extracted and the image is kept.
2. **Given** a two-session image whose session 2 is a Form 2 stream, listed with "Session NN" folders,
   **When** the user unpacks the whole image the same way, **Then** `Session 01/a.txt` is extracted and
   the image is kept.

---

### User Story 2 - A real Video CD still unpacks whole and is deleted (Priority: P1)

A user unpacks a whole Video CD or Super Video CD image whose stream tracks are covered by its
`AVSEQnn` files. Every file is extracted and the image is deleted, as before.

**Why this priority**: without it every Video CD's whole unpack would fail - the cost the item
accepts only for Video CDs whose directory does not reference a stream.

**Independent Test**: reviewer 3's real vcdimager images (R-VCD-CCD, R-SVCD-CCD, R-VCD-NRG) and new
synthetic images whose track 1 holds a file whose extent starts in the stream track (rows S-VCDCOV,
C-VCDCOV): every file extracted, the image deleted.

**Acceptance Scenarios**:

1. **Given** a real VCD (CloneCD or NRG) or SVCD (CloneCD) image made by vcdimager, **When** the user
   unpacks it whole with "Delete archive after unpacking", **Then** every file is extracted and the
   image is deleted.
2. **Given** a synthetic image whose track 1 lists `a.txt` and a file whose extent starts at the Form 2
   track, **When** the user unpacks it whole the same way, **Then** both files are extracted and the
   image is deleted.

### Edge Cases

- Several Form 2 tracks, only some covered: each uncovered one marks the listing (the image is kept).
- A file whose extent starts in an earlier track and runs on into the Form 2 track does not cover it
  (only the start extent counts, as the unpack reads it).
- A covering file of zero bytes: does not cover (nothing of the track is extracted).
- A folder whose extent lies in the Form 2 track: does not cover.
- An audio track's virtual entry (no position data): ignored.
- The listing with "Session NN" folders off (one listing of the last data track): the same rule.
- A track that feature 335 already marks (no file system, not Form 2) or a track with a file system:
  unchanged.
- An image without a track table: unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: After the image is listed, each data track that feature 335 took as a Form 2 stream
  MUST mark the listing incomplete when no listed file of more than zero bytes starts in it.
- **FR-002**: "Starts in" MUST use the same mapping from a file's start position to a track that the
  unpack uses to read the file (one rule, shared, tested).
- **FR-003**: A Form 2 track that a listed file starts in MUST NOT mark the listing (a real Video CD /
  SVCD still unpacks whole and is deleted).
- **FR-004**: The rule MUST apply in every listing mode (with and without "Session NN" folders, one or
  more sessions).
- **FR-005**: The decision (which track a start position maps to; whether a stream track marks) MUST be
  a pure rule in a header under `src/common/` with `saltests` checks.
- **FR-006**: Tracks that are not Form 2 streams, and images without a track table, MUST keep their
  present behaviour.
- **FR-007**: No UI string, dialog or setting changes; the existing "incomplete listing" path does the
  rest (a whole unpack fails, the image is kept).

### Key Entities

- **Form 2 stream track**: a data track of a track table with no file system whose sectors 16..31 are
  Mode 2 Form 2 (feature 335).
- **Listed file**: an entry of the listing with a start position (extent) and a size.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe rows S-VCD, M-FORM2, C-VCD, C-VCDREAL keep the image (before: deleted).
- **SC-002**: The real vcdimager rows R-VCD-CCD, R-SVCD-CCD, R-VCD-NRG and the new covered rows
  extract every file and delete the image.
- **SC-003**: Feature 335's other rows and the regression probes of 322, 329, 330, 333, 334 give the
  same verdicts as before (except the rows the change is meant to turn).
- **SC-004**: `saltests` passes with new checks of the rule; a mutant that ignores coverage fails them.

## Assumptions

- Assumption (autonomous run): GUI probes need the maintainer's installed Tandem Commander closed (they
  share its registry key); when it keeps running through the run, the rows are recorded NOT DRIVEN and
  owed to a person.
- Assumption (autonomous run): the extents listed by HFS / UDF / Xbox readers are mapped by the same
  rule; on such discs a Form 2 stream track is not expected - a wrong mapping can only make a stream
  covered (as before this feature), never lose a mark this feature adds for ISO 9660.
- Out of scope: Video CD files read cut to 2048 bytes a sector (Inbox
  `iso-plug-in-video-cd-mpeg-files-in-form-2-sectors-may`); NRG ETNF / ETN2 / multi-session CCD
  table defects (Inbox `iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables`).
