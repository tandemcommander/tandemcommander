# Research - 335-uniso-raw-track-lost

## R1 - Can a lost data track be told apart from a Video CD's MPEG track?

- Decision: yes, by the track's sector 16. A Mode 2 Form 2 sector (CD-ROM XA: subheader submode bit
  0x20 in both copies) is a stream; anything else is a file system area.
- Rationale: ISO 9660 / UDF volume descriptors on CD are recorded in Form 1 sectors (Mode 1, or Mode 2
  Form 1 on CD-ROM XA - Form 2 has no ECC layer and is used for real-time data); a Video CD / SVCD MPEG
  track (track 2 onwards) is recorded in Mode 2 Form 2 sectors from its pregap and front margin on. The
  plug-in already looks for every file system it reads from the track's sector 16 (`DetectTrackFS`),
  and feature 334 already uses sector 16 as the bound for "outside the image".
- Alternatives considered: the track mode of the track table (NRG / CCD say Mode 1 or Mode 2 only - a
  Mode 2 track is either a damaged XA data session or a Video CD stream, not decidable); marking every
  raw track (the item's *Notes*: every Video CD's whole unpack fails - rejected); scanning several
  sectors (more reads, no better decision: a damaged session's sector 16 is the descriptor area).

## R2 - Which image layouts carry the subheader?

- Raw sectors of 2352 bytes (CCD/IMG always `0x930`; NRG DAO raw modes; MDF): sync (12 bytes
  `00 FF x10 00`), header (3 bytes address, mode byte at 15), subheader at 16..23 (file, channel,
  submode, coding - twice). Sizes above 2352 (`0x990` = 2352 + 96 bytes of subchannel) start the same.
- Mode 2 sectors of 2336 bytes (`0x920`, NRG ETNF mode bit 0, e.g. mode 0x03): subheader at 0..7.
- 2048 bytes a sector (cooked Mode 1 / Mode 2 Form 1): only user data - Form 2 data (2324 bytes) cannot
  be stored; such a track is never a Video CD stream.
- `CISOImage::GetSectorOffset(16) - SectorHeaderSize` is the start of the stored sector for every layout.

## R3 - Fail closed

- A sector whose sync, mode byte or one subheader copy does not say Form 2, a read that returns fewer
  bytes than needed, a negative offset: not Form 2 -> the track marks the listing. Cost: a damaged
  Video CD stream track keeps the image after a whole unpack (no data lost).

## R4 - Listing paths (unchanged code, reused rule)

`SalIsoTrackMarksListing(kind, outsideImage, outcome)` already marks a data track with `outsideImage`
in every outcome, so the "lost" flag passes through the same parameter (renamed `rawLost`): session
folders (the track opens via `CRawFS` and lists nothing - LISTED - still marked), the single listing
(NOT_TRIED - still marked), the fallback listing. 334's tests of the rule stay valid unchanged.

## R5 - Measured (probe before)

`probe/result_before.txt` at e363177e: PASS 10, FAIL 4 (M-NOFS, M-NOFS-F1, S-NOFS, S-RAW deleted the
image); the NRG Mode 2 / 2336 Form 1 control (M-OK-2336) lists both files - the 2336 path is read.
