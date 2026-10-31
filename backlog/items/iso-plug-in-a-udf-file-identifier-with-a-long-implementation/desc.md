---
title: ISO plug-in: a UDF file identifier with a long implementation-use field reads past its buffer
type: bug
status: in-progress
severity: 6
area: archives
source: review:361
who: agent
created: 2026-10-31
updated: 2026-11-01
verified: 2026-11-01 443ee778
effort: S
feature: 363
related: []
depends-on: []
reason: -
---

# ISO plug-in: a UDF file identifier with a long implementation-use field reads past its buffer

## Problem

The UDF folder walk takes a file identifier name at 38 + L_IU with L_FI bytes, both from the image, without comparing them with its two-sector buffer: a damaged identifier makes it read past the buffer.

## Evidence

- `src/plugins/uniso/udf.cpp` at 46806c89: `CUDF::ReadFileIdentifier` (line 553) reads L_FI and L_IU (16 bits)
  from the identifier and calls `DecodeOSTACompressed(sector + 38 + iu, fi, fileName)` (line 563) without a bound;
  it returns `4 * ((38 + fi + iu + 3) / 4)`. `CUDF::ScanDir` (line 968) holds the folder in
  `Uint8 directory[2 * SECTOR_SIZE]` (line 972, the stack) and calls it at `directory + p` with `p <= 2048`
  (line 1010) - an L_IU near 65535 reads up to 64 KB past the buffer; the next `p` is then far past it too (the walk
  steps back one sector at a time).
- Found by review 2 of feature 361 (NOTE 1) by reading the code; no probe drove it.

## Expected

An identifier that does not fit the buffer is refused like an invalid tag; the folder is marked incomplete; saltests and a probe row.

## Approach

A pure rule in `src/common/` (as feature 361's `salisoudfentry.h`): an identifier fits when 38 + L_IU + L_FI lies
within the bytes the walk holds from `p`; otherwise the folder is refused as with an invalid tag (330's mark). A
probe row on a `ud.iso` copy (feature 330's seed) whose identifier gets L_IU 0xFFFF.

## Notes

- Severity: a read past a stack buffer on a damaged image; whether it crashes is not verified (the stack usually
  holds 64 KB more) - the lower band value, as the rules ask when unsure.

## Log

- 2026-10-31 — created (source review:361)
- 2026-10-31 — moved to Next position 1
- 2026-11-01 — verified at 443ee778: iso363 probe at 443ee778: L_IU 0xFFFF / 0x1000 / L_FI past buffer - name read past buffer listed as _, image deleted by unpack, 8 FAIL
- 2026-11-01 — run started, feature 363
