# Feature Specification: The image information of an NRG image stays within its session table

**Feature Branch**: `370-nrg-info-sessions`
**Created**: 2026-11-01
**Status**: Draft
**Input**: User description: "Backlog item iso-plug-in-the-image-information-of-an-nrg-image-reads-past - implement exactly what it describes." From backlog item iso-plug-in-the-image-information-of-an-nrg-image-reads-past.

## Context

The ISO plug-in shows information about a disc image when the user views the image (F3 / View on the
image file): the label, the number of sessions, then each session with its number of tracks and each
track with its type, size and file system details. An NRG (Nero) image stores the number of tracks of
each session separately from its track table (one SINF chunk a session, an unsigned 32-bit count). The
information walked the track table and started the next session whenever the track index reached the
running sum of the counts, without checking that a next session exists and reading each count as a
signed number.

Measured at 2c1c1279 (probe `probe/iso370_probe.ps1`, Debug build, F3 on NRG images of two tracks and
on feature 334's `multi_extra` image of three tracks; `probe/result_before.txt`, PASS 6 / FAIL 10):

| Image (SINF counts / tracks) | Before |
|---|---|
| 1, 1 / 2 (control) | correct |
| 1 / 2 | Debug range check "Index is out of range (index = 1, Count = 1)" - the program must be ended |
| no SINF / 2 | Debug range check (index = 0, Count = 0) |
| 1, 1 / 3 (multi_extra) | Debug range check (index = 2, Count = 2) |
| 0xFFFFFFFF, 2 / 2 | session 1 "Number of tracks: -1", both tracks under it, session 2 never shown |
| 1, 0xFFFFFFFF / 2 | session 2 "Number of tracks: -1" |
| 0, 2 / 2 | both tracks under session 1 (which counts 0), session 2 never shown |
| 1, 2 / 2 | session 2 "Number of tracks: 2" though one track is left |

In the Release build the read past the session table yields an arbitrary number shown as a track count
and added to the running sum.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Viewing an image whose session counts do not cover its tracks (Priority: P1)

A user presses F3 on an NRG image whose session counts add up to fewer tracks than the image holds (or
that has no session count at all). The information opens and shows each session the image declares
with the tracks that belong to it, then the remaining tracks under a line saying that no session covers
them. The program keeps running.

**Why this priority**: today this stops the Debug program and shows garbage in the Release build - the
defect the item is about.

**Independent Test**: probe rows S-SHORT, S-NONE, S-EXTRA3: the dump skeleton is the expected one, no
fatal window, the program ends cleanly.

**Acceptance Scenarios**:

1. **Given** an NRG image of two tracks with one SINF count 1, **When** the user views it, **Then** the
   information shows "Number of sessions: 1", session 1 with 1 track (track 1), then the line "Tracks not
   in any session" and track 2.
2. **Given** an NRG image of two tracks with no SINF chunk, **When** the user views it, **Then** it shows
   "Number of sessions: 0", the line "Tracks not in any session" and tracks 1 and 2.
3. **Given** feature 334's `multi_extra` image (counts 1, 1, three tracks), **When** the user views it,
   **Then** it shows sessions 1 and 2 with one track each, the line, and track 3.

### User Story 2 - Session counts read as the unsigned numbers the image stores (Priority: P2)

A user views an NRG image whose session counts are larger than the tracks left (also counts of 2^31 or
more) or zero. Every session the image declares is shown; each with the tracks it actually gets from the
track table (feature 340's rule, the same the listing uses), so no negative count and no missing session.

**Why this priority**: wrong information but no crash; same rule as the listing (feature 340).

**Independent Test**: probe rows S-NEG, S-NEGEND, S-OVER, F-ZERO.

**Acceptance Scenarios**:

1. **Given** counts 0xFFFFFFFF, 2 and two tracks, **When** viewed, **Then** session 1 shows 2 tracks
   (tracks 1 and 2) and session 2 shows 0 tracks.
2. **Given** counts 1, 0xFFFFFFFF, **When** viewed, **Then** sessions 1 and 2 show one track each.
3. **Given** counts 1, 2, **When** viewed, **Then** session 2 shows 1 track (track 2).
4. **Given** counts 0, 2, **When** viewed, **Then** session 1 shows 0 tracks and session 2 shows 2 tracks
   (tracks 1 and 2).

### User Story 3 - Images whose counts fit are shown as before (Priority: P1)

**Independent Test**: probe row F-FIT (counts 1, 1): unchanged output; every other image format (ISO,
CCD/IMG, ...) keeps its counts, which always cover the track table.

**Acceptance Scenarios**:

1. **Given** counts 1, 1 and two tracks, **When** viewed, **Then** the output is the same as before the
   change (no "Tracks not in any session" line).

### Edge Cases

- No session count at all (an NRG image without SINF): every track is under the "not in any session" line.
- A session declared with 0 tracks, or after the tracks ran out: the session is shown with 0 tracks.
- A count above 2^31: read unsigned, limited to the tracks left.
- More sessions than tracks: the extra sessions are shown with 0 tracks.
- An image with no tracks: the sessions are shown with 0 tracks, no line.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The image information MUST never read a session count past the image's session table.
- **FR-002**: The image information MUST show every session the image declares, in order, each with the
  number of tracks it gets from the track table by feature 340's rule (the declared count read as an
  unsigned 32-bit number, at most the tracks left) and with exactly those tracks under it.
- **FR-003**: Tracks that no session covers MUST be shown after the last session, under one line saying
  that no session covers them ("Tracks not in any session", after an empty line, like a session
  heading); the line appears only when such tracks exist, and the tracks keep their numbers.
- **FR-004**: The output for an image whose counts cover its tracks exactly MUST stay as it was.
- **FR-005**: The new line is a UI text of the ISO plug-in: it MUST be translated into every enabled
  language (two-stage `.slt` refresh).

### Key Entities

- **Session count**: the number of tracks the image says a session holds (NRG: SINF chunk, unsigned 32-bit).
- **Track table**: the tracks the image holds, in order.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Viewing each of the eight probe images shows the expected session/track structure; 0 fatal
  windows, the program ends cleanly (probe: 16 of 16 rows PASS, before 6 of 16).
- **SC-002**: The unit checks of the session walk pass (saltests 0 failed).
- **SC-003**: The image with fitting counts shows the same information as before.

## Clarifications

### Session 2026-11-01

- Q: Tracks no session covers - listed without a heading, or under a line saying no session covers them?
  → A: under one line "Tracks not in any session" (listed without a heading they would read as tracks of
  the last session); the item allows both (autonomous run: item).
- Q: What does "Number of tracks" of a session show when the declared count does not fit? → A: the tracks
  the session gets from the track table by feature 340's rule (`SalIsoSessionTracks`), consistent with the
  tracks listed under it and with the listing (autonomous run: item).
- Q: What form does the line for tracks no session covers take? → A: the form of the session heading -
  an empty line, then "Tracks not in any session" at the left margin; the tracks below it keep their usual
  form and numbering (autonomous run: conservative).

## Assumptions

- Assumption (autonomous run): only the image information (F3) changes; the listing (feature 340) and the
  readers are not touched.
- Assumption (autonomous run): the session structure of non-NRG formats (ISO: one session of one track;
  CCD/IMG: counts built from the track table) always covers the track table, so their output is unchanged.
- Assumption (autonomous run): a declared count that does not fit is not reported separately in the
  information (out of the item's scope; the listing already marks it incomplete).
