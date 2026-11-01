# Data model - 367-uniso-form2-unmarked

## CISOImage::CFilePos (plug-in's own per-file data, not ABI)

| Field | Before | Now |
|---|---|---|
| `Form2` (BYTE) | 0 / 1 (366) | 0 = 2048 a sector; 1 = 2324 a sector (366's files and examined all-Form-2 files); 2 = per sector (mixed) |
| `Scanned` (BYTE) | - | the file was examined (`ExamineFileSectors`): its coverage span is `WholeSectors` |
| `WholeSectors` (DWORD) | - | the leading run of sectors the reader reads whole (record lengths are 32-bit: at most 2^21 sectors) |

## SalIsoSectorScan (salisotrack.h)

| Field | Meaning |
|---|---|
| `Sectors` | ceil(record length / 2048) |
| `Seen` | sectors added so far |
| `Form2` | Form 2 sectors among them |
| `Whole` | the leading run of sectors read whole |
| `Stopped` | the run ended (an unknown sector, or a last non-Form-2 sector the record ends inside) |
| `LastForm` | form of the last added sector |
| `LastLen` | the record's bytes in the last sector (1..2048) |

Kind: `Form2 == 0` none; `Form2 == Sectors` all; else mixed. Size: none = record length; all = Sectors x 2324;
mixed = Form2 x 2324 + (Sectors - Form2 - 1) x 2048 + (last Form 2 ? 2048 : LastLen) - written so that it equals
both other cases.

## Sector form

`SAL_ISO_SECTOR_UNKNOWN` 0, `SAL_ISO_SECTOR_FORM1` 1, `SAL_ISO_SECTOR_FORM2` 2.
