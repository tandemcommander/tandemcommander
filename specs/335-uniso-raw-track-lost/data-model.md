# Data model - 335-uniso-raw-track-lost

## CISOImage::Track (src/plugins/uniso/isoimage.h)

- `RawLost` (BOOL, was feature 334's `OutsideImage`; FALSE by default): set in `CISOImage::Open` for a
  track-table data track in which no file system was found (`fsData`) when its sector 16 is outside the
  image file (334) or is not a Mode 2 Form 2 sector (335). Read by `MarkTrack`.

## Rule inputs (src/common/salisotrack.h)

- `SalIsoSectorIsForm2(raw, len, sectorRawSize)`: `raw` = the first `len` bytes of the stored sector;
  `sectorRawSize` = bytes a sector as stored (>= 2352 raw, 2336 Mode 2 without sync / header, other =
  user data only). True only when the stored header says Mode 2 Form 2 (2352+: sync, mode byte 2,
  submode bit 0x20 at 18 and 22; 2336: submode bit 0x20 at 2 and 6).
- `SalIsoTrackMarksListing(kind, rawLost, outcome)`: unchanged logic (334); the parameter is the track's
  `RawLost`.

## States

fsData track -> RawLost = outside || !Form2 -> marked in every listing path; Form 2 stream inside the
image -> RawLost FALSE -> 334's rule (not marked when listed or not tried).
