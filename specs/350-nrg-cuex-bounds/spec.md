# Feature Specification: An NRG image's CUEX chunk gives only the tracks it holds

**Feature Branch**: `350-nrg-cuex-bounds`  
**Created**: 2026-10-31  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-an-nrg-cuex-chunk-under-16-bytes-makes-a-huge` - "ISO plug-in: an NRG CUEX chunk under 16 bytes makes a huge track count". From backlog item iso-plug-in-an-nrg-cuex-chunk-under-16-bytes-makes-a-huge.

## Background (measured at cadc65bb)

The ISO plug-in (`uniso`, on in the default build) opens a Nero image (`.nrg`) by reading the chunk
list at the end of the file (opening the file in a panel: `ReadSessionInfo` -> `ReadSessionNRG` ->
`ReadNRGRoot`). The CUEX chunk is a 16-byte header followed by one 16-byte entry a track; the
reader makes one audio track per entry. The chunks follow each other: each reader is expected to
consume exactly its chunk's bytes, so the next chunk header is read right after it.

`readCUEX` computes its entry count as `(Size - 16) / 16` from the chunk's size (a 32-bit unsigned
value from the image), never compares it with the chunk or the image, and does not check how many
bytes each read returned:

- a chunk of fewer than 16 bytes underflows to 268,435,455 entries; the reader then makes one track
  from every 16 bytes that follow (the next chunks, any data) until a read fails at the end of the
  file - the image then does not open as NRG;
- a chunk claiming more bytes than the image has does the same;
- a chunk whose size is not 16 + a whole number of entries leaves its last bytes unread, so the next
  chunk header is read from the wrong place.

Measured with a hidden-desktop probe on the Debug x64 build of cadc65bb, four crafted images of two
audio tracks: the control opens with its two tracks (peak working set 84 MB, 0.7 s); an 8-byte CUEX
chunk followed by a 96 MiB chunk grows the program to 1036 MB, keeps its window from answering for
50 s, and ends with "Unknown file format or not a valid ISO image"; a CUEX chunk claiming 0xFFFFFFF0
bytes does the same (1037 MB, 50 s); a CUEX chunk 4 bytes longer than its two entries does not open.

Feature 331 bounded the CDTX and DAOX readers with `src/common/salnrgcdtext.h`
(`SalNrgChunkFits`: a chunk is read only when it lies within the image, else skipped like an unknown
chunk).

## Clarifications

### Session 2026-10-31

- Q: What does the reader do with a CUEX chunk that does not lie within the image? → A: it skips it
  like an unknown chunk, as the CD-Text reader does since 331 - no track is made from it; the chunk
  list then ends at the end of the file and the image does not open as NRG, as before (autonomous
  run: item - *Notes*, "the same rule fits here")
- Q: Where does the next chunk start after a CUEX chunk whose size is not 16 + whole entries, or under
  16 bytes? → A: right after the chunk's bytes - the reader takes the whole entries it holds and
  continues after the chunk, as for any other chunk (autonomous run: item - *Expected*, "takes only as
  many entries as its chunk holds"; conservative - a valid chunk is consumed exactly as before)
- Q: Should the CUEX reader also refuse more than 99 tracks (a CD's maximum) when its chunk lies
  within the image? → A: Yes (revised after review 1, which measured a 96 MiB CUEX chunk inside a
  100 MB image on the first fix: 6.3 million tracks, 1565 MB, 179 s - the item's own symptom, worse):
  a chunk claiming more entries than a CD has tracks is skipped like one that does not fit; no real
  disc image has more than 99 tracks, so nothing is lost (autonomous run: item - *Problem*, "a damaged
  image costs memory and time"; conservative - refuses rather than guesses)
- Q: What happens when a read of the header or an entry returns fewer bytes than asked? → A: no track
  is made from it, the reader stops taking entries and reports failure as it did before; the chunk list
  reader goes on as it did before (autonomous run: item - *Expected*; conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A damaged NRG image opens without exhausting memory (Priority: P1)

A user opens an NRG image whose CUEX chunk is damaged (shorter than its header, or claiming more
bytes than the image has). The program answers at once and does not grow by hundreds of megabytes;
the image either opens with the tracks its other, intact chunks describe, or is reported as not a
valid image - it is never built from every 16 bytes up to the end of the file.

**Why this priority**: the item's main point - a damaged image cost a gigabyte of memory and almost
a minute of a frozen window at the open.

**Independent Test**: open the crafted images `short.nrg` and `past.nrg` in a panel (probe rows
N-SHORT, N-PAST): the program answers within seconds, its peak working set stays within 150 MB of the
control's.

**Acceptance Scenarios**:

1. **Given** an NRG image with a CUEX chunk of 8 bytes followed by a large chunk and then the image's
   good chunks, **When** the user opens it, **Then** the short chunk adds no track, the image opens
   with the good chunks' tracks, and the program's memory stays near the control's.
2. **Given** an NRG image whose CUEX chunk claims more bytes than the image holds, **When** the user
   opens it, **Then** no track is made from that chunk, the program does not crash, and its memory
   stays near the control's.

---

### User Story 2 - A CUEX chunk with extra bytes no longer hides the rest of the image (Priority: P2)

A user opens an NRG image whose CUEX chunk is a few bytes longer than its whole entries. The image
opens with its tracks; the chunks after the CUEX chunk are read from where they start.

**Why this priority**: part of "takes only as many entries as its chunk holds" - a secondary,
measured symptom of the same reader.

**Independent Test**: open `odd.nrg` (probe row N-ODD): the image opens, a track is listed.

**Acceptance Scenarios**:

1. **Given** an NRG image of two audio tracks whose CUEX chunk is 4 bytes longer than its two
   entries, **When** the user opens it, **Then** it opens with its two tracks.

---

### User Story 3 - Intact NRG images open as before (Priority: P1)

A user opens a well-formed NRG image; it lists exactly the tracks it listed before.

**Independent Test**: probe row N-OK (the control) and feature 329's A-OPEN row.

**Acceptance Scenarios**:

1. **Given** a well-formed NRG image of two audio tracks, **When** the user opens it, **Then** it
   opens with its two tracks, as before.

### Edge Cases

- A CUEX chunk of exactly 16 bytes (header only): no track, the reader continues after it.
- A CUEX chunk of 0 bytes: no track, the next chunk header follows directly.
- A read of an entry that returns fewer than 16 bytes (an I/O error within a chunk that lies within
  the image): no track is made from it, the reader stops taking entries and reports failure.
- A CUEX chunk lying within the image but holding more than 99 entries (only possible when the
  image's chunk offset points far before its end): skipped, no track (review 1; probe row N-INSIDE).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The CUEX reader MUST take as entries only the whole 16-byte entries that follow the
  16-byte header within the chunk's own size; a chunk under 32 bytes holds none.
- **FR-002**: The CUEX reader MUST read a chunk only when the chunk lies within the image file and
  holds at most 99 entries (a CD's tracks); otherwise it MUST skip the chunk like an unknown one and
  make no track from it.
- **FR-003**: The CUEX reader MUST check that every read returned the whole header or entry and MUST
  never make a track from a short read.
- **FR-004**: After a CUEX chunk that lies within the image, the next chunk header MUST be read from
  the byte after the chunk, whatever the chunk's size.
- **FR-005**: A well-formed NRG image MUST give the same tracks as before.
- **FR-006**: The rule deciding a CUEX chunk's entry count MUST be a pure function next to feature
  331's NRG rules (`src/common/salnrgcdtext.h`) with `saltests` checks.

### Key Entities

- **CUEX chunk**: a size from the image, a 16-byte header, then 16-byte entries - one audio track
  each (its extent offset at entry byte 4).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Opening an NRG image with a CUEX chunk under 16 bytes or past the image's end keeps the
  program's peak memory within 150 MB of an intact image's and the window answering within 5 s
  (before: +950 MB, 50 s) - probe rows N-SHORT and N-PAST.
- **SC-002**: The image with the short CUEX chunk and good later chunks opens with its tracks
  (before: not opened) - N-SHORT; the image with a CUEX chunk 4 bytes too long opens - N-ODD.
- **SC-003**: The control image opens with its two tracks before and after - N-OK; 329's A-OPEN row
  still passes.
- **SC-004**: `saltests` checks of the entry-count rule fail when the rule is mutated (underflow back,
  remainder counted as an entry).

## Assumptions

- Assumption (autonomous run): a CUEX chunk of more than 99 entries describes no disc (Red Book's
  track limit; Nero numbers tracks 01..99) - it is treated as damaged (review 1).
- Assumption (autonomous run): a chunk that does not fit the image makes the image not open as NRG
  (the skip seeks past the end of the file, so the next header cannot be read) - the same result as
  before, without building tracks first, and the same behaviour as 331's CD-Text reader.
- The plug-in interface, the stored settings and the UI texts do not change.
