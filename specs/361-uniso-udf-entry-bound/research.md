# Research - 361-uniso-udf-entry-bound

## R1 - Callers of the general reader (enumerated with Grep, fix protocol)

`ReadFileEntry(Uint8*, bool, Uint16, CICBTag*, CAD*, int)` is called from:

| Caller | maxAds | Reached by | Today on failure |
|---|---|---|---|
| `CUDF::ReadPartitionMap` (type 2, "*UDF Metadata Partition") | 32 | `CUDF::Open` (Enter, Alt+F9, F3) on a UDF 2.50 volume | `nMetadataICBs` = the count; 0 = no translation |
| `CUDF::MapICB(CAD, CICBTag*, CAD*)` | 1 | `ListDirectory` (root), `ScanDir` (every sub-folder) | 0 → "Bad root ICB" / listed empty + `ListingLeftOut.SetIncomplete()` (330) |
| `CUDF::UnpackFile` | 32 | Unpack / Copy of a file | `IDS_UDF_ICB_AND_FILESIZE_MISMATCH` + `UNPACK_ERROR` when the descriptors do not cover the size |

The listing reads files through the other reader `ReadFileEntry(BYTE*, bool, CFileEntry*)` (size, time; no
descriptor walk) - a damaged file entry is reached by Unpack only.

- Decision: refusal value `UDF_FE_REFUSED` (-2); -1 keeps meaning "embedded data" for the callers that test
  `-1 ==`. MapICB returns 0, UnpackFile shows the mismatch box, the metadata map stores 0.
- Rationale: each caller already has a path for an unreadable entry; no new message (spec Clarifications).
- Alternatives: return 0 descriptors (an empty folder / file - a whole unpack would succeed and could delete the
  image); a new message (a UI string and translations for a damaged-image case).

## R2 - Shared rules

- Decision: a new header `src/common/salisoudfentry.h` with `SalIsoUdfEntryDescs`, built on 360's
  `SalIsoUdfVatDescArea` (area in the sector, 64-bit, no wrap) and `SalIsoUdfVatDescSize` (8 / 16 / 20 / 0 / -1);
  a whole number of descriptors replaces the per-step `DescFits` (equivalent for a fixed size).
- Rationale: the item asks for the rules shared with 360 ("reused or generalised"); 360's names and tests stay.
- Alternatives: renaming 360's functions to general names (churn in 360's tests and reader for no behaviour).

## R3 - Embedded data

The embedded case (type 3) sets `ad->Offset = area start`, `ad->Length = L_AD`; `UnpackFile` writes
`sector + Offset` for up to `Length` bytes (one 2048-byte buffer) and `ScanDir` reads the directory at
`directory + Offset` (two sectors). With the area inside the sector, `Offset + Length <= 2048` - both stay in
their buffers. An empty embedded area (L_AD 0) keeps today's result (no descriptor, the terminating entry).

## R4 - Probe images

- mk_cdr.img (mkudffs `--media-type=cdr`, 356's `mkudf356.sh`) with the root folder's entry type 5 (360 review's
  `rootadt5`) - the measured hang.
- ud.iso (genisoimage `-udf`, 330's `mkimg330.sh`: `a/side.txt`, `top.txt`, `zlast/z.txt`; ISO 9660 + UDF) with:
  folder `a`'s entry type 5; folder `a`'s L_EA 0x10000000 (the 32-bit area start 256 MB past the stack sector -
  an access violation before); file `top.txt`'s entry type 5 (Unpack only). The reader checks no descriptor CRC.
- Controls: mk_cdr.img and ud.iso unchanged.
