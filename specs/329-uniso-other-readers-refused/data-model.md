# Data model - feature 329

## Left-out entry (328, unchanged)

`CSalListingLeftOut` (`src/common/salisonamefit.h`), one per `CISOImage` (`ListingLeftOut`), filled by
every reader of the image during `ListImage`:

- `Count` - entries the listing refused; `Incomplete` - something is missing (also out of memory);
  `Paths` - the first 10 in-image paths (leading `\` dropped; for a hybrid with the file system's
  folder, e.g. `UDF (TC329)\a...\e...`).
- Read by `ListArchive` (the report box when `Count > 0`; `CPluginDataInterface::ListingLeftOut`
  when `Incomplete`) and by `UnpackWholeArchive` (fails when set).

## Left-out folder IDs (new)

`CSalLeftOutIds` (`src/common/salisonamefit.h`), local to one `CHFS::ListDirectory` call:

- `Add(id)` -> bool (false = out of memory), `Has(id)` -> bool; IDs are 32-bit catalog node IDs.
- An HFS+ record is skipped when `Has(parentID)`; a skipped or refused folder's `folderID` is added.
