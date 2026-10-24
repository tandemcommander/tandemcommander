# Feature Specification: A disc image with a track the ISO plug-in cannot open is kept by Unpack with "Delete archive after unpacking"

**Feature Branch**: `334-uniso-session-missing`  
**Created**: 2026-10-24  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-unpack-with-delete-archive-deletes-a-multi` - "ISO plug-in: Unpack with Delete archive deletes a multi-session image whose session track cannot be opened". From backlog item iso-plug-in-unpack-with-delete-archive-deletes-a-multi.

## Background (traced and measured at 21c3ce91)

The ISO plug-in (`uniso`, on in the default build) reads disc images that carry a track table (NRG,
CCD/IMG, ...). By default ("Session NN" folders) it lists a multi-session image with one folder per
session. When a session's track does not open, it shows its box "Some error(s) occured while reading
multisession image. Showing only correctly read sessions." and lists the other sessions - but the
listing is not marked incomplete (feature 328's mark that makes a whole-image unpack fail). In a
single-session listing the plug-in lists the last data track it recognises; when that track does not
open it falls back to listing the other tracks, again without a mark.

Measured on the Debug build at 21c3ce91 on the hidden desktop (probe `iso334_probe.ps1`). Two ISO 9660
sessions made by genisoimage (session 1: `a.txt`; session 2: `b.txt`, addressed after session 1), put
into NRG images by a Python writer. Unpack (Alt+F9) of the whole image with "Delete archive after
unpacking":

- two intact sessions: `Session 01/a.txt` and `Session 02/b.txt` extracted, the image deleted (correct);
- session 2's volume descriptor set terminator destroyed (its descriptors still say ISO 9660, the ISO
  9660 reader does not open it): the box shows, `Session 01/a.txt` extracted, **the image deleted -
  `b.txt` lost**;
- session 2's track starting past the end of the image: no box at all - the track is taken as a raw
  data track that lists nothing - `Session 01/a.txt` extracted, **the image deleted**;
- one session of the two tracks, intact: `b.txt` (the last track) extracted, the image deleted
  (correct - the plug-in lists only the last data track of a single-session listing);
- one session, the last data track's terminator destroyed: no box, the fallback lists track 1,
  `a.txt` extracted, **the image deleted - `b.txt` lost**.

## Clarifications

### Session 2026-10-24

- Q: Which tracks count as "a track that could not be opened"? → A: every track of a session the
  multi-session listing tries (data and audio) whose reader does not open, or whose listing fails; in
  the single-session listing the last data track when it does not open, and every other track the
  fallback then tries that does not open (autonomous run: item - *Expected* "a listing that left out a
  track or session that could not be opened is marked incomplete")
- Q: Do audio tracks that do not open count (the item's *Notes* leave it to the spec)? → A: yes, they
  mark the listing like any other track - a "safe to delete?" check fails closed. In practice an audio
  track always opens (its reader has no open step), so audio CDs and mixed-mode discs behave as today
  (autonomous run: rule - CLAUDE.md "a safe to delete? check fails closed")
- Q: A data track that lies past the end of the image (nothing of it can be read - the plug-in takes it
  as a raw data track that lists nothing)? → A: it is a track that could not be opened: marked, in the
  multi-session and the single-session listing. A raw data track that can be read (no file system the
  plug-in knows, e.g. the MPEG tracks of a Video CD) stays as today - not listed, not marked
  (autonomous run: item - its *Notes* name this image as the probe; conservative for readable raw
  tracks)
- Q: Tracks of a type the track table does not name ("unknown" tracks, skipped by every listing
  today)? → A: unchanged - never listed, not marked (autonomous run: conservative - the item does not
  name them)
- Q: A message? → A: no new message or UI string; the multi-session box stays exactly as it is, a
  silent case stays silent (as feature 330's silent cases) (autonomous run: item - "The error box and
  the listing of the other sessions stay as they are")
- Q: The APFS parts of a hybrid (open decision item `iso-plug-in-apfs-original-hfs-and-hfsx-parts-of-a-hybrid-are`)?
  → A: untouched - that decision concerns a part inside a track that opens. A whole track the
  multi-session listing cannot open (whatever its type) already shows the box and is marked by this
  feature (autonomous run: rule - recorded decisions are the maintainer's)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A multi-session image with a session that cannot be opened is kept (Priority: P1)

A user unpacks a whole multi-session disc image with "Delete archive after unpacking". One session's
track cannot be opened. The other sessions are extracted, the box tells that some sessions were not
read, and the image stays on disk, so the files of the unread session are not lost.

**Why this priority**: it is the item's main point - the image is deleted today and the files of the
unread session are gone.

**Independent Test**: probe rows M-TERM and M-PAST: the image of two sessions whose second session does
not open (terminator destroyed) or lies past the end of the image; Unpack with "Delete archive after
unpacking".

**Acceptance Scenarios**:

1. **Given** a two-session image whose second session's track does not open, **When** the user unpacks
   the whole image with "Delete archive after unpacking", **Then** the first session's files are
   extracted, the multi-session box shows as before, and the image is kept.
2. **Given** a two-session image whose second session's track lies past the end of the image,
   **When** the same unpack runs, **Then** the first session's files are extracted, no new message
   shows, and the image is kept.
3. **Given** a two-session image whose sessions both open, **When** the same unpack runs, **Then**
   both sessions' files are extracted and the image is deleted (as today).

---

### User Story 2 - A single-session image whose last data track does not open is kept (Priority: P2)

A user unpacks a whole disc image of one session whose last data track does not open; the plug-in
lists the other tracks instead. The listed files are extracted and the image stays on disk.

**Why this priority**: the same loss on the second listing path the item names.

**Independent Test**: probe row S-TERM (one session of two tracks, the last track's terminator
destroyed).

**Acceptance Scenarios**:

1. **Given** a one-session image whose last data track does not open and whose first track lists,
   **When** the user unpacks the whole image with "Delete archive after unpacking", **Then** the first
   track's files are extracted, no new message shows, and the image is kept.
2. **Given** a one-session image of two intact tracks, **When** the same unpack runs, **Then** the last
   track's files are extracted and the image is deleted (as today).

### Edge Cases

- An audio CD or a mixed-mode disc whose tracks all open: unchanged (unpacks whole, deleted as today).
- A Video CD-like image whose later tracks are readable raw data: unchanged (not listed, not marked).
- An "unknown" track type in the track table: unchanged.
- An image without a track table (a plain .iso): unchanged - one track, the existing reader marks.
- No track at all opens: the image does not open, as today.
- Copying single files out of the listed sessions still works; only a whole-image unpack fails.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: In the multi-session listing, a track the listing tries (any type except "unknown")
  that does not open, whose listing fails, or that lies past the end of the image MUST mark the
  listing incomplete, so a whole-image unpack fails and "Delete archive after unpacking" keeps the image.
- **FR-002**: In the single-session listing, when the last data track does not open and the listing
  falls back to the other tracks, the listing MUST be marked incomplete when it is returned; a track the
  fallback tries that does not open (except "unknown") MUST mark it too.
- **FR-003**: In the single-session listing, a data track that lies past the end of the image MUST mark
  the listing incomplete.
- **FR-004**: The multi-session box, the folders listed and every message MUST stay as they are; no UI
  string is added or changed.
- **FR-005**: Images whose tracks all open (and readable raw data tracks, audio tracks, "unknown"
  tracks) MUST unpack whole and be deleted with "Delete archive after unpacking" as before.
- **FR-006**: The decision which track outcome marks the listing MUST be a pure rule in a header under
  `src/common/` with `saltests` checks (stop-rules §2.5).

### Key Entities

- **Track**: an entry of the image's track table - its type (data / audio / unknown), whether its data
  lies within the image, whether its reader opened it and whether its listing succeeded.
- **Listing mark**: feature 328's "incomplete" flag of the listing; a whole-image unpack of a marked
  listing fails.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe rows M-TERM, M-PAST and S-TERM: image kept (3 FAIL before the change, PASS after).
- **SC-002**: Control rows M-OK and S-OK: image deleted, all listed files extracted (PASS before and after).
- **SC-003**: The earlier ISO probes (322, 329, 330, 333) keep their results.
- **SC-004**: `saltests` gains checks of the rule and keeps 0 failures; a mutant of the rule fails them.

## Assumptions

- Assumption (autonomous run): "lies past the end of the image" means that the track's first volume
  descriptor sector (sector 16, where every file system the plug-in reads starts looking) cannot be
  read from the image file - the plug-in's own detection reads nothing there.
- Assumption (autonomous run): the readers' own `ListDirectory` failures already mark the listing
  (features 328-333); treating a failed listing of a track as a mark again is harmless.
- Assumption (autonomous run): the single-session listing keeps listing only the last data track when
  it opens (earlier tracks of one session are not listed, by design - the last track's directory of a
  multi-session disc includes the earlier ones); only an unreadable data track adds a mark there.
