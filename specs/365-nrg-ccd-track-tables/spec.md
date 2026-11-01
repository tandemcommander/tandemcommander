# Feature Specification: The ISO plug-in reads NRG ETNF / ETN2 and CloneCD track tables with the right sector sizes, sessions and ends

**Feature Branch**: `365-nrg-ccd-track-tables`  
**Created**: 2026-11-01  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables` - "ISO plug-in: NRG ETNF / ETN2 and multi-session CCD track tables get wrong sector sizes or ends". From backlog item iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables.

## Background (measured at 41f18c08)

The ISO plug-in (`uniso`, on in the default build) opens a disc image with a track table - a Nero image
(`.nrg`, its chunks at the end of the file) or a CloneCD image (`.img` + `.ccd`) - by building one track
record per track: where its sectors start and end in the file, how large a sector is stored, how many
bytes precede the user data in a sector, and which disc sector (extent) the track starts at. The file
systems of every session are read through these records; a whole Unpack with "Delete archive after
unpacking" deletes the image once everything listed was extracted, and keeps it when the listing is
marked incomplete (features 328 / 334 / 335).

- **NRG ETNF** (track-at-once table, 20 bytes a track): the stored sector size comes from bit 0 of the
  mode byte (2336 bytes if set, else 2048). Mode 0x05 (raw Mode 1, 2352 bytes a sector) is read as 2336,
  mode 0x06 (raw Mode 2, 2352) as 2048.
- **NRG ETN2** (the 64-bit form, 32 bytes a track): only the first entry of a chunk is read, its end is set
  to the entry's length (not start + length), its mode is always taken as Mode 1 / 2048 and its first disc
  sector as 0 - whatever the entry says.
- **CloneCD**: the tracks are split into sessions where a track's `INDEX 1` is 0. A table whose `INDEX 1`
  values are counted from the start of the disc (each equal to the track's position in the table of
  contents, its PLBA) is one split for two sessions; the last track's sector count is computed as an
  unsigned difference and wraps when that track starts after the session's lead-out.

Measured with the hidden-desktop probe `iso365_probe` (seeds by `mkimg365.sh` - genisoimage: s1.iso a.txt
"A1", s2.iso b.txt "B2" addressed from session 1's sectors + 11400, the lead-out / lead-in / pregap no
image file holds; images by `img365.py`; a whole Unpack, Alt+F9, with "Delete archive after unpacking") on
the Debug build of 41f18c08: **12 PASS / 6 FAIL**.

| Row | Image | Result at 41f18c08 |
|---|---|---|
| C-ETNF00 | ETNF, two sessions, Mode 1 / 2048 | both sessions extracted, image deleted (control) |
| R-ETNF05 / R-ETNF06 | ETNF, track 2 raw Mode 1 (0x05) / raw Mode 2 (0x06) | session 2 lost, image kept (335's mark) |
| C-ETN2ONE | ETN2, one session from offset 0 | a.txt extracted, image deleted (control) |
| R-ETN200 / R-ETN203 / R-ETN206 | ETN2, a chunk a session, track 2 mode 0x00 / 0x03 / 0x06 | session 2 lost, **Session 01/a.txt written with the wrong content** (both tracks start at extent 0, so a.txt is read from track 2), image kept; R-ETN200 also shows "Error reading directory structure" |
| C-CCDREL | CloneCD, two sessions, `INDEX 1` counted from the start of each session (0, 0) | both sessions extracted, image deleted (control) |
| R-CCDABS | CloneCD, two sessions, track 2's `INDEX 1` = its PLBA | only a.txt (no session folders), image kept (352's mark) |

**Format facts** (libmirage's NRG and CloneCD parsers, the psx-spx CloneCD reference, DiscImageCreator
issue 121): an ETNF entry holds start u32 @0, length u32 @4, mode @11, first sector u32 @12; an ETN2 entry
start u64 @0, length u64 @8, mode @19, first sector u32 @20 (all big-endian). Nero's mode bytes: 0x00 Mode
1 / 2048, 0x02 Mode 2 Form 1 / 2048, 0x03 Mode 2 / 2336, 0x05 Mode 1 / 2352, 0x06 Mode 2 / 2352, 0x07 audio /
2352, 0x0F Mode 1 + subchannel, 0x10 audio + subchannel, 0x11 Mode 2 + subchannel (the item's note had 0x10
/ 0x11 swapped). CloneCD: the table-of-contents entries' PLBA count from the start of the disc, the
`[TRACK n]` `INDEX` values from the start of their session; the 11400 sectors between sessions are not in
the `.img` (sessions follow each other); libmirage lays the tracks out back to back from the PLBA values
with a stored pregap of INDEX 1 - INDEX 0 subtracted (`track_start = PLBA - pregap`, also for a
session's first track; the session's last track ends at the session's lead-out, entry 0xA2). (Corrected
after review 1, which read libmirage's code: an earlier wording said "from the PLBA values alone".)

**Finding against the item's premise**: CloneCD itself writes `INDEX 1` counted from the session (the
form C-CCDREL uses), which 41f18c08 already reads correctly; a table with `INDEX 1` counted from the disc
start (the item's "real multi-session image") is what R-CCDABS reads wrongly. The layout of this feature
(PLBA only, INDEX not read) reads both forms the same way. libmirage would read the second form
differently (a session-2 `INDEX 1` of 11576 as an 11576-sector pregap), and it reads a stored pregap
before a later session's first track (`INDEX 0=0`, `INDEX 1=150`) which this feature does not - such an
image keeps its listing marked as on 41f18c08 (review 1 measured: session 2 not listed, image kept; a
limit, Clarification 1).

## Clarifications

### Session 2026-11-01

- Q: Should the CloneCD layout add a stored pregap before a session's first track (libmirage's INDEX 0 / INDEX 1 difference)? → A: No - the reader does not read INDEX 0 today, CloneCD omits the pregap of a later session's first track (DiscImageCreator issue 121), and 41f18c08's geometry is kept for every case it reads; a stored pregap stays a limit (autonomous run: conservative)
- Q: Now that every ETN2 entry becomes a track, may a damaged ETN2 chunk make thousands of tracks? → A: No - an ETN2 chunk is read only when it lies within the image and holds at most 99 whole entries (a disc's track limit); otherwise it is skipped like an unknown chunk, no track. 41f18c08 made one track per chunk; no new unbounded track count is added (features 331 / 350's practice) (autonomous run: conservative)
- Q: Is the table-of-contents layout also used for a one-session CloneCD image? → A: Yes, whenever the table can be followed - for a consistent table it gives the same track records as 41f18c08 (FR-008), so one rule serves every image (autonomous run: recommended)
- Q: How is a `[TRACK n]` section matched to its table-of-contents entry when the reader keeps no track number? → A: The k-th `[TRACK n]` section is the track numbered (the smallest ADR-1 track point 1..99) + k; the points must then run without a hole, else the table cannot be followed (FR-005) (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A Nero image with raw or Mode 2 tracks lists and unpacks every session (Priority: P1)

A user opens a Nero image whose track table is ETNF or ETN2 - a track-at-once burn, possibly
multi-session, possibly with raw (2352-byte) or Mode 2 sectors - and sees and unpacks every session's
files with their right content.

**Why this priority**: today such an image loses a session, and an ETN2 image writes a file of session
1 with session 2's bytes - silent wrong data.

**Independent Test**: probe rows R-ETNF05, R-ETNF06, R-ETN200, R-ETN203, R-ETN206 and controls C-ETNF00,
C-ETN2ONE.

**Acceptance Scenarios**:

1. **Given** an NRG image whose ETNF entry for track 2 has mode 0x05 or 0x06 and holds a file system in
   2352-byte sectors, **When** the user unpacks it whole with "Delete archive after unpacking", **Then**
   `Session 01/a.txt` and `Session 02/b.txt` are extracted with their content, no window shows, and the
   image is deleted.
2. **Given** an NRG image with an ETN2 chunk per session (track 2 starting after track 1's bytes, at disc
   sector 11576, of mode 0x00, 0x03 or 0x06), **When** the user unpacks it whole, **Then** both files are
   extracted with their content, no window shows, and the image is deleted.
3. **Given** a one-session ETN2 image or a two-session ETNF image of Mode 1 / 2048 tracks, **When** it is
   unpacked, **Then** the result is as before (controls).

### User Story 2 - A CloneCD image is split into its sessions by its table of contents (Priority: P2)

A user opens a CloneCD image of two sessions whose `[TRACK n]` `INDEX 1` values count from the start of
the disc; both sessions are listed and unpacked, and the image is deleted only after both were extracted.
An image in CloneCD's own form (INDEX counted from the session) keeps working.

**Why this priority**: today the second session's files are not extracted (the image is kept since 352,
so nothing is lost - but nothing of session 2 is listed either).

**Independent Test**: probe rows R-CCDABS and C-CCDREL; feature 352's probe rows R-ABS (now both
sessions, image deleted) and R-TWOSEC (still kept).

**Acceptance Scenarios**:

1. **Given** a CloneCD image of two sessions whose track 2 has `INDEX 1` = its PLBA, **When** it is unpacked
   whole with "Delete archive after unpacking", **Then** `Session 01/a.txt` and `Session 02/b.txt` are
   extracted, no window shows, and the image is deleted.
2. **Given** the same image with `INDEX 1` = 0 for both tracks, **When** it is unpacked, **Then** the result
   is as before (both extracted, image deleted).
3. **Given** a `.ccd` with two `[Session n]` sections but tracks in one session only (352's R-TWOSEC),
   **When** it is unpacked, **Then** the image is still kept.

### User Story 3 - An inconsistent table never wraps a track's end (Priority: P3)

A damaged or crafted CloneCD table whose track positions go backwards, or whose lead-out comes before a
track, no longer gives a track a sector count that wraps to billions; such a track is empty and the
listing is marked incomplete, so a whole unpack keeps the image.

**Why this priority**: since 334 / 335 such a table already fails closed through other marks in the
cases measured; this closes the arithmetic itself.

**Independent Test**: `saltests` checks of the layout rule (a decreasing PLBA, a lead-out before the
last track, the same in the INDEX-1 split).

**Acceptance Scenarios**:

1. **Given** a table where a track's end position comes before its start, **When** the layout is
   computed, **Then** that track gets 0 sectors and the result says the table is inconsistent (the
   listing is marked incomplete).

### Edge Cases

- An ETNF / ETN2 mode byte outside the verified table (0x01, 0x04, 0x08.., 0x0F, 0x10, 0x11, ...): the
  sector size stays what 41f18c08 gives it (ETNF: the bit-0 rule; ETN2: Mode 1 / 2048), the mode and
  type as `SetTrackTypeMode` gives them (unknown modes are not opened and mark the listing, 334).
- An ETN2 chunk holding several entries (several tracks of one session): every entry becomes a track, in
  order, as ETNF does.
- An ETN2 chunk whose size is not a multiple of 32: the whole entries are read, the rest ignored (as
  ETNF with 20); a chunk under 32 bytes gives no track (41f18c08 read 16 bytes past such a buffer -
  part of Inbox item `iso-plug-in-nrg-sinf-and-etn2-chunks-are-read-without-regard`, whose SINF half
  stays open).
- An ETN2 chunk that does not lie within the image, or holds more than 99 entries: skipped like an
  unknown chunk, no track (the next chunk header is read right after it).
- A CloneCD table in which a track has no ADR-1 entry with its number, the track points outnumber the
  `[TRACK n]` sections, two entries for one track
  disagree, a later track belongs to an earlier session, or a session holding tracks has no lead-out
  entry: the table of contents cannot be followed - the `INDEX 1` split of 41f18c08 is used, with 352's
  mark when sections and splits disagree.
- A CloneCD session section without any track (352's R-TWOSEC): the sessions holding tracks and the
  `[Session n]` sections disagree - the listing stays marked (352).
- A CloneCD layout guessed wrongly for some other producer (sessions with their gap kept in the `.img`):
  session 2's data track shows no file system and is marked by 335, an audio track by 334 - the image is
  kept (fails closed).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The stored sector size of an NRG ETNF or ETN2 track MUST follow Nero's mode byte for the
  verified modes: 0x00 and 0x02 -> 2048 bytes, 0x03 -> 2336, 0x05, 0x06 and 0x07 -> 2352. For any other
  mode byte the size MUST stay as 41f18c08 gives it (ETNF: 2336 when bit 0 is set, else 2048; ETN2: 2048).
- **FR-002**: The bytes before the user data in a sector MUST follow the track's mode and stored sector
  size by the plug-in's existing rule (Mode 1 / 2352 -> 16, Mode 2 / 2352 -> 24, Mode 2 / 2336 -> 8,
  2048 -> 0).
- **FR-003**: Every whole 32-byte entry of an ETN2 chunk MUST become a track, in order: its start = the
  entry's start, its end = start + length, its mode and type from the mode byte (as ETNF, through
  `SetTrackTypeMode`; a mode outside the verified table keeps 41f18c08's Mode 1 / ISO 9660), its first
  disc sector (extent offset) = the entry's first-sector field. A chunk outside the image or of more
  than 99 entries MUST give no track and the reader MUST continue right after it.
- **FR-004**: A CloneCD track (the k-th `[TRACK n]` section = track number first + k, first = the
  smallest ADR-1 track point 1..99) MUST belong to the session that the table-of-contents entry with
  ADR 1 and its track number names; its extent offset MUST be that entry's PLBA; within a session a track MUST
  end where the next track of that session starts (by PLBA) and the session's last track at the
  session's lead-out (entry 0xA2, ADR 1); the sessions MUST follow each other in the `.img` without a
  gap (each starts where the previous one ended).
- **FR-005**: When the table of contents cannot be followed (see Edge Cases), the reader MUST keep
  41f18c08's `INDEX 1` split, unchanged, including 352's mark.
- **FR-006**: A track whose computed sector count would be negative (in either path) MUST get 0 sectors,
  and the listing MUST then be marked incomplete.
- **FR-007**: 352's layout mark MUST still apply when the number of `[Session n]` sections differs from
  the number of sessions holding tracks.
- **FR-008**: For a CloneCD table that 41f18c08 already split correctly (`INDEX 1` counted from the
  session, consistent with the PLBA values) the track records MUST be the same as before.
- **FR-009**: No UI string, dialog, message or configuration changes.
- **FR-010**: The pure rules (the NRG mode table, the ETN entry decoding, the CloneCD layout) MUST live
  in a header under `src/common/` with `saltests` checks (rule §2.5).

### Key Entities

- **Track record**: start and end byte in the image, stored sector size, header bytes before the user
  data, mode, file-system type, extent offset (first disc sector).
- **ETN entry**: start, length, mode byte, first sector - 20 bytes (ETNF, 32-bit) or 32 bytes (ETN2, 64-bit).
- **CloneCD table of contents**: `[Entry n]` rows - session, point (track number, 0xA0 / 0xA1 / 0xA2,
  0xB0 / 0xC0), ADR, PLBA.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `iso365_probe` on the fixed build: 18 PASS / 0 FAIL (the six R rows that failed at 41f18c08
  pass, the three controls still pass).
- **SC-002**: No ETN2 image of the probe writes a file with another file's content.
- **SC-003**: Feature 352's probe: every row as recorded except R-ABS, which now extracts both sessions and
  deletes the image (the item's note); R-TWOSEC still keeps the image. Features 334, 335 and 351 probes as
  recorded.
- **SC-004**: `saltests` passes with new checks of the mode table, ETN decoding and CloneCD layout; a
  mutant of each rule fails at least one check.

## Assumptions

- Assumption (autonomous run): Nero modes 0x0F / 0x10 / 0x11 (with subchannel) and unknown modes keep
  41f18c08's sector size - libmirage's track-at-once loader does not show how their subchannel bytes are
  stored, the item marks them "not verified"; a later item may add them.
- Assumption (autonomous run): an ETN2 entry's first-sector field is the track's first disc sector, as
  the ETNF reader already takes it (same field in libmirage's shared ETN structure).
- Assumption (autonomous run): the reader of NRG v1 images (footer "NERO", where ETNF belongs) is not
  part of this item - the plug-in reads only "NER5" footers, so ETNF is reached through an NER5 image
  that holds an ETNF chunk (as features 334 / 335 build their images); recorded, not changed.
- Assumption (autonomous run): crafted images only; no real Nero or CloneCD dump is available to the run
  (a person step at closing).
