# Data model - feature 306

## SalPaxValues (src/common/salpaxheader.h)

| Field | Meaning |
|---|---|
| `PathState`, `Path` | UNSET / DELETED / SET; `Path` malloc'd, NUL-terminated raw bytes of the value |
| `SizeState`, `Size` | UNSET / DELETED / SET; unsigned 64-bit, at most 2^63-1 |
| `MTimeState`, `MTimeSec`, `MTimeFrac` | UNSET / DELETED / SET; seconds since 1970 (floor, signed), 100-ns fraction 0..9999999 |

Two instances: the global one (`CArchive::GlobalPax`, whole pass) and the member one (one
`ReadTarHeader` call). Effective value = member SET → member; member DELETED → none; else
global SET → global; else none.

## SCommonHeader additions (src/plugins/tar/tar.h)

| Field | Meaning |
|---|---|
| `MTimeFrac` | 100-ns part added after the seconds are converted to a FILETIME; 0 for every non-PAX member |
| `NameFromPax` | the name came from a PAX `path` (the FR-006 check applies only then) |

## CArchive additions

| Field | Meaning |
|---|---|
| `GlobalPax` | values of the `g` headers read so far in this pass |
| `ReportRefusedNames` | TRUE in `ListArchive` and `UnpackWholeArchive` |
| `RefusedNameShown` | the FR-006 message was shown in this object's life |
