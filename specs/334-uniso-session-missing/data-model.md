# Data model - 334-uniso-session-missing

## Track (`CISOImage::Track`, plug-in internal)

| Field | Meaning | New |
|---|---|---|
| `FSType` | `fsUnknown` (track table type not known), `fsAudio`, `fsData` (no file system found), or a file-system type | - |
| `OutsideImage` | set by `Open` for an `fsData` track whose sector 16 is not within the image file | yes (default FALSE) |

## Rule `SalIsoTrackMarksListing(kind, outsideImage, outcome)` (`src/common/salisotrack.h`)

Inputs:

- kind: `SAL_ISO_TRACK_DATA` / `SAL_ISO_TRACK_AUDIO` / `SAL_ISO_TRACK_UNKNOWN`
- outsideImage: the data track's sector 16 is not in the image
- outcome: `SAL_ISO_TRACK_NOT_TRIED` / `SAL_ISO_TRACK_NOT_OPENED` / `SAL_ISO_TRACK_LIST_FAILED` /
  `SAL_ISO_TRACK_LISTED`

Result (true = mark 328's `ListingLeftOut` incomplete):

| kind | outsideImage | outcome | marks |
|---|---|---|---|
| unknown | any | any | no |
| data | true | any | yes |
| data / audio | false (audio: ignored) | not opened, listing failed | yes |
| data / audio | false | not tried, listed | no |
| any other outcome value | - | - | yes (fail closed) |
