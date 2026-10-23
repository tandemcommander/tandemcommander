# Data model - 323-ftp-upload-cache-args

No new data. The existing in-memory structure involved:

- **CUploadListingCache** (`operats.h`, global `UploadListingCache`): list of
  `CUploadListingsOnServer`, looked up by `FindServer(user, host, port)` - host compared without
  case, user exactly (anonymous stored as NULL), port equal.
- **CUploadListingsOnServer**: `User`, `Host`, `Port` and the cached listings
  (`CUploadPathListing`: path, state `ulsReady` / `ulsInProgress` / `ulsInProgressButObsolete` /
  `ulsInProgressButMayBeOutdated` / `ulsNotAccessible`, items).
- Lifetime: a server entry is created when an upload needs a listing (or seeds one from the
  panel) and removed when the last upload operation to that server is deleted.

## Per-component decision of a reported Create Directory (FR-005)

For each named component (not `.`, `..` or empty) of the typed path, at the cached listing of its
parent (if any):

| Result of the command | Component | Parent listing shows it | Action |
|---|---|---|---|
| unknown | any | any | invalidate the parent listing (unchanged) |
| created | the last named one | any | as before: `ReportCreateDir` on the parent listing; when it was added, an empty, ready listing of the new folder |
| created | an earlier one | yes (ready / newer listing holds the name) | nothing |
| created | an earlier one | no, or cannot tell (listing in progress or outdated) | invalidate the parent listing; no empty listing |

State transitions of `InvalidateListing` are unchanged: a ready listing is dropped (the next
upload lists the folder again); a listing in progress is marked "may be outdated".
