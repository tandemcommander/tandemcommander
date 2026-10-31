# Data model - 353-uniso-noccd-sessions

## Rule inputs (`src/common/salisotrack.h`)

| Name | Meaning |
|---|---|
| `raw` | the `.ccd` could not be opened and sector 0 of the file has the CD sync pattern |
| descriptor bytes | the first 132 bytes at sector 16 (fewer = not readable) of the opened layout |
| `volumeSectors` | volume space size of the primary volume descriptor (type 1, `CD001`, version 1, both copies equal, logical block size 2048) |
| `fileSize`, `dataOffset`, `sectorRawSize` | the file's length, the layout's data offset and stored sector size |

## Functions

- `SalIsoPvdVolumeSectors(desc, len, &sectors)` -> true and the size when the descriptor is a valid
  primary volume descriptor as above; false otherwise (`sectors` untouched).
- `SalIsoNoCcdRestMarks(raw, volumeKnown, volumeSectors, fileSize, dataOffset, sectorRawSize)`:
  - not `raw` -> false (unchanged behaviour);
  - not `volumeKnown`, or `sectorRawSize` <= 0 -> true (fails closed);
  - whole sectors = (fileSize - dataOffset) / sectorRawSize (0 when fileSize <= dataOffset);
  - true when whole sectors > volumeSectors + `SAL_ISO_LATER_VOLUME_SECTOR` (16), or whole sectors <
    volumeSectors (review 1: a size claiming more than the file holds is not trusted).

## State

- `CISOImage::CcdMissing` (BOOL): FALSE at each `ReadSessionInfo`; TRUE when `processCCDFile` could not
  open the `.ccd`. Read only by `Open`'s plain branch.
- `CISOImage::ListingLeftOut.Incomplete`: set when the rule returns true.
