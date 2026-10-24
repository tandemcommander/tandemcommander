---
title: ISO plug-in: a UDF file whose track does not open is left partly written in the target
type: bug
status: open
severity: 3
area: archives
source: review:338
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: a UDF file whose track does not open is left partly written in the target

## Problem

While a UDF file of a disc image is written, an allocation extent whose track does not open makes the reader
stop the file with an error, but the file written so far is left in the target under its full name - it
looks like a complete file. Every other error path of the readers removes such a part file. Since feature
338 a whole unpack fails and keeps the image, but Copy (F5) and Unpack leave the cut file behind.

## Evidence

- Review 1 of feature 338 (`specs/338-uniso-skip-fails-unpack/fix-log.md`, section *Review*, NOTE); read
  at c99f39e5, not reproduced (needs a multi-track image whose UDF file extent points into a track that
  does not open).
- `src/plugins/uniso/udf.cpp` `CUDF::UnpackFile`: inside the extent loop `if (!Image->OpenTrack(track))`
  -> `Error(IDS_CANT_OPEN_TRACK, ...)` and `throw UNPACK_ERROR` (around line 1183) - the `!bFileComplete`
  clean-up after the loop (clear read-only, `DeleteFileU8`) is skipped.

## Expected

A file the reader stops is removed from the target as on a read error (or kept under a name that says it
is incomplete); the result stays "not extracted".

## Log

- 2026-10-24 — created (source review:338)
- 2026-10-24 — moved to Next position 76
