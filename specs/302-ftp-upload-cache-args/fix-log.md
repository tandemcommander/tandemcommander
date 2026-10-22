# Fix log - 302-ftp-upload-cache-args

Backlog item `ftp-panel-mkdir-rename-skip-upload-listing-cache` - FTP: Create Directory and Quick
Rename in a panel never update the upload listing cache. Run started from `main` at 02eba55f.

## Measurement at HEAD (02eba55f), by reading

- `src/plugins/ftp/ctrlcon5.cpp`, `CControlConnectionSocket::CreateDir`: two calls
  `UploadListingCache.ReportCreateDirs(hostBuf, userBuffer, portBuf, ...)` (created / result
  unknown); `CControlConnectionSocket::QuickRename`: two calls
  `UploadListingCache.ReportRename(hostBuf, userBuffer, portBuf, ...)` (renamed / result unknown).
- Declarations (`operats.h`, `CUploadListingCache`): `(const char* user, const char* host,
  unsigned short port, ...)`. `CUploadListingCache::FindServer` (`operats9.cpp`) compares
  `server->Host` with the host argument (`StrICmp`) and `server->User` with the user argument
  (`strcmp`, anonymous = NULL). With the arguments swapped no server matches unless the user name
  equals the host name - the report is dropped.
- Every other `UploadListingCache.*` caller (Grep: `operats1/3/4/8/a/b.cpp`, `fs2.cpp`, `fs3.cpp`,
  `fs5.cpp`) passes `(user, host, port)` - only these four are swapped.
- Lifetime: the cache holds a server only while an upload operation to it exists
  (`CFTPOperationsList::DeleteOperation` -> `RemoveServer` when no upload to that server is left).
- Masking: after F7 / Quick Rename the panel posts a change notification for the changed path; the
  panel's next listing of its own folder calls `UploadListingCache.AddOrUpdateListing(..., TRUE /*
  only update */)` (`fs2.cpp`) and replaces the cached listing; an upload into the panel's folder
  seeds the cache from the panel listing (`fs5.cpp`). So for the panel's folder the stale listing
  lives only until the refresh. `CUploadListingsOnServer::ReportRename` only invalidates the panel
  folder's listing anyway - the rename case is masked entirely (expected: the item's rename row
  passes before the fix).
- Not masked: F7 with an absolute path outside the panel's folder (`/other/new` from `/src`): the
  panel refreshes only `/other/new` (CreateDir sets `changedPath` to the new path), and only
  `ReportCreateDirs` (absolute branch: `ReportCreateDir` on the cached listing of `/other` +
  an empty listing of `/other/new`) would tell the cache. An open upload operation then uploads a
  local folder `new` into `/other`: the worker reads the stale listing (`operatsa.cpp`,
  `fwssWorkStartWork`: `existingItem == NULL` -> `fwssWorkUploadCreateDir`) and sends `MKD new`
  instead of joining the existing folder (`UploadDirAlreadyExists = DIRALREADYEXISTS_JOIN` default).

## Probe

(see below)
