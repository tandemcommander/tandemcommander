# Data model - 330-iso-unreadable-folder

## Listing incomplete mark (existing, feature 328)

- `CISOImage::ListingLeftOut` (`CSalListingLeftOut`, `src/common/salisonamefit.h`): `Count` (entries
  the panel listing refused, named in the report), `Incomplete` (something is missing).
- `ListArchive`: `Incomplete` -> `CPluginDataInterface::ListingLeftOut = TRUE`; the "(206)" report only
  when `Count > 0`.
- `UnpackWholeArchive`: `ListingLeftOut` -> the unpack returns FALSE -> the core does not delete the
  image.

## New transitions

| Event | Before | After |
|---|---|---|
| ISO 9660 walk result != `ERR_OK` (read error, record check, zero extent, out of memory) | unmarked | `SetIncomplete()` |
| UDF / Xbox "Error reading directory structure" | unmarked | `SetIncomplete()` |
| A directory met again (cycle) | unmarked | unmarked |
| UDF entry skipped as damaged | unmarked | unmarked (other Inbox item) |

`Count` is unchanged by a read error, so no "(206)" report appears for it; the existing error box is
the report.
