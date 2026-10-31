# Data model - 352

- **CCD** (reader-internal, `img.cpp`): `TrackArray`, `EntryArray`, `SessionArray`,
  `DisplayMissingCCDWarning`, **new** `Refused` (the `.ccd` exists and was refused with
  `IDS_CCD_BAD_FORMAT`; false for a missing `.ccd`).
- **CCDEntry**: `Session` **int** (was `BYTE`), `Point`, `PLBA`, `ADR`. Valid when
  `SalIsoCcdSessionIndex(Session, SessionArray.Count) >= 0`.
- **CCDTrack**: `Mode`, `Index` - both from rows that parsed once.
- **CCDSession**: `PreGapMode`, `PreGapSubC` - both from rows that parsed once.
- **Split list** (`CISOImage::Session`): one track count per run of tracks starting at `INDEX 1 = 0`.
  Split `i` takes its extents from table row `SalIsoCcdSplitSection(i, SessionArray.Count)` (none ->
  0). `SalIsoCcdLayoutTrusted(SessionArray.Count, Session.Count)` false -> `ListingLeftOut` incomplete.
- **CSalIsoCcdFields** (rule): `Seen` bit set, `Bad` (a row repeated or not parsed);
  `Complete(required)` = not bad and all required bits seen.
