# Data model - 351

## CISOImage::Track (uniso internal)

| Field | Default from 351 | Set by |
|---|---|---|
| `SectorSize` | 0 | CCD loop (2048, then 0x930), DAOX, ETNF, ETN2, no-table path |
| `SectorHeaderSize` | 0 | CCD loop, DAOX, ETNF, ETN2, no-table path |
| `Mode` | `mNone` | CCD loop (by `SalIsoCcdTrackKind` + CCD mode), `SetTrackTypeMode`, ETN2, no-table path |
| `Start`, `End` | 0 | CCD loop, DAOX, ETNF, ETN2, no-table path |
| `ExtentOffset` | 0 | CCD loop, CUEX, ETNF, ETN2, no-table path |
| `FSType` | `fsUnknown` | CCD loop (audio -> `fsAudio`, data -> `fsISO9660`), `SetTrackTypeMode`, ETN2, `DetectTrackFS`, `Open` |
| `Bootable` | FALSE (unchanged) | - |
| `FileSystem` | NULL (unchanged) | `OpenTrack` |
| `RawLost`, `Form2Stream` | FALSE (unchanged) | `Open` (335 / 336) |

## SalIsoCcdTrackKind(int ccdMode) -> int (salisotrack.h)

| `MODE=` | Result |
|---|---|
| 0 | `SAL_ISO_TRACK_AUDIO` |
| 1, 2 | `SAL_ISO_TRACK_DATA` |
| anything else (negative, 3, ...) | `SAL_ISO_TRACK_UNKNOWN` |
