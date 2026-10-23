# Research - 302-ftp-upload-cache-args

## R1 - Which calls are swapped

- Decision: exactly four - `ctrlcon5.cpp` `CreateDir` (created, result unknown) and `QuickRename`
  (renamed, result unknown).
- Rationale: Grep of `UploadListingCache\.` over `src/plugins/ftp`: every other call
  (`ReportDelete`, `ReportCreateDirs`, `ReportStoreFile`, `ReportFileUploaded`,
  `ReportUnknownChange`, `GetListing`, `ListingFailed`, `ListingFinished`, `AddOrUpdateListing`,
  `InvalidatePathListing`, `IsListingFromPanel`, `RemoveServer`, `RemoveNotAccessibleListings` in
  `operats1/3/4/8/a/b.cpp`, `fs2.cpp`, `fs3.cpp`, `fs5.cpp`) passes `(user, host, port)` -
  through `Oper->GetUserHostPort(userBuf, hostBuf, &port)` or the FS's `User, Host, Port`.
  `QuickRename` also calls `FTPOpenedFiles.OpenFile(userBuffer, hostBuf, portBuf, ...)` in the
  right order (declared `(user, host, port, ...)`).
- Alternatives: a server-key struct to make a swap a compile error - rejected (clarification:
  touches 30+ callers for no behaviour change).

## R2 - When the stale cache is visible

- Decision: probe the absolute-path Create Directory case; keep the rename row as a regression.
- Rationale: the panel's refresh of its own folder replaces the cached listing
  (`fs2.cpp`, `AddOrUpdateListing(..., onlyUpdate = TRUE)` when the listing is fresh and whole), and
  an upload into the panel's folder re-seeds the cache from the panel (`fs5.cpp`); `ReportRename`
  only invalidates the panel folder anyway. A Create Directory of `/other/new` from a panel at
  `/src` posts a change of `/other/new` only (`changedPath = newPath` when it is not under the
  working path), so nothing but `ReportCreateDirs` tells the cached listing of `/other`.
- The cache exists only while an upload operation to the server exists. The probe keeps the first
  upload open with an overwrite question (default `UploadFileAlreadyExists = USERPROMPT`, the
  Solve Error dialog stays open, the operation dialog too).
- Observable: second upload of a local folder `new` into `/other`; with the stale listing the
  worker goes to `fwssWorkUploadCreateDir` and sends `MKD new`; with the corrected report it finds
  a directory -> `fwssWorkUploadDirExists` -> default `DIRALREADYEXISTS_JOIN` (no `MKD`).

## R3 - Test server

- Decision: 215's `ftpmini.py` (127.0.0.1 only, logs every command as JSON lines), UTF-8 mode,
  user `u` / password `p` (user name different from the host `127.0.0.1`, so the swap fails).
