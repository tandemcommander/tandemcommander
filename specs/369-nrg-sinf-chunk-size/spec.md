# Feature Specification: NRG SINF chunks read by their size

**Feature Branch**: `369-nrg-sinf-chunk-size`  
**Created**: 2026-11-01  
**Status**: Draft  
**Input**: User description: "Backlog item iso-plug-in-nrg-sinf-and-etn2-chunks-are-read-without-regard - implement exactly what it describes." From backlog item iso-plug-in-nrg-sinf-and-etn2-chunks-are-read-without-regard.

## Background

A Nero disc image (`.nrg`) ends with a table of chunks (ETNF / ETN2 / CUEX / DAOX track tables, one SINF
chunk a session holding that session's track count, CD-Text, END!). The ISO plug-in reads the chunks one
after another; each chunk reader must leave the file position at the end of its chunk, or the next chunk
header is read from the wrong place.

Measured at 720a7472 (Debug x64, new probe `iso369_probe` built on 340's `iso340_probe`, images of two
Mode 1 tracks - session 1 `a.txt`, session 2 `b.txt` - unpacked with Alt+F9 and "Delete archive after
unpacking"):

| Image | SINF chunks (size: count) | Before |
|---|---|---|
| fit (control) | 4: 1, 4: 1 | both sessions extracted, image deleted - PASS |
| sinf8 | 8: 1 + 4 zero bytes, 4: 1 | only `Session 01/a.txt`, box "Unknown track type.", `b.txt` lost |
| sinf8tail | 4: 1, 8: 1 + 4 zero bytes | as sinf8 |
| sinf2 | 2: -, 4: 1 | as sinf8 |
| sinf0 | 0: -, 4: 1, 4: 1 | only `Session 01/a.txt`, the box, `Session 02/b.txt` lost |

The ETN2 half of the item already holds at HEAD: feature 365 rewrote the ETN2 reader (one track per whole
32-byte entry read into a fixed buffer, every read checked, a chunk outside the image or implausible
skipped, the position set to the chunk's end).

## Clarifications

### Session 2026-11-01

- Q: Should a SINF chunk longer than 4 bytes still give its first 4 bytes as the session's count? → A: No - any SINF chunk not exactly 4 bytes is refused whole (no count) and the listing marked incomplete (autonomous run: conservative - refuse rather than guess; the item allows "refused or skipped")
- Q: Should the DAOX reader also be made to stop at its own chunk's end when its track range claims more entries than the chunk holds? → A: No - only the file position after it is set to the chunk's end (the loop-level seek); what it reads past its chunk is another defect, recorded as an Inbox item if confirmed (autonomous run: item - its scope names SINF and ETN2; conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A damaged NRG session table does not lose the rest of the image (Priority: P1)

A user opens or unpacks a Nero image whose session information chunk (SINF) has an unexpected size
(damaged or written by a tool that differs from Nero). The other chunks of the image's table are still
read correctly; the damaged session count is not used; the image is never deleted after unpacking
because its listing is known to be incomplete.

**Why this priority**: today one wrong-sized chunk makes the plug-in read the remaining chunk table from
the wrong place: a session's files disappear from the listing and the unpack shows an error box.

**Independent Test**: the probe `iso369_probe` - unpack each image with "Delete archive after
unpacking" and compare the extracted files, the windows shown and whether the image was kept.

**Acceptance Scenarios**:

1. **Given** an NRG image whose SINF chunks are all 4 bytes, **When** it is unpacked whole with "Delete
   archive after unpacking", **Then** every session's files are extracted and the image is deleted (as
   before).
2. **Given** an NRG image with one SINF chunk of 8 bytes (first or last), **When** it is unpacked whole,
   **Then** no error box shows, the chunk after it is read from its own start, the files the remaining
   session layout lists are extracted, and the image is kept.
3. **Given** an NRG image with a SINF chunk of 2 or 0 bytes before whole ones, **When** it is unpacked
   whole, **Then** no error box shows, the following whole SINF chunks are read, and the image is kept.

### Edge Cases

- A SINF chunk whose declared size runs past the end of the image: refused, the listing marked
  incomplete; the next chunk header cannot be read, so the chunk table ends there (as for any chunk of
  that kind today).
- A SINF chunk of 4 bytes that cannot be read whole: refused, no session count from it, the listing
  marked incomplete.
- A known chunk reader that stops early (a short read) or reads less than its chunk (a DAOX chunk larger
  than its entries): the next chunk header is still read at the chunk's end.
- A known chunk reader that skips a chunk lying past the end of the image: the next read fails and the
  table ends, as today.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A SINF chunk is used only when its size is exactly 4 bytes, it lies within the image and
  its 4 bytes are read whole; then its count is the session's track count, as before.
- **FR-002**: Any other SINF chunk is refused: no session count is taken from it and the image's
  listing is marked incomplete (a whole unpack fails, "Delete archive after unpacking" keeps the image),
  with no new box and no new UI string.
- **FR-003**: After every chunk reader the NRG reader knows (CUEX, DAOX, SINF, ETNF, ETN2, CDTX), the
  next chunk header is read at the end of the chunk as its header declares it (chunk start + size),
  whatever the reader consumed.
- **FR-004**: The ETN2 reader keeps feature 365's behaviour (whole entries only, never past its buffer,
  position at the chunk's end); no change is needed for it.
- **FR-005**: Images whose chunks are well formed are read exactly as before (same tracks, sessions,
  labels; the probes of features 340, 350 and 365 keep their results).
- **FR-006**: The rule deciding whether a SINF chunk is usable is a pure function under `src/common/`
  with `saltests` checks.

### Key Entities

- **SINF chunk**: one per session; a 4-byte big-endian track count of that session.
- **Chunk table**: the chunks between the image's data and its footer, each an 8-byte header (4-byte
  identifier, 4-byte big-endian size) followed by its size of bytes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `iso369_probe` goes from PASS 6 / FAIL 4 (before) to all rows PASS, no error box in any
  row.
- **SC-002**: The probes of features 340 (`iso340_probe`, 14 / 0), 350 and 365 (`iso365_probe`, 22 / 0)
  keep their recorded results.
- **SC-003**: `saltests` passes with the new SINF checks; a mutant that accepts every SINF size fails
  them.

## Assumptions

- Assumption (autonomous run): a SINF chunk of a size other than 4 is refused whole rather than read
  for its first 4 bytes - the conservative option (refuse rather than guess); the item allows "refused
  or skipped".
- Assumption (autonomous run): the session layout left after a refused SINF chunk (fewer sessions) is
  listed as the existing rules list it; the incomplete mark keeps the image.
- Assumption (autonomous run): the loop-level seek to the chunk's end (the item's first option) is used,
  so it also covers DAOX; what a DAOX reader reads past its own chunk is not changed (out of scope).
- Release build not driven; crafted images only (no real Nero image with a damaged SINF).
