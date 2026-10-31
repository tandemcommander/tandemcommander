---
title: ISO plug-in: a CloneCD session number from the .ccd writes outside the reader arrays
type: bug
status: in-progress
severity: 7
area: archives
source: review:351
who: agent
created: 2026-10-31
updated: 2026-10-31
verified: 2026-10-31 2f260c23
effort: S
feature: 352
related: [iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables]
depends-on: []
reason: -
---

# ISO plug-in: a CloneCD session number from the .ccd writes outside the reader arrays

## Problem

The ISO plug-in's CloneCD reader (`CISOImage::ReadSessionCCD`) takes each `[Entry n]` section's
`Session=` value from the `.ccd` file and uses `Session - 1` as an index into four arrays it
allocated with one element per `[Session n]` section (`pointMin`, `pointMax`, `extents`,
`extentsEnd`) - without a range check. A damaged or crafted `.ccd` with `Session=0` writes before
the heap block; `Session=200` writes about 800 bytes past a one-session array. In the Debug build
the CRT reports heap corruption; in a measured case (`Session=200`) the whole unpack went on,
succeeded and **deleted the image** ("Delete archive after unpacking") after the silent
out-of-bounds write. The same reader indexes `Session[i]` for `i` up to the number of
`[Session n]` sections, while `Session` holds one count per `INDEX 1=0` split of the track list -
a `.ccd` declaring more sessions than splits reads past it (by reading, not reproduced). By
reading too: `processTrackSection` / `processEntrySection` / `processSessionSection` count a row
even when its `sscanf` fails (`MODE=x`, an empty value, a duplicated row), so a track's
`ExtentOffset` / `End` can still come from uninitialised stack values for a malformed `.ccd`
(feature 351 made the track's type and mode always defined).

## Evidence

- Review 1 of feature 351 (`specs/351-uniso-track-defaults/fix-log.md`, section *Review*), SHOULD 1
  and NOTE 1; reproduced on the Debug build at 8f35c3e0 with a copy of
  `specs/351-uniso-track-defaults/probe/iso351_probe.ps1` whose `ccd_m1.ccd` had `[Entry 0]`
  `Session=0`: "HEAP CORRUPTION DETECTED: ... wrote to memory before start of heap buffer. Memory
  allocated at ...\src\plugins\uniso\img.cpp(438)"; with `Session=200`: no message, the image
  deleted after the unpack. (The reviewer's scratch: `%TEMP%\rv351\p\iso351_probe.ps1` rows R-S0 /
  R-S200, log `%TEMP%\rv351\probe-oob-debug.txt` - not kept in the repository.)
- `src/plugins/uniso/img.cpp` at 8f35c3e0: `ReadSessionCCD`, the loop over `ccd->EntryArray`
  (`int session = entry->Session - 1;` then `pointMin[session]` ...); the arrays allocated with
  `ccd->SessionArray.Count` elements; the loops over `ccd->SessionArray.Count` that read
  `Session[i]` and `Tracks[firstTrack + j]`; `processTrackSection`, `processEntrySection`,
  `processSessionSection` (`sscanf` results not checked).
- Reachable: opening or unpacking a `.img` whose `.ccd` lies beside it (uniso on in the default
  build).

## Expected

An entry whose session number names no `[Session n]` section, a `.ccd` whose session sections and
track splits disagree, and a row whose value does not parse are refused or ignored without writing
or reading outside the reader's arrays; the image then does not open as CloneCD, or opens with its
listing marked incomplete (a whole unpack fails, the image is kept) - never a silent unpack that
deletes the image. A pure rule for the bounds in `src/common/` with `saltests` checks.

## Notes

- Related to `iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables` (wrong geometry of valid
  multi-session CloneCD tables, not bounds) - the two may be done together.
- Severity 7: memory corruption and a deleted image from a damaged or crafted `.ccd` (a narrow
  scenario).

## Log

- 2026-10-31 — created (source review:351)
- 2026-10-31 — moved to Next position 1
- 2026-10-31 — verified at 2f260c23: still present at 2f260c23: probe (Debug) R-S0 heap corruption img.cpp(438), R-S200 image deleted, R-S257 RTC, R-ABS TRACE_C Session[1], R-DUP plba uninit
- 2026-10-31 — run started, feature 352
