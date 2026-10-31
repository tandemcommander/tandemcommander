---
title: ISO plug-in: NRG CUEX index records are paired into wrong tracks
type: bug
status: open
severity: 4
area: archives
source: measure:350
who: agent
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: M
feature: -
related: [iso-plug-in-a-track-of-a-ccd-or-nrg-image-may-keep-an]
depends-on: []
reason: -
---

# ISO plug-in: NRG CUEX index records are paired into wrong tracks

## Problem

The ISO plug-in reads an NRG (Nero) image's CUEX chunk as a 16-byte header followed by 16-byte entries
and makes one audio track per entry, taking the entry's bytes 4..7 as the track's extent offset. Nero
writes CUEX as 8-byte index records - the lead-in, then for every track one record for index 0 and
one for each index 1..99, then the lead-out - so the pairing matches the disc only when every track
has exactly index 0 and 1. A disc with index points (classical recordings, sound-effect libraries,
test CDs) gets extra tracks (2 tracks of index 1..99 make 100) whose extent offsets come from the
wrong records; the listing hides the tracks the DAOX chunk does not fill, but on a multi-session
image the extra tracks of session 1 shift session 2's track numbers away from its DAOX entries and
SINF counts, so the wrong tracks get the second session's data.

## Evidence

- `src/plugins/uniso/nrg.cpp` `readCUEX` (at the commit of feature 350's review 2 fix, branch
  `350-nrg-cuex-bounds`): `SalNrgCuexEntryCount(header->Size)` entries of `SAL_NRG_CUEX_ENTRY` (16)
  bytes, `track->ExtentOffset = getDWord(data + 0x04)` per entry.
- Review 2 of feature 350, NOTE 1 (`specs/350-nrg-cuex-bounds/fix-log.md`, section *Review*): its
  real-layout images (8-byte records, `imgrev.py`; now kinds `idx2` / `idx20` of
  `specs/350-nrg-cuex-bounds/probe/img350.py`) list their 2 / 20 tracks on main and on 350 because the
  listing hides the unfilled extra tracks; libmirage reads CUEX as 8-byte records, one chunk a session.
- The multi-session shift is reasoned from the code, not measured (no multi-session image with index
  points was built).

## Expected

The CUEX reader makes one track per track number of its records (index 1's LBA as the track's start,
the lead-in and the lead-out not tracks), so a disc with index points gets exactly its tracks and a
multi-session image keeps each session's tracks aligned with its DAOX and SINF chunks; images without
index points list as before (feature 329's, 331's and 350's probe images).

## Notes

- Feature 350 bounded the chunk (`SalNrgCuexSizePlausible`, at most 2 + 99 x 100 records) and kept
  the pairing on purpose (its scope was the size bounds); a new reader must keep those bounds.
- Related: `iso-plug-in-a-track-of-a-ccd-or-nrg-image-may-keep-an` (a track the DAOX chunk does not
  fill keeps uninitialised fields - the extra tracks here are such tracks).
- Review 3 of feature 350, NOTE 2: a real CUEX chunk of an odd number of records (8 mod 16 bytes,
  e.g. one track of index 0, 1, 2 = 40 bytes) did not open on main (the next chunk header was read
  8 bytes early); since 350 it opens through this pairing, so its extent offsets may be wrong - a class
  of images this item now also covers (read-only, audio extraction is refused).

## Log

- 2026-10-31 — created (source measure:350)
- 2026-10-31 — extended: review 3 NOTE 2 of feature 350 (odd record counts now open)
- 2026-10-31 — moved to Next position 32
