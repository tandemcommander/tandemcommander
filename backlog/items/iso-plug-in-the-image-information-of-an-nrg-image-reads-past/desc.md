---
title: ISO plug-in: the image information of an NRG image reads past its session table
type: bug
status: new
severity: 5
area: archives
source: measure:340
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

# ISO plug-in: the image information of an NRG image reads past its session table

## Problem

The ISO plug-in's information about a disc image (F3 / View on the image: `CISOImage::DumpInfo` writes
the sessions, tracks and file systems into a text the viewer shows) walks the image's track table and
starts the next session whenever the track index reaches the running sum of the session counts. When
the counts add up to *fewer* tracks than the image holds (an NRG image whose SINF chunks cover only
part of its CUEX / ETNF tracks, e.g. feature 334's `multi_extra.nrg`: counts 1, 1 and three tracks), the
index reaches the sum after the last session and the code reads `Session[Session.Count]` - past the
session table (Debug: the array's range check stops the program; Release: an arbitrary number printed as
the track count and added to the running sum).

## Evidence

- `src/plugins/uniso/viewer.cpp` `CISOImage::DumpInfo` (at 2b3f0716): `for (i = 0; i < Tracks.Count; i++)
  { if (i == limit) { int trks = Session[session]; limit += Session[session]; session++; ...` - no check
  that `session < Session.Count`. Also a count of 2^31 or more (stored as a negative `int`, see feature
  340) moves `limit` backwards, so later sessions are never printed.
- Caller: `src/plugins/uniso/uniso.cpp` (the plug-in's view of an image: `image->DumpInfo(outStream)` into
  a temporary file).
- Found by reading while doing feature 340 (`specs/340-nrg-session-count/research.md` R5). Not measured.

## Expected

The information never reads past the session table: tracks that no session count covers are listed
without a session of their own (or under a line saying no session covers them), and the session counts
are read as the unsigned numbers the image stores (feature 340's `SalIsoSessionTracks` in
`src/common/salisotrack.h` gives each session's tracks within the track table).

## Notes

- Feature 340 fixed the same counts in the listing (`CISOImage::ListTracks`); the information dump was
  left out of its scope (another user action, another array).
- Not measured: an F3 on 334's `multi_extra.nrg` (or 340's `img340.py` with counts 1 and three tracks)
  should reproduce it on the Debug build.

## Log

- 2026-10-24 — created (source measure:340)
