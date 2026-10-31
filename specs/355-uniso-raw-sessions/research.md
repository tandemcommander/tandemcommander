# Research - 355-uniso-raw-sessions

## R1 - Which files reach the new rule

- Decision: `CISOImage::Open`'s plain branch (no session table read), `rawStart` (sector 0 carries the CD
  sync pattern and a mode byte 1 or 2 - `DetectSectorType`), `CcdMissing` false.
- Rationale: `ReadSessionInfo` reads a table only for `.nrg` and `.img` (+ `.ccd`); every raw `.bin`, `.mdf`,
  `.iso`, and an `.img` whose `.ccd` exists but is not read, takes the plain branch unmarked (measured: 10
  rows deleted at 4cc97934). The `.img` without its `.ccd` keeps 353's block (spec Clarifications).
- Alternatives: replace 353's condition by `rawStart` alone - rejected, it would change 353's decided rows.

## R2 - The zero-rest check for raw sectors

- Decision: read the 2048 bytes of user data of each whole sector past the volume at the opened layout
  (`DataOffset + n * SectorRawSize + SectorHeaderSize`), mark unless every read returns 2048 bytes and all
  are zero; more than 512 sectors (`SAL_ISO_ZERO_REST_SECTORS`) mark without reading.
- Rationale: a raw sector's sync, header and EDC/ECC are never all zero, so 354's byte check of the whole
  rest cannot be reused. The user data of a later session's sector 16 (its volume descriptor) is never
  zero, also when the later session is Mode 2 XA and the opened layout is Mode 1 (the descriptor lies 8
  bytes further, still inside the 2048 bytes read). Audio sectors are not zero. A post-gap of a data track
  is stored as sectors of zero user data; a run-out read as zeros is zero everywhere.
- Real dumps: none on the machine (user profile, D:, E: searched to depth 4) - person step at closing.
- Alternatives: no zero check (353 as it is) - rejected: it keeps every one-session `.bin` with a
  post-gap, making "Delete archive after unpacking" useless for the common case, while a zero tail holds no
  data.

## R3 - A partial sector at the end

- Decision: not read; only whole sectors count (as 353's and 354's rules).
- Rationale: fewer bytes than one sector cannot hold a later volume's 17 sectors.

## R4 - No valid descriptor at sector 16

- Decision: mark (fails closed, as 353): an HFS-only or damaged raw image is kept.
- Rationale: the volume's size is unknown, nothing can show that the rest is empty.
