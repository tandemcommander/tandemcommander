# Research - 357-uniso-other-layouts

## R1. Which layouts can carry a later session?

- **Decision**: NRG offset (0x4B000), 2336, NCD (0x16E4E), PDI (0x130), Easy CD Creator, CIF, C2D (0x20000,
  0x76220 Mode 2, Roxio 0x120), CIF 2332.
- **Rationale**: each is a CD image layout whose listed volume is an ISO 9660 volume found at sector 16 of the
  layout; a crafted two-session image opened through every one of them (`img357.py` checks the detection order)
  and lost its second session on a whole unpack (probe before: 16 FAIL rows). Their sectors carry user data at a
  fixed offset (`SectorHeaderSize`), which 355's check reads.
- **Alternatives considered**: Xbox (XDVDFS, a DVD format without sessions, no ISO 9660 descriptor at sector 16 -
  355's rule would mark every Xbox image because the size is unknown); HFS / APFS (block sizes of the file
  system, not CD sectors; a non-raw HFS image has no CD sessions); MDF (needs the sync at offset 0 - already 355).
  All left as they are.

## R2. Which rule?

- **Decision**: 355's `SalIsoRawRestDecision` and its block (user data of each whole sector past the volume, at
  most 512, all zero = keep), unchanged.
- **Rationale**: the item's *Expected* names it; the read address `DataOffset + n * SectorRawSize +
  SectorHeaderSize` is the opened layout's for every covered layout (2048-byte layouts: the whole sector; ECDC /
  C2D Mode 2: after 24 bytes; 2336 / CIF / CIF 2332: after 8). A 2048-byte layout with an offset could also use
  354's byte check of the whole rest, but 354's check starts at offset 0 and counts the trailing partial sector;
  355's rule is offset-aware and one rule for all eight is simpler to test.
- **Alternatives considered**: a new rule per layout (no measured need); 354's rule for the cooked offsets
  (needs an offset parameter - a change to a decided rule).

## R3. How does the block know the layout?

- **Decision**: the plain branch sets an `int plainLayout` (enum `SalIsoPlainLayout` in `salisotrack.h`) in each
  `else if` of the detection chain; `SalIsoPlainRawRuleApplies(rawStart, ccdMissing, plainLayout)` decides.
- **Rationale**: the pure decision is testable in `saltests` (stop-rules 2.5); the layout fields alone cannot tell
  NRG from NCD and would make the rule depend on numbers.
- **Alternatives considered**: `!rawStart && !cookedIso` - would also catch Xbox, HFS and APFS (all opened with
  2048 or file-system block sizes when `CheckForISO` failed); a rule by the layout's numbers is fragile.

## R4. UDF-only at the NRG offset

- **Decision**: marked (355 marks a raw image without an ISO 9660 size).
- **Rationale**: fails closed; `CheckForNRG` is the only covered check that accepts `BEA01`; nothing measured
  writes such a file.
