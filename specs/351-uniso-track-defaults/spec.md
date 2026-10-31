# Feature Specification: Every track of a disc image starts with defined values

**Feature Branch**: `351-uniso-track-defaults`  
**Created**: 2026-10-31  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-a-track-of-a-ccd-or-nrg-image-may-keep-an` - "ISO plug-in: a track of a CCD or NRG image may keep an uninitialised file-system type". From backlog item iso-plug-in-a-track-of-a-ccd-or-nrg-image-may-keep-an.

## Background (measured at d760ed1a)

The ISO plug-in (`uniso`, on in the default build) opens a disc image with a track table - a
CloneCD image (`.img` + `.ccd`) or a Nero image (`.nrg`) - by building one track record per track
the table names, then detecting the file system of every track whose type is neither "unknown" nor
"audio". The track record's constructor sets only a few of its fields (the file-system object, the
boot flag, and 335 / 336's flags); its file-system type, mode, sector size, header size, start, end
and extent offset keep whatever the memory held.

- The CloneCD reader sets the type only for an audio track (CCD mode 0). A Mode 1 or Mode 2 data
  track keeps the memory's value: in the Debug build the allocator fills new memory with 0xCD, a
  value that is neither "unknown" nor "audio", so the track is detected by chance; in the Release
  build the value is often 0 ("unknown") - the data track is never detected and the image does not
  open ("Unknown file format or not a valid ISO image"), or, with other tracks, its files are not
  listed.
- The Nero reader makes one track per CUEX entry and fills it from the DAOX entry of the same
  number. A CUEX track that no DAOX entry describes (a DAOX chunk naming fewer tracks, an entry
  skipped by feature 331's range check, CUEX index points paired into extra tracks - 350's limit)
  keeps every field the memory held: it can be detected as a data track at garbage start / end, or
  listed as an audio track of garbage size.

Measured with the hidden-desktop probe `iso351_probe` (images by `img351.py` from feature 334's
`mkimg334.sh` seeds; Unpack, Alt+F9, with "Delete archive after unpacking"), three runs on the
0.2.0 Release build (built from tag `v0.2.0`; the track constructor and the CloneCD reader are
unchanged since): a CloneCD image of one Mode 1 track (C-M1), of one Mode 2 Form 1 track (C-M2) and
of two sessions of one Mode 1 track each (C-M1M1) showed "Unknown file format or not a valid ISO
image" and extracted nothing in 7 of 9 runs (C-M1 2 / 3, C-M2 2 / 3, C-M1M1 3 / 3) - at random. The
NRG control (N-ONE) and an NRG whose DAOX describes only track 1 of two CUEX tracks (N-UNDESC, the
image kept) passed. The Debug build at d760ed1a passes all five rows.

## Clarifications

### Session 2026-10-31

- Q: Which file-system type does a track have before a reader describes it? → A: "unknown" - the
  type under which a track is never detected nor listed, and (feature 334) marks the listing
  incomplete, so a whole unpack keeps the image (autonomous run: item - *Expected*, "a track the
  track table does not describe is not listed with garbage bounds"; conservative - refuses rather
  than guesses)
- Q: Which type does the CloneCD reader give a Mode 1 / Mode 2 data track? → A: a data type that
  makes `Open` detect the track's file system (the same value the Nero reader gives a data track,
  ISO 9660, which detection replaces) (autonomous run: item - *Expected*, "set by the CCD reader for
  modes 1 / 2")
- Q: What about a CloneCD track whose MODE is neither 0, 1 nor 2? → A: it stays "unknown" (mode
  none) - never detected, never listed, the listing marked incomplete (autonomous run:
  conservative - before, it kept the memory's value)
- Q: Which values do the other fields get? → A: zero / none: sector size 0, header size 0, mode
  none, start 0, end 0, extent offset 0; every reader that describes a track overwrites them as
  before (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A CloneCD data image opens every time (Priority: P1)

A user opens or unpacks a CloneCD image (`.img` with its `.ccd`) of a data disc with the Release
build. The image opens and lists its files every time, not at random.

**Why this priority**: the item's main point, measured: in the shipped build such an image did not
open in 7 of 9 tries.

**Independent Test**: probe rows C-M1, C-M2, C-M1M1 on a Release build of the fix, repeated: every
run extracts the files and deletes the image (the unpack complete).

**Acceptance Scenarios**:

1. **Given** a CloneCD image of one Mode 1 data track, **When** the user unpacks it whole with
   "Delete archive after unpacking", **Then** its file is extracted and the image deleted, in every
   run.
2. **Given** a CloneCD image of one Mode 2 Form 1 data track, **When** the same, **Then** the same.
3. **Given** a CloneCD image of two sessions of one Mode 1 track each, **When** the same, **Then**
   both sessions' files are extracted into "Session 01" / "Session 02" and the image deleted.

---

### User Story 2 - A Nero track the track table does not describe is not listed with garbage bounds (Priority: P2)

A user opens an NRG image whose CUEX chunk names more tracks than its DAOX chunk describes. The
undescribed track is taken as unknown: it is not detected at a garbage position, not listed as an
audio track of garbage size; the listing is marked incomplete, so a whole unpack keeps the image.

**Why this priority**: the second half of the item's *Expected*; the measured outcome (the image
kept) does not change, the track's values become defined.

**Independent Test**: probe row N-UNDESC: a.txt extracted, no window, the image kept - in Debug and
Release.

**Acceptance Scenarios**:

1. **Given** an NRG image with two CUEX tracks and a DAOX entry for track 1 only, **When** the user
   unpacks it whole with "Delete archive after unpacking", **Then** track 1's file is extracted, no
   window shows, and the image is kept.

---

### User Story 3 - Images that opened before open as before (Priority: P1)

Intact NRG images (CUEX + DAOX, ETNF, ETN2), CloneCD images with audio tracks, and plain images
without a track table open and list as before.

**Independent Test**: probe row N-ONE; the probes of features 334, 335 and 350 on the Debug build of
the fix give their recorded results.

**Acceptance Scenarios**:

1. **Given** an NRG image of one described Mode 1 track, **When** the user unpacks it whole,
   **Then** its file is extracted and the image deleted, as before.

### Edge Cases

- A CloneCD track of MODE 3 or another value: unknown (mode none), never detected nor listed, the
  listing marked incomplete (before: the memory's value).
- An NRG image whose DAOX chunk comes before its CUEX chunk: the DAOX entries apply to no track (331),
  every CUEX track stays unknown - nothing is detected at a garbage position.
- A CUEX index point paired into an extra track (350's limit, real Nero images with index points):
  the extra track is unknown, never listed; it marks the listing, as an audio track already does
  (such images are audio discs - 334 marks their listing anyway).
- An image without a track table (plain ISO, MDF, ...): the single track's mode is set from the
  detected sector type as before; for a sector type that names no mode it is "none" instead of the
  memory's value.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every track record MUST have a defined value in every field from its construction:
  file-system type "unknown", mode "none", sector size, header size, start, end and extent offset 0,
  no file system, not bootable, and the flags `RawLost` (334 / 335) and `Form2Stream` (336) off.
- **FR-002**: The CloneCD reader MUST give a track of CCD mode 1 or 2 a data file-system type that
  makes the plug-in detect the track's file system, and a track of mode 0 the audio type (as
  before); a track of any other mode MUST stay unknown.
- **FR-003**: A Nero CUEX track that no DAOX entry describes MUST stay unknown with zero bounds - it
  is not detected, not listed, and marks the listing incomplete (feature 334's rule for an unknown
  track).
- **FR-004**: Every track that a reader describes MUST keep the values the reader gives it - an
  intact image opens and lists as before.
- **FR-005**: The CloneCD mode rule (mode -> audio / data / unknown) MUST be a pure function next to
  feature 334's track rules (`src/common/salisotrack.h`) with `saltests` checks.

### Key Entities

- **Track record**: one per track of the image's track table - file-system type, mode, sector size,
  header size, start, end, extent offset, the file-system object and 334-336's flags.
- **CloneCD track mode**: `MODE=` of a `[TRACK n]` section of the `.ccd` file - 0 audio, 1 Mode 1
  data, 2 Mode 2 data.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a Release build of the fix, the CloneCD rows C-M1, C-M2 and C-M1M1 pass in every
  one of at least three runs (before: 7 of 9 runs failed with "Unknown file format").
- **SC-002**: N-UNDESC passes on Debug and Release (an undescribed NRG track keeps the image, no
  window); N-ONE passes. (A regression row: N-UNDESC passes before the fix too - the heap's value
  marked the listing either way; that the undescribed track's fields are now defined rests on
  reading, fix-log T009 and review 1.)
- **SC-003**: The Debug build, with the CloneCD reader's data type removed (a mutant), fails C-M1,
  C-M2 and C-M1M1 every time - the probe sees the defect deterministically once the constructor
  gives "unknown".
- **SC-004**: The recorded results of the 334, 335 and 350 probes do not change on the Debug build
  of the fix.
- **SC-005**: `saltests` checks of the CloneCD mode rule fail when the rule is mutated.

## Assumptions

- Assumption (autonomous run): the Release measurement uses the 0.2.0 Release tree (unchanged code
  at the sites); the after measurement uses a Release build of the fix - built in a separate build
  folder so the 0.2.0 tree stays as it is.
- Assumption (autonomous run): "unknown" for an undescribed track is the conservative value - the
  track's content cannot be found without its bounds, so the listing is marked incomplete rather than
  guessed.
- No real CloneCD / Nero image of a pressed disc is tried (crafted images); the person steps of 334 /
  335 already ask for real images.
- The plug-in interface, the stored settings and the UI texts do not change.
