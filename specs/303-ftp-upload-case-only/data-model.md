# Data model - 303-ftp-upload-case-only

No stored data changes. In memory:

- **CUploadPathListing** (existing): the items of one server folder, sorted by the path type's rule
  (`strcmp` for Unix, `StrICmp` otherwise); `FindItem` = binary search by that rule (unchanged).
- **CUploadListingItem** (existing): `ItemType` (file / directory / link), `Name`, `ByteSize`
  (`UPLOADSIZE_UNKNOWN`, `UPLOADSIZE_NEEDUPDATE` or the size).
- **The copy GetListing returns** (`existingItem`): as before for an exact match; for a case-only
  match: the listed item's `Name` and `ItemType`, `ByteSize = UPLOADSIZE_UNKNOWN`; `nameExists` =
  TRUE in both cases.
- **caseOnlyCounts** (new argument of both `GetListing` functions): TRUE = a case-only match counts
  (file upload start, resume size, file auto-rename); FALSE = exact only (folder upload, folder
  auto-rename).
