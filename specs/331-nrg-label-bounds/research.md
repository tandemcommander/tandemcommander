# Research - 331-nrg-label-bounds

## R1 - Where the name is built

- Decision: a heap buffer sized by `snprintf(NULL, 0, ...)`, the whole name; the listing rule of
  feature 329 (`SalListingAcceptsFileU8` in `CAudio::AddFileDir`) decides.
- Rationale: the standing rule "a path or name is never cut"; 329 already reports a refused audio
  name. A bounded stack buffer would need a cut or a refusal of its own.
- Alternatives: `char[3 * MAX_PATH]` and refuse longer labels - a second length rule beside the
  listing's, rejected.

## R2 - CD-Text chunk size

- Decision: the chunk must lie within the image after its header (`SalNrgChunkFits`, 64-bit); the
  buffer is exactly `header->Size` bytes; the text is gathered in place (the write position 12k never
  passes the read position 4 + 18k); labels are split from the gathered text by length, so no
  terminator area is needed.
- Rationale: removes all three overreaches of the old code (the 32-bit wrap of `Size + 1 + n`, the
  4-byte overread of the last block, the terminator area past the buffer for sizes below 36) with one
  buffer whose size is the chunk's.
- Alternatives: keep the terminator area (`Size + 1 + n` in `size_t`) - still needs the clipping
  and keeps a size that depends on a count from another chunk; rejected. A fixed cap - not needed
  (clarification).
- Behaviour for consistent images: a real CDTX chunk is a whole number of 18-byte packs (4-byte
  header, 12 text bytes, 2-byte CRC; review 1) - for such sizes the gathered text is the same 12 bytes
  per pack in the same order as before. Only for other sizes did the old loop append up to 4 bytes from
  past the chunk.

## R3 - DAOX track numbers

- Decision: numbers 1..trackCount (the tracks the CUEX chunk added); an entry out of range is read
  and dropped; a short read ends the chunk (`return FALSE`, as a failed read did).
- Rationale: nothing outside the table is written; the read position stays as the old code left it.
- `GetTrack`'s `<=` is fixed too (an index equal to the count is outside the table); its other
  callers (`audio.cpp` with the track's own index, `udf.cpp` with `GetTrackFromExtent`) pass valid
  indexes, so they are unaffected.

## R4 - Reproduction

- The item notes no run reproduced it. The sites are confirmed by reading at d87666d5; this run does
  not build images that drive the overrun on the old code. Evidence after the fix: the `saltests`
  rules (the sizes and lengths the old code mishandled are among the checked inputs) and feature
  329's probe (the fitting-label path unchanged).

## R5 - Found on the way (outside the item)

- `readCUEX`: `(header->Size - 0x10) / 0x10` underflows for a chunk smaller than 16 bytes (a huge
  track count, one allocation per iteration until the reads fail).
- `ListImage` with "session as directory" (default on): `Session[]` counts from SINF chunks index
  `Tracks[]` without a check against the track count.
- Both go to the backlog's Inbox (`measure:331`).
