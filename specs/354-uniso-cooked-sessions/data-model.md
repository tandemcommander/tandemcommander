# Data model - 354-uniso-cooked-sessions

No stored data. The rule's inputs and outputs (`src/common/salisotrack.h`):

| Name | Meaning |
|---|---|
| `iso9660` | sector 16 of the cooked layout holds an ISO 9660 primary descriptor header (type 1, `CD001`) |
| `volumeKnown`, `volumeSectors` | `SalIsoPvdVolumeSectors` (353) read the volume size from that descriptor |
| `fileSize` | the image's size in bytes (`track->End` of the plain branch) |
| `SAL_ISO_LATER_VOLUME_SECTOR` (353) | 16 - a rest of at most this many whole sectors holds no later volume |
| `SAL_ISO_ZERO_REST_SECTORS` | 512 - the most sectors of the rest that are read |

`SalIsoCookedRestDecision(iso9660, volumeKnown, volumeSectors, fileSize, checkFrom, checkBytes)`
returns one of:

| Result | When | Open does |
|---|---|---|
| `SAL_ISO_REST_KEEP_LISTING` | not `iso9660`; or at most 16 whole sectors past the volume | nothing |
| `SAL_ISO_REST_MARK` | not `volumeKnown`; `fileSize` negative; fewer whole sectors than the volume; the rest longer than 512 sectors | marks `ListingLeftOut` incomplete |
| `SAL_ISO_REST_CHECK` | otherwise: `checkFrom` = the volume's end in bytes, `checkBytes` = the bytes from there to the end of the file | reads them; marks unless all were read and `SalIsoBytesAllZero` |
