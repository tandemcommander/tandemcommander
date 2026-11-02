# Data model - 401-uniso-share-length

## Folder visit key

| Field | Source | Notes |
|-------|--------|-------|
| start | `LocationOfExtent - ExtentOffset + ExtendedAttributeRecordLength` (32 bits) | the block the walk reads |
| length | the record's `DataLength` (32 bits) | the bytes the walk reads |
| key | `((unsigned long long)length << 32) | start` | `SalIsoFolderVisitKey` |

## Visited sets of one ISO 9660 listing (`CISO9660::ListDirectory`)

- fit-check walk: its own set (`fitVisited`), discarded after the walk;
- listing walk: `visited`;
- count walks (328 decision mode) inside either: add to the current set, log their keys
  (`VisitedLog`), and remove exactly those keys afterwards.

State: a key absent → the folder is walked and the key inserted; present → listed empty (328's rule).
