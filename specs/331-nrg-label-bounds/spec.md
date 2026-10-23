# Feature Specification: An NRG image's CD-Text labels and track table never reach past a buffer

**Feature Branch**: `331-nrg-label-bounds`  
**Created**: 2026-10-24  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-an-nrg-audio-track-label-of-257-bytes-overruns-a` - "ISO plug-in: an NRG audio track label of 257+ bytes overruns a stack buffer". From backlog item iso-plug-in-an-nrg-audio-track-label-of-257-bytes-overruns-a.

## Background (traced at d87666d5)

The ISO plug-in (`uniso`, on in the default build) opens Nero images (`.nrg`) by reading the chunk
list at the end of the file (`ReadSessionInfo` -> `ReadSessionNRG` -> `ReadNRGRoot`): `CUEX` adds one
track per entry, `DAOX` fills in the tracks' sector size, mode and extent, `CDTX` (CD-Text) gives the
volume label and one label per track. An audio track is listed as one file named `NN <label>` (or
`Audio Track NN` without a label) by `CAudio::ListDirectory`.

Every site the item names is still present at HEAD (read; the Debug x64 build of HEAD succeeds):

- `CAudio::ListDirectory` formats `"%02d %s"` with `sprintf` into `char audioTrack[MAX_PATH]` - a
  label of 257 bytes or more writes past the stack buffer.
- `readCDTX` sizes its buffer as `header->Size + 1 + trackCount` in 32-bit unsigned arithmetic (a
  size near 4 GiB wraps to a few bytes, which the read then fills), reads the 12-byte text blocks
  with a bound that ignores the 4 skipped flag bytes (up to 4 bytes past the chunk), places the
  terminator area at `12 * ceil(Size / 18)` - past the buffer for chunk sizes below 36 - and does not
  check how much was read.
- `readDAOX` takes the first and last track number from the image and writes through
  `GetTrack(number - 1)`: track 0 gives `NULL`, and `CISOImage::GetTrack` accepts an index equal to
  the track count (`track <= Tracks.Count`, off by one), so a track number one past the `CUEX`
  tracks reaches past the track table. Its entry reads are not checked for a full read.

Feature 329 made the audio reader ask the panel listing's rule first: a track name the listing
refuses (256 bytes and more) is left out alone and named in the "(206)" report, and a whole unpack of
such a listing fails (the image is kept). That path is only reached for names up to 259 bytes today.

## Clarifications

### Session 2026-10-24

- Q: How long may a listed track name be? → A: as long as its label - the name is built on the heap
  and never cut; the panel listing's rule (feature 329) then decides, so a name it refuses is left
  out and reported (autonomous run: item - *Expected*; rule - "a path or name is never cut")
- Q: What does the reader do with a CD-Text chunk that claims more bytes than the image still holds
  after it, or whose buffer cannot be allocated? → A: it takes no labels from it (tracks keep the
  `Audio Track NN` names) and moves past the chunk as for any other chunk; a chunk past the end of the
  image then ends the chunk list the way a truncated image does today (autonomous run: conservative -
  refuses rather than guesses, no new message)
- Q: What does the reader do with a DAOX entry whose track number is not one of the tracks the CUEX
  chunk added (0, or above the track count)? → A: the entry is read (the position in the chunk list
  stays as before) and not applied to any track (autonomous run: conservative - nothing is written
  outside the track table, the other entries keep their effect)
- Q: Should the other NRG readers (CUEX size, SINF session counts, ETNF / ETN2) be hardened too? →
  A: no - outside the item; recorded as an Inbox item if a defect is found (autonomous run: rule -
  scope, stop-rules §2.11)
- Q: Is a CD-Text chunk that fits in the image also limited by a fixed maximum size? → A: no - the
  image's own size bounds it and a failed allocation gives no labels; a fixed cap could drop the
  labels of a real image and is not needed for safety (autonomous run: conservative - changes least
  for consistent images)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A long CD-Text label is listed or reported, never written past a buffer (Priority: P1)

A user opens an NRG image whose CD-Text gives an audio track a long label (257 bytes or more, from a
damaged or crafted file). The plug-in lists the image: a track whose name the panel listing takes is
listed under its whole name; one it refuses is left out and named in the existing "(206)" report;
nothing is written past a buffer and the program keeps running.

**Why this priority**: it is the item's main point - a stack overrun while listing a file the user
merely opened.

**Independent Test**: the pure rule of the track name (its length equals 3 + the label's length for
tracks 1-99, never cut) in `saltests`; the listing code builds the name on the heap and passes it to
feature 329's listing rule, which refuses a name over the listing's bound.

**Acceptance Scenarios**:

1. **Given** an NRG image whose track 2 has a label of 300 bytes, **When** it is opened, **Then** track 1
   is listed, track 2 is left out and named in the "(206)" report, and nothing is written past a
   buffer.
2. **Given** an NRG image whose labels fit (feature 329's 253-byte label and a short one), **When** it
   is opened, **Then** the behaviour is unchanged from feature 329 (the 256-byte name reported, the
   short one listed).

---

### User Story 2 - The CD-Text and DAOX readers check the image's sizes and track numbers (Priority: P1)

The same user opens an NRG image whose CD-Text chunk size or DAOX track numbers are damaged. The
reader never reads or writes outside the bytes it allocated or the tracks it has; a chunk it cannot
use gives no labels, a DAOX entry for a track that does not exist changes nothing.

**Why this priority**: part of the item's *Expected*; the same file, the same open.

**Independent Test**: `saltests` checks of the pure rules: the chunk fits the image; the compacted
CD-Text text length and content never exceed the chunk (every size 0..200 and sizes near 4 GiB);
the n-th label of a text without a final terminator; the DAOX track number range.

**Acceptance Scenarios**:

1. **Given** a CD-Text chunk of any size from 0 to the bytes left in the image, **When** the labels are
   taken, **Then** no byte outside the chunk is read and no byte outside the buffer is written.
2. **Given** a CD-Text chunk claiming more bytes than the image holds after it, **When** the image is
   opened, **Then** no labels are taken from it and no buffer of a wrapped size is allocated.
3. **Given** a DAOX chunk naming track 0 or a track above the CUEX track count, **When** the image is
   opened, **Then** no track outside the table is touched.

### Edge Cases

- A label exactly as long as the listing takes (the name 255 bytes): listed (unchanged).
- A CD-Text text that does not end with a terminator: the last label ends at the end of the text.
- Fewer labels than tracks: the remaining tracks have no label (`Audio Track NN`), as before.
- A CD-Text chunk of size 0..4 (no text block): no labels.
- Track numbers 100 and above: the name is `100 <label>` (the `%02d` rule), its length computed, not
  assumed.
- Out of memory while building a name: the listing is marked incomplete, as feature 329 does.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The listed name of an audio track MUST be built in a buffer sized from the label's
  length, holding the whole name (never cut), and handed to the existing listing rule (left out and
  reported when refused).
- **FR-002**: The CD-Text reader MUST take labels only from a chunk that fits in the image after its
  header; its buffer size MUST be computed without wrap-around; a failed allocation or short read
  MUST leave the tracks without labels.
- **FR-003**: The CD-Text text MUST be gathered from the 12-byte blocks only within the chunk's bytes,
  and each label MUST be taken only from that text (a label without a terminator ends at the text's
  end).
- **FR-004**: The DAOX reader MUST apply an entry only to a track the table holds (numbers 1 to the
  track count) and MUST stop at a short read.
- **FR-005**: `CISOImage::GetTrack` MUST return no track for an index equal to or above the track count.
- **FR-006**: Images whose chunks are consistent MUST list exactly as before (names, labels, tracks).
- **FR-007**: The pure decisions (chunk fits, text gathering, n-th label, track range, name length)
  MUST live in a header under `src/common/` with `saltests` checks.

### Key Entities

- **CD-Text chunk**: 4 flag bytes, then blocks of 12 text bytes and 6 other bytes; the text is the
  volume label and one label per track, each 0-terminated.
- **DAOX entry**: per-track sector size, mode and extent for track numbers first..last.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For every label length from 0 to 4096 bytes, the track name built holds the whole label
  (checked in `saltests`); no fixed-size buffer is left on the name path.
- **SC-002**: For every CD-Text chunk size from 0 to 200 bytes and for sizes within 64 bytes of 4 GiB,
  the gathered text length never exceeds the chunk size (checked).
- **SC-003**: DAOX track numbers 0 and count + 1 are refused, 1..count accepted (checked); `GetTrack`
  returns no track at index count.
- **SC-004**: Feature 329's NRG probe row (A-OPEN, the 253-byte label) still passes.

## Assumptions

- Assumption (autonomous run): no new UI string - a refused name uses feature 329's "(206)" report; a
  chunk the reader cannot use is skipped silently, like any other damaged NRG chunk today.
- Assumption (autonomous run): the crash at HEAD is shown by reading the sites (the item's own note:
  no run reproduced it); the run does not build images that drive the overrun at the old code. The
  after-fix evidence is the `saltests` checks of the rules plus feature 329's probe (a fitting label).
- Assumption (autonomous run): the label bytes are passed to the listing as they are (their encoding
  is outside this item).
