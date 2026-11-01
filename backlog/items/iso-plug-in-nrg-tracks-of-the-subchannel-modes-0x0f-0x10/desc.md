---
title: ISO plug-in: NRG tracks of the subchannel modes 0x0F / 0x10 / 0x11 get a wrong type or size
type: bug
status: new
severity: 3
area: archives
source: leftover:365
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: NRG tracks of the subchannel modes 0x0F / 0x10 / 0x11 get a wrong type or size

## Problem

Nero's mode bytes 0x0F (Mode 1 + subchannel), 0x10 (audio + subchannel) and 0x11 (Mode 2 + subchannel)
are read wrongly by the ISO plug-in's NRG readers: `SetTrackTypeMode` types 0x0F as Mode 2 (bit 1), and
0x10 / 0x11 as unknown (never opened; the listing is marked, 334); in an ETNF / ETN2 track-at-once table
their stored sector size stays the old guess (ETNF: 0x0F / 0x11 -> 2336, 0x10 -> 2048; ETN2: 2048) - feature
365 left them so because the file layout of their 96 subchannel bytes in a track-at-once image is not
known. A data track of such a mode is not listed (the image is kept by 334 / 335's marks, so nothing is
deleted).

## Evidence

- Branch `365-nrg-ccd-track-tables` (feature 365): `src/plugins/uniso/nrg.cpp` `SetTrackTypeMode` (0x0F ->
  `type & 0x02` -> Mode 2; 0x10 / 0x11 -> `fsUnknown`), `src/common/salnrgcdtext.h` `SalNrgEtnSectorSize`
  (`SalNrgModeVerified` false for 0x0F / 0x10 / 0x11).
- libmirage `mirage_parser_nrg_decode_mode` (feature 365 fix-log, *Research*): 0x0F Mode 1 2352 + 96,
  0x10 audio 2352 + 96, 0x11 Mode 2 2352 + 96; its track-at-once loader divides the entry size by 2352 and
  sets no subchannel offset, so it does not show how such data is stored in the file.
- Not measured: no image with these modes was made; DAO (DAOX) tracks of these modes take their sector
  size from the DAOX entry (2448 expected) and are typed by the same `SetTrackTypeMode`.

## Expected

Mode bytes 0x0F / 0x10 / 0x11 are typed Mode 1 / audio / Mode 2 and, once a real Nero image shows the
layout, sized 2448 bytes a sector (2352 + 96) in ETNF / ETN2 tables; measured with a crafted image
before and after.

## Notes

- Needs a real Nero track-at-once image burnt with subchannel data to confirm the layout (not verified);
  until then the change of type alone (0x0F as Mode 1) is safe: the header size for 2448-byte sectors is
  16 for both modes.

## Log

- 2026-11-01 — created (source leftover:365)
