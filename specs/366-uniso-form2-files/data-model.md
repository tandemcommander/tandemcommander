# Data model - 366-uniso-form2-files

## CD-XA system-use record (read only, from the image)

| Offset | Size | Field |
|---|---|---|
| 0 | 2 | owner group id |
| 2 | 2 | owner user id |
| 4 | 2 | attributes, big-endian: 0x0800 Form 1, 0x1000 Form 2, 0x2000 interleaved, 0x4000 CD-DA, 0x8000 directory (low bits: permissions) |
| 6 | 2 | signature "XA" |
| 8 | 1 | file number |
| 9 | 5 | reserved |

Located at the start of the record's system-use area: record offset 33 + identifier length, + 1 when the
identifier length is even. Present only when the record holds at least 14 bytes there.

## `CISOImage::CFilePos` (plug-in internal)

- new `BYTE Form2` - TRUE for a Form 2 file (spec FR-001); default FALSE (every constructor of the plug-in's
  readers: ISO 9660, UDF, HFS+, the boot image).

## Rules (`src/common/salisotrack.h`)

- `SalIsoXaAttributes(rec, recLen, idLen, &attrs)` - the XA record of a raw directory record; false when absent.
- `SalIsoXaIsForm2File(attrs)` - Form 2 bit set, Form 1 and directory bits clear.
- `SalIsoTrackStoresForm2(sectorRawSize, sectorHeaderSize)` - `SalIsoForm2PayloadOffset(raw) >= 0` and equal to
  the header size.
- `SalIsoForm2FileSize(dataLength)` - ceil(dataLength / 2048) x 2324.
- `SalIsoFileSectorSpan(..., bytesPerSector)` - floor(size / bytesPerSector) whole sectors.
