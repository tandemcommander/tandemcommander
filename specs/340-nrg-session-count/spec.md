# Feature Specification: An NRG image whose session counts do not fit its tracks is listed within its tracks and kept

**Feature Branch**: `340-nrg-session-count`  
**Created**: 2026-10-24  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-an-nrg-session-count-above-the-image-s-tracks` - "ISO plug-in: an NRG session count above the image's tracks lists past the track table". From backlog item iso-plug-in-an-nrg-session-count-above-the-image-s-tracks.

## Background (traced and measured at 2b3f0716)

The ISO plug-in (`uniso`, on in the default build) opens NRG (Nero) disc images. With its default
option "session as directory" it lists an image of two or more sessions with one folder per session
("Session 01", "Session 02", ...). The NRG image says how many tracks each session holds (one SINF
chunk a session, a 32-bit count) and, separately, which tracks the image holds (its track table). The
plug-in never compares the two: the listing takes the next *count* tracks for each session, so a count
above the tracks that are left reads past the end of the track table; a count of 2^31 or more is taken
as a negative number, after which the next session starts before the first track.

Measured on the Debug build at 2b3f0716 on the hidden desktop (scratch probe `iso340_probe.ps1`, seeds by
feature 334's `mkimg334.sh`: two ISO 9660 tracks, `a.txt` and `b.txt`; `img340.py` writes NRG images of
these two tracks with chosen session counts). Unpack (Alt+F9) of the whole image with "Delete archive
after unpacking":

- counts 1, 1 and 0, 2 (controls - the counts add up to the tracks): both files extracted, the image
  deleted (correct);
- counts 1, 2 / 1, 1000 / 1, 1, 1 (a session counts tracks the image does not hold): **the program stops
  with "Index is out of range (index = 2, Count = 2)"** (a Release build reads through whatever lies
  past the table);
- counts 0xFFFFFFFF, 2: **"Index is out of range (index = -1, Count = 2)"**;
- counts 1, 0xFFFFFFFF: no stop, but **session 2's `b.txt` is never listed or extracted** (the image is
  kept only by feature 334's mark for a track no session covers).

## Clarifications

### Session 2026-10-24

- Q: How is a session count of 2^31 or more read? → A: as the unsigned 32-bit number the image stores -
  a count far above the tracks the image holds, refused like any other count that does not fit; never
  a negative number (autonomous run: item - *Expected* "a session count that does not fit the track
  table is refused")
- Q: Which tracks does a session whose count does not fit get? → A: the tracks that are left from where
  the previous session ended, up to the end of the track table: they are listed in that session's
  folder as today; only the tracks the image does not hold are missing (autonomous run: item -
  *Expected* "the session's missing tracks are not listed")
- Q: What does the user see when a count does not fit? → A: the listing is marked incomplete (as
  features 328 / 330 / 334 do: a whole unpack fails, the image is kept, also with "Delete archive after
  unpacking"); no new box, no new text (autonomous run: item - *Expected*; conservative - no UI string)
- Q: A session after one whose count used up the track table? → A: it starts at the end of the table;
  a count of zero fits (nothing listed, nothing marked), any other count does not fit (autonomous run:
  item)
- Q: The image viewer's information dump (F3 on an image) also reads the session counts - in scope? →
  A: no: it walks the track table, never past it, and a count above the tracks only prints that
  number; its own overrun (a session table read past its end when the counts add up to *fewer*
  tracks than the image holds) is another defect, recorded as an Inbox item (autonomous run: rule -
  scope of stop-rules §2.11)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Opening and unpacking an NRG image whose session counts are damaged (Priority: P1)

A user opens or unpacks an NRG image whose session table names more tracks than the image holds (a
damaged or hand-made image). The plug-in lists the tracks that exist, each in its session's folder,
does not stop or read memory it does not own, and marks the listing incomplete, so a whole Unpack with
"Delete archive after unpacking" keeps the image.

**Why this priority**: today the program stops (Debug) or reads past an array (Release) - a crash on
opening a file from the panel, and, with a negative count, a session's files silently left out.

**Independent Test**: the probe's rows S-OVER, S-OVER1000, S-EXTRA, S-NEG, S-NEGEND on the hidden desktop:
Unpack of the whole image with "Delete archive after unpacking".

**Acceptance Scenarios**:

1. **Given** an NRG image of two tracks with session counts 1, 2, **When** the user unpacks it whole with
   "Delete archive after unpacking", **Then** `Session 01/a.txt` and `Session 02/b.txt` are extracted, no
   window shows, the program keeps running and the image is kept.
2. **Given** counts 1, 1000 or 1, 1, 1, **Then** the same as scenario 1.
3. **Given** counts 0xFFFFFFFF, 2, **Then** `Session 01/a.txt` and `Session 01/b.txt` are extracted (the
   first session holds every track the image has), no window, the image kept.
4. **Given** counts 1, 0xFFFFFFFF, **Then** `Session 01/a.txt` and `Session 02/b.txt` are extracted, no
   window, the image kept.

---

### User Story 2 - Images whose counts fit keep their behaviour (Priority: P2)

An NRG image whose session counts add up to its tracks (also with a session of zero tracks) is listed
and unpacked as before; a whole Unpack with "Delete archive after unpacking" deletes it.

**Why this priority**: no regression for valid images.

**Independent Test**: rows F-FIT (1, 1) and F-ZERO (0, 2) of the probe; features 334 / 335 probes.

**Acceptance Scenarios**:

1. **Given** counts 1, 1, **Then** `Session 01/a.txt`, `Session 02/b.txt` extracted, the image deleted.
2. **Given** counts 0, 2, **Then** `Session 02/a.txt`, `Session 02/b.txt` extracted, the image deleted.

### Edge Cases

- A count far above the tracks (1000, 2^32 - 1): treated as "does not fit", never summed in a way that
  wraps around.
- More sessions than tracks: every session after the table's end with a count above zero does not fit.
- Tracks no session count covers (the counts add up to fewer tracks): left out and marked as feature 334
  does - unchanged.
- The single-session listing ("session as directory" off, or one session): does not use the counts -
  unchanged.
- CCD/IMG images: their session counts are derived from their own track list, so they always fit; the
  same rule applies to them without change in behaviour.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The session listing MUST never look at a track outside the image's track table (no index
  at or past its end, none below zero), whatever the session counts say.
- **FR-002**: A session count MUST be read as the unsigned 32-bit number the image stores.
- **FR-003**: Each session MUST be given the tracks from where the previous session ended, as many as its
  count but no more than the tracks left; those tracks are listed in its folder as today.
- **FR-004**: When a session's count is above the tracks left, the listing MUST be marked incomplete (a
  whole unpack fails and the image is kept, as for a track that does not open); no new message.
- **FR-005**: Images whose counts fit (also zero-track sessions) MUST be listed, marked and unpacked
  exactly as before.
- **FR-006**: The rule that decides a session's tracks MUST be a pure rule with unit checks (a header
  under `src/common/`, saltests).

### Key Entities

- **Session count**: the number of tracks a session claims (one SINF chunk of the NRG image, an unsigned
  32-bit number).
- **Track table**: the tracks the image holds (from its CUEX / ETNF chunks).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe's five damaged-count rows (S-OVER, S-OVER1000, S-EXTRA, S-NEG, S-NEGEND) pass
  where four stopped the program and one lost a file before (FAIL 9 -> 0); the two controls stay PASS.
- **SC-002**: Feature 334's and 335's probes (all their images' counts fit) give the results the features
  after them recorded: 334 23 / 1 (S-RAW, changed by 335), 335 28 / 4 (four Form 2 stream rows changed by
  336) - no row changed by this feature.
- **SC-003**: The new pure rule's checks pass in saltests, and a mutant that drops the bound fails them.

## Assumptions

- Assumption (autonomous run): the fix goes where the counts are used (the session listing), not where
  they are read: the NRG chunks may name a session's count before or after its tracks, so only the
  listing knows the whole track table.
- Assumption (autonomous run): Release builds are not driven; the Debug range check stops exactly where
  a Release build would read past the table, so a Debug run without that stop proves the bound.
- No real Nero image with damaged session counts exists to try; the images are hand-made by `img340.py`.
