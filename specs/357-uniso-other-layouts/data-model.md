# Data model - 357-uniso-other-layouts

## SalIsoPlainLayout (enum, `src/common/salisotrack.h`)

The check of `CISOImage::Open`'s plain branch that opened the file, in the order of the chain:

| Value | Check | Covered by 355's rule without a raw start |
|---|---|---|
| `SAL_ISO_PLAIN_NONE` | none opened the file | no |
| `SAL_ISO_PLAIN_ISO` | `CheckForISO` (cooked from offset 0 without raw start: 354) | no |
| `SAL_ISO_PLAIN_NRG` | `CheckForNRG` | yes |
| `SAL_ISO_PLAIN_2336` | `CheckFor2336` | yes |
| `SAL_ISO_PLAIN_NCD` | `CheckForNCD` | yes |
| `SAL_ISO_PLAIN_PDI` | `CheckForPDI` | yes |
| `SAL_ISO_PLAIN_ECDC` | `CheckForECDC` | yes |
| `SAL_ISO_PLAIN_CIF` | `CheckForCIF` | yes |
| `SAL_ISO_PLAIN_C2D` | `CheckForC2D` (WinOnCD, Mode 2, Roxio) | yes |
| `SAL_ISO_PLAIN_CIF2332` | `CheckForCIF2332` | yes |
| `SAL_ISO_PLAIN_XBOX` | `CheckForXbox` | no |
| `SAL_ISO_PLAIN_MDF` | `CheckForMDF` (needs the sync: always a raw start) | no |
| `SAL_ISO_PLAIN_HFS` | `CheckForHFS` | no |
| `SAL_ISO_PLAIN_APFS` | `CheckForAPFS` | no |

## SalIsoPlainRawRuleApplies(rawStart, ccdMissing, layout) -> bool

- `rawStart && !ccdMissing` -> true (355, any layout - unchanged);
- `rawStart && ccdMissing` -> false (353's block);
- `!rawStart` -> true for the eight covered layouts above, false otherwise (an unknown value: false).
