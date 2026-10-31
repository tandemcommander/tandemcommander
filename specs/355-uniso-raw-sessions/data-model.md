# Data model - 355-uniso-raw-sessions

## SalIsoRawRestDecision (src/common/salisotrack.h)

Inputs:

| Name | Meaning |
|---|---|
| `volumeKnown`, `volumeSectors` | `SalIsoPvdVolumeSectors` of the 132 bytes at the opened layout's sector 16 |
| `fileSize` | the file's bytes |
| `dataOffset` | the layout's offset of sector 0 |
| `sectorRawSize` | the stored size of one sector |

Outputs: `SAL_ISO_REST_KEEP_LISTING`, `SAL_ISO_REST_MARK`, `SAL_ISO_REST_CHECK`; for CHECK only
`firstSector` (= `volumeSectors`) and `sectors` (whole sectors past the volume, 17..512).

| Condition (in order) | Result |
|---|---|
| `!volumeKnown`, `sectorRawSize <= 0`, `fileSize < 0` or `dataOffset < 0` | MARK |
| whole sectors `(fileSize - dataOffset) / sectorRawSize` (0 when `fileSize <= dataOffset`) < `volumeSectors` | MARK |
| whole - `volumeSectors` <= 16 (`SAL_ISO_LATER_VOLUME_SECTOR`) | KEEP_LISTING |
| whole - `volumeSectors` > 512 (`SAL_ISO_ZERO_REST_SECTORS`) | MARK |
| otherwise | CHECK |

CHECK in the plug-in: for each sector `n` in `[firstSector, firstSector + sectors)`, read 2048 bytes at
`dataOffset + n * sectorRawSize + SectorHeaderSize`; any short read or non-zero byte marks.
