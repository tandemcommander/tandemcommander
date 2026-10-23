# Data model - 302-ftp-upload-cache-args

No new data. The existing in-memory structure involved:

- **CUploadListingCache** (`operats.h`, global `UploadListingCache`): list of
  `CUploadListingsOnServer`, looked up by `FindServer(user, host, port)` - host compared without
  case, user exactly (anonymous stored as NULL), port equal.
- **CUploadListingsOnServer**: `User`, `Host`, `Port` and the cached listings
  (`CUploadPathListing`: path, state `ulsReady` / `ulsInProgress` / ... , items).
- Lifetime: a server entry is created when an upload needs a listing (or seeds one from the
  panel) and removed when the last upload operation to that server is deleted.

Change of this feature: the panel's Create Directory and Quick Rename identify the server entry
correctly; the reactions (`ReportCreateDir` on the listing, `AddEmptyListing`, `InvalidateListing`)
are unchanged.
