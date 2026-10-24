# Data model - 334-uniso-session-missing

## Track (`CISOImage::Track`, plug-in internal)

| Field | Meaning | New |
|---|---|---|
| `FSType` | `fsUnknown` (track table type not known), `fsAudio`, `fsData` (no file system found), or a file-system type | - |
| `OutsideImage` | set by `Open` for an `fsData` track whose sector 16 is not within the image file | yes (default FALSE) |

## Rule `SalIsoTrackMarksListing(kind, outsideImage, outcome)` (`src/common/salisotrack.h`)

Inputs:

- kind: `SAL_ISO_TRACK_DATA` / `SAL_ISO_TRACK_AUDIO` / `SAL_ISO_TRACK_UNKNOWN`
- outsideImage: the data track's sector 16 is not in the image (`SalIsoTrackSectorOutside`: also a
  negative or overflowed offset)
- outcome: `SAL_ISO_TRACK_NOT_TRIED` / `SAL_ISO_TRACK_NOT_OPENED` / `SAL_ISO_TRACK_LIST_FAILED` /
  `SAL_ISO_TRACK_LISTED` / `SAL_ISO_TRACK_LEFT_OUT` (no session count covers the track)

Result (true = mark 328's `ListingLeftOut` incomplete), revised after review 1:

| kind | outsideImage | outcome | marks |
|---|---|---|---|
| audio, unknown, or a kind the rule does not know | any | any | yes (audio is never extracted, unknown never listed) |
| data | true | any | yes |
| data | false | not opened, listing failed, left out, or an outcome the rule does not know | yes |
| data | false | not tried, listed | no |
