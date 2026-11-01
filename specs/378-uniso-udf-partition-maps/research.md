# Research - 378-uniso-udf-partition-maps

## R1 - The bounds of the partition map walk

- Decision: the area is [440, min(held, 440 + table length)) computed in 64 bits; each declared map needs its
  type and length bytes inside the area, a length >= 2 and >= the bytes the reader takes from a map of its
  type, and its end inside the area. The walk's step is the map's length (>= 2), so at most (held - 440) / 2
  steps; a count beyond the maps that fit fails at the first map that does not fit.
- Rationale: the item - "read only inside the descriptor sector and the declared map table length"; "a count
  or a map length that does not fit (or a map length of 0) is refused".
- Alternatives: refusing a table length larger than the sector even when the maps fit (rejected: changes a
  case the item does not name - clarification 2); requiring the ECMA-167 exact sizes 6 / 64 (rejected: a type 2
  map of 44 - 63 bytes is read safely today; the item asks for "fits", not for conformance).

## R2 - Bytes the reader takes from a map

- `ReadPartitionMap`: byte 0 (type), byte 1 (length); type 1: words at 2 and 4 (bytes up to 5); type 2: entity
  identifier at 4 (`ReadEntityID`: 1 + 23 + 8 bytes, up to 35), words at 36 and 38, the metadata location
  dword at 40 (up to 43). Minimum length: type 1 = 6, type 2 = 44, others = 2.

## R3 - Where the refusal goes

- Decision: `ReadLVD` returns `FALSE` before any `CPartitionMap` is created; `CUDF::Open` calls
  `Error(IDS_ERROR_LISTING_IMAGE, quiet, block)` and returns `FALSE`.
- Rationale: the same exits as a sector that cannot be read (`IDS_ERROR_READING_SECTOR` + `return FALSE`);
  `CISOImage` deletes the file system object, the track is not opened; `CUDFISO::Open` marks `PartMissing`
  when the anchor at 256 is present (330) - the listing is incomplete and a whole unpack keeps the image.
  The existing text names the sector and says the content is incomplete; no new string (no `.slt` refresh).
- Alternatives: `IDS_UDF_INVALID_TAG_ID` (rejected: the tag is valid); a new text (rejected: a translation
  round for no gain in what the user can do).

## R4 - Measurement

- The read past the buffer is invisible in the GUI (no crash in the measured runs: the stack bytes past the
  sector gave maps that were taken). The probe distinguishes by acceptance (before: a.txt extracted, image
  deleted; after: refused, kept); saltests prove the walk's bounds.
