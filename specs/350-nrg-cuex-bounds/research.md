# Research - 350-nrg-cuex-bounds

## R1 - The CUEX chunk's layout

- Decision: the reader's model stays - a 16-byte header, then 16-byte entries, one audio track each
  (the extent offset at entry byte 4). Entry count = 0 for a chunk under 16 bytes, else
  `(size - 16) / 16` (whole entries only).
- Rationale: it is what the reader always did for well-formed chunks (Nero's CUEX: 8-byte index
  records, two per track plus lead-in and lead-out = 16 * (tracks + 1) bytes); feature 329's and
  331's crafted images use this layout and open.
- Alternatives: re-interpreting CUEX as 8-byte index records (changes which tracks a real image
  gives - out of scope).

## R2 - A chunk outside the image

- Decision: `SalNrgChunkFits(pos, Size, fileSize)` (331) before reading; when it does not fit, seek
  past it and return FALSE, as `readCDTX` does.
- Rationale: one rule for all chunk readers (item *Notes*); the result for the image (not opened as
  NRG - the next header read fails at the end of the file) is the same as before, without first
  building a track from every 16 bytes.
- Alternatives: stopping the chunk list there (a change in `ReadNRGRoot` not asked for).

## R3 - The next chunk's position

- Decision: after the entries, `Seek(chunkStart + Size, FILE_BEGIN)`.
- Rationale: `ReadNRGRoot` reads the next header where the reader stopped; a whole-entries chunk
  ends exactly there anyway (no change), a short or odd chunk no longer shifts the next header
  (measured: odd.nrg did not open).
- Alternatives: leaving the position (keeps N-ODD failing and the short chunk's 8 bytes unread).

## R4 - Short reads

- Decision: `read != 16` (header or entry) → no track, return FALSE (position as the read left it,
  as before for a failed read).
- Rationale: item *Expected* - never a track from a short read. Within a chunk that fits the image a
  short read is only an I/O error.

## R5 - The largest CUEX chunk a disc can have (reviews 1 and 2)

- Decision: a chunk larger than (2 + 99 x 100) x 8 = 79,216 bytes is skipped like one that does not
  fit (`SalNrgCuexSizePlausible`).
- Rationale: the first fix (no bound) still built 6.3 million tracks from a 96 MiB chunk inside the
  image (review 1: 1565 MB, 179 s). Review 1's 99-entry bound refused real discs with index points
  (review 2: 2 tracks of index 1..99 = 100 entries, 20 tracks of index 1..10 = 110 - main opens them;
  libmirage reads CUEX as 8-byte records, one chunk a session). The record bound accepts every disc
  the Red Book allows and keeps the cost of a damaged chunk at most 4,950 tracks.
- Alternatives: reading at most 99 entries and ignoring the rest (review 2's option 1) - changes the
  track table of real images with index points (fewer, different tracks than main) for no gain.
