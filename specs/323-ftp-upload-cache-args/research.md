# Research - 323-ftp-upload-cache-args

R1-R3 are the stopped run's findings (feature 302), still valid at 4c33e2fc (`ctrlcon5.cpp` is
unchanged since 02eba55f; `main` changed `operats9.cpp` / `operats.h` only in `GetListing`,
feature 303). R4 is new.

## R1 - Which calls are swapped

- Decision: exactly four - `ctrlcon5.cpp` `CreateDir` (created, result unknown) and `QuickRename`
  (renamed, result unknown).
- Rationale: Grep of `UploadListingCache\.` over `src/plugins/ftp`: every other call
  (`ReportDelete`, `ReportCreateDirs`, `ReportStoreFile`, `ReportFileUploaded`,
  `ReportUnknownChange`, `GetListing`, `ListingFailed`, `ListingFinished`, `AddOrUpdateListing`,
  `InvalidatePathListing`, `IsListingFromPanel`, `RemoveServer`, `RemoveNotAccessibleListings` in
  `operats1/3/4/8/a/b.cpp`, `fs2.cpp`, `fs3.cpp`, `fs5.cpp`) passes `(user, host, port)` -
  through `Oper->GetUserHostPort(userBuf, hostBuf, &port)` or the FS's `User, Host, Port`.
- Alternatives: a server-key struct to make a swap a compile error - rejected (clarification:
  touches 30+ callers for no behaviour change).

## R2 - When the stale cache is visible

- Decision: probe rows MKD-ABS (F7 with an absolute path outside the panel folder) and REN-UP
  (the item's rename row), both with an upload operation kept open by an overwrite question.
- Rationale (corrected by 302's probe): reading suggested the panel's refresh masks the panel
  folder's case; the probe showed the panel's `LIST` reaches the server after the upload's `STOR`,
  and an upload into the panel's folder does not take the panel's listing while another operation
  can change that folder - REN-UP replaced `b.txt` without the question on the old code.
- The cache exists only while an upload operation to the server exists.

## R3 - Test server

- Decision: 215's `ftpmini.py` (127.0.0.1 only, logs every command as JSON lines), UTF-8 mode,
  user `u` / password `p` (user name different from the host `127.0.0.1`, so the swap fails).
  For R4's rows 302 review 2's `ftpmini_hide.py`: a plain `LIST` omits dot names, and path
  components resolve without case (as vsftpd / Pure-FTPd / ProFTPD hide dot files, and a
  case-insensitive file system answers `docs` for `Docs`).

## R4 - Which components of a created path the cache may record (302 review 2 MUST)

- Finding: `CUploadListingsOnServer::ReportCreateDirs` (`operats9.cpp`) calls
  `CUploadPathListing::ReportCreateDir` for every component whose parent listing is cached; that
  inserts the name when the listing lacks it and reports `dirCreated`, after which an empty, ready
  listing of the folder is added (`AddEmptyListing(..., ulsReady)`). For `MKD .cfg/new` the server
  succeeds only because `.cfg` exists - a missing earlier component means the listing is
  incomplete, not that the folder was made. Measured by 302 review 2: upload of `f.txt` into
  `.cfg/` (or `docs/` beside `Docs`) sent `STOR` without `LIST` and without the question.
  Unreachable before the argument fix (the report was dropped) - a regression the fix would bring.
- Decision: per named component (not `.`, `..`, empty): the last one keeps the existing handling
  (it was created by the successful command: new and empty); an earlier one is never given an
  empty listing - when its parent listing is ready (or holds a newer listing) and contains the
  name, nothing happens; otherwise the parent listing is invalidated. Applies to the relative
  branch (walks top-down: the last named component is found by a pre-scan of a copy) and the
  absolute branch (walks bottom-up: the first cut component is the last one).
- Rationale: an invalidation costs one `LIST` while an upload exists; trusting loses data. The
  last component is new whatever the cache knew of the folders above it (the server created it) -
  the same trust the upload workers' own single-name reports already rely on.
- Alternatives: (a) stop recording anything once an earlier component was unknown - rejected by
  clarification (the last folder is certainly new; the absolute branch walks bottom-up and could
  not know beforehand without a second pass); (b) insert the earlier component into the parent
  listing but add no empty listing - rejected: with case-insensitive servers it would insert
  `docs` beside `Docs`, a listing that no longer matches the server.
- Pure rule: `src/common/salftpmkdirreport.h` (header-only; the FTP plug-in cannot compile a
  `.cpp` from `src/common`), checked by `saltests`.
- Callers of `CUploadListingCache::ReportCreateDirs` (Grep): the panel (`ctrlcon5.cpp`, 2 calls),
  the upload workers (`operatsa.cpp` 4 calls, `operats3.cpp` 2 calls - always a single name, the
  target folder's name, so it is the last component: unchanged behaviour).
