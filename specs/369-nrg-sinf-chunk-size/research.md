# Research - 369-nrg-sinf-chunk-size

## R1 - The SINF chunk's format

- Decision: a SINF chunk is 4 bytes, a big-endian count of the session's tracks.
- Rationale: libmirage's NRG parser (`mirage_parser_nrg_load_session` reads one 32-bit value from
  the SINF block) and the plug-in's own reader agree; all images of features 334, 340, 365 use 4 bytes.
- Alternatives: take the first 4 bytes of a longer chunk - rejected (guessing; spec Clarifications).

## R2 - Where to restore the chunk alignment

- Decision: in `ReadNRGRoot`, remember the position after the header and seek to `start + Size`
  after every known reader.
- Rationale: the item's first option; one place for all readers (DAOX does not end at its chunk's end
  either); the readers that already seek there (CUEX, ETN2, CDTX) are unaffected.
- Alternatives: each reader checks its size - more code, misses DAOX.

## R3 - How to mark the listing incomplete

- Decision: `iso->ListingLeftOut.SetIncomplete()` from `readSINF` (public member, as `ReadSessionCCD`
  does in feature 352) - it survives to the listing; a whole unpack then fails and the image is kept.
- Alternatives: a new flag - unnecessary.

## R4 - ETN2

- Decision: no change - feature 365's `readETN2` reads whole entries into a fixed buffer with every read
  checked and ends at the chunk's end; covered by `iso365_probe` (22 / 0) as a regression.
