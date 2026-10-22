# Research - 303-ftp-upload-case-only

## R1. Where the decision is made

- Decision: in `CUploadListingsOnServer::GetListing` (`operats9.cpp`), after `FindItem` fails,
  only when the caller passes `caseOnlyCounts = TRUE`.
- Rationale: all three file-upload decisions (start: exists?, resume size, auto-rename name free?)
  go through it; the folder upload's two calls keep `FALSE` (spec: path identity and folders are
  out of scope). Putting it into `FindItem` would change every cache update (`ReportStoreFile`,
  `ReportDelete`, `ReportRename`, ...) - their exact-name semantics must stay.
- Alternatives: change `FTPIsCaseSensitive` for Unix (changes path identity, sorting, every
  lookup - rejected by the item's *Notes*); ask the server (`SIZE` / `MLST` of the name) - more
  network traffic, and a case-sensitive server cannot tell us about the twin either.

## R2. The name rule

- Decision: `SalNameOrderEqualCI` (`src/common/salnameorder.h`, feature 115 = 092's rule).
- Rationale: CLAUDE.md standing rule "The same name is the file system's rule"; header-only, already
  used by the FTP plug-in (`operats9.cpp`, opened-file lock, 277). Covers `Č` / `č`; keeps NFC /
  NFD and the Kelvin sign apart from ASCII.
- Alternatives: `StrICmp` (code-page fold on UTF-8 bytes - the other item's defect), `_stricmp`
  (ASCII only - misses `Č` / `č`).

## R3. The found item's size

- Decision: the copy handed to the caller gets `ByteSize = UPLOADSIZE_UNKNOWN` when it was found
  only by case.
- Rationale: on a case-sensitive server it is another file's size; the resume path
  (`fwssWorkUploadGetFileSizeFromListing`) would append at that offset to a file that does not
  exist (a corrupt result reported as success). With an unknown size the existing branches apply:
  Resume -> "unable to determine size" (`ITEMPR_UPLOADUNABLETORESUMEUNKSIZ`), Resume or Overwrite
  -> overwrite, the "transferred whole?" test -> `ITEMPR_UPLOADTESTIFFINISHEDNOTSUP`. When the
  server answers `SIZE`, its answer is used, as today.
- Alternatives: exact-only for the size lookup - the retry branch (`existingItem == NULL` ->
  item waiting again) would loop: the start check finds the twin again, the size lookup misses it.

## R4. Cost

- Decision: a linear pass over the listing, only after the binary search missed.
- Rationale: `SalNameOrderEqualCI` returns at once for two different ASCII first bytes; converting
  happens only for names sharing a non-ASCII tail. One pass per new file; runs under the cache's
  critical section like `FindItem`.
- Alternatives: a second sorted index by `SalNameOrderCompareCI` - more memory and code in every
  cache update; not needed for the scale (folders of thousands of names).

## R5. What the user sees

- The existing "Target File Already Exists" question (or the configured automatic answer) with
  the target name as typed (`B.txt`). No new text, no log line (a new log string would be a new
  UI string - FR-007).
