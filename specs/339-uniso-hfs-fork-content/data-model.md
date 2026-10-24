# Data model - 339-uniso-hfs-fork-content

## HFS+ file record (`HFSPlusCatalogFile`, TN1150, big-endian, 248 bytes)

| Offset | Field | Used |
|---|---|---|
| 0 | recordType (2 = file) | checked by the caller |
| 40 | adminFlags | no |
| 41 | ownerFlags - `UF_COMPRESSED` = 0x20 | yes |
| 42 | fileMode (2 bytes) - type bits 0xF000 | yes: 0 = BSD information not initialised |
| 88 | dataFork.logicalSize (8 bytes) | yes |
| 168 | resourceFork.logicalSize (8 bytes) | yes |

## Content kind (`SalHfsFileContentKind(rec, avail)`)

| Result | When |
|---|---|
| `SAL_HFSFILE_SHORT` (3) | `rec == NULL` or `avail < 248` (the caller refuses such records first) |
| `SAL_HFSFILE_COMPRESSED` (1) | `(fileMode & 0xF000) != 0` and `ownerFlags & 0x20` |
| `SAL_HFSFILE_RESOURCE_ONLY` (2) | otherwise, data fork size 0 and resource fork size > 0 |
| `SAL_HFSFILE_DATA` (0) | otherwise - the data fork is the content |

## Unpack result (`CHFS::UnpackFile`)

| Kind | silent | Box | Result | File |
|---|---|---|---|---|
| DATA | any | as before | as before | as before |
| COMPRESSED / RESOURCE_ONLY | 0 | Skip / Skip all / Cancel, text 1062 / 1063 | Skip: `UNPACK_ERROR`; Skip all: `UNPACK_ERROR`, silent = 1; Cancel: `UNPACK_CANCEL` | not created |
| COMPRESSED / RESOURCE_ONLY | != 0 | none | `UNPACK_ERROR` | not created |
