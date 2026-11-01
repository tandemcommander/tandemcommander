# Data model - 365

- **Track record** (`CISOImage::Track`, unchanged type): `SectorSize` (stored bytes a sector), `SectorHeaderSize`
  (bytes before the user data, `GetHeaderSizeFromMode`), `Mode`, `FSType`, `Start` / `End` (bytes in the
  image), `ExtentOffset` (first disc sector).
- **ETN entry** (`SalNrgEtnEntry`): `Start`, `Length` (bytes, 64-bit), `Mode` (byte), `Sector` (32-bit).
  ETNF: 20 bytes, start / length 32-bit @0 / @4, mode @11, sector @12. ETN2: 32 bytes, start / length
  64-bit @0 / @8, mode @19, sector @20. Big-endian.
- **CloneCD TOC entry** (`SalIsoCcdTocEntry`): `Session` (1..sections, checked by 352), `Point`, `Adr`,
  `Plba` (signed).
- **CloneCD track layout** (`SalIsoCcdTocTrack`): `Session`, `Extent` (= PLBA), `FirstSector` (index of
  its first 2352-byte sector in the `.img`), `Sectors`.
- **Layout result**: `SAL_ISO_CCD_TOC_NONE` (the INDEX 1 split of 41f18c08), `SAL_ISO_CCD_TOC_OK`,
  `SAL_ISO_CCD_TOC_INCONSISTENT` (followed; a negative count set to 0 - the listing is marked).
