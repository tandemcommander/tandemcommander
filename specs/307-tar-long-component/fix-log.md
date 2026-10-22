# Fix log - 307-tar-long-component

Backlog item `opening-a-tar-whose-member-name-has-a-300-letter-component` (measure:306).

## Measurement at d92d8278 (main, before the feature)

- `build.cmd` (Debug x64) at HEAD.
- `powershell -File tools\run_on_hidden_desktop.ps1 -Log %TEMP%\tcrun_scratch\result_before_gnu.txt
  -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File
  specs\306-tar-pax-headers\probe\pax306_probe.ps1 -Only GNU-TOOLONG,GNU-LONG -Label before-HEAD -Exe
  build\tandemcommander\Debug_x64\tandemcommander.exe"`:
  - GNU-LONG PASS (302-byte path, extracted whole).
  - GNU-TOOLONG FAIL: "A problem has occurred, forcing Tandem Commander to close", report
    "Error Number: 2 / Description: Stack memory corruption", innermost call-stack message
    `CFilesWindow::CommonRefresh`. Registry restored, SHA-256 identical.
- Root cause by reading (see research.md R1): the member is at the archive root ->
  `ReadArchiveHeader` sets `header.Path = NULL` -> `ListArchive` calls `AddFile(NULL, ...)` ->
  `CSalamanderDirectory::AddFile` (`src/zip.cpp`) checks its feature-222 bound only under
  `path != NULL` (`AddDir` likewise) -> the 904-byte name is listed -> `RefreshListBox`
  (`src/fileswn2.cpp`) runs `AlterFileName` into `char formatedFileName[SAL_FIND_NAME_U8]` (780).
  Every measured length agrees (604 / 769 bytes list, 904 crashes).
- Consumers of `AddFile` / `AddDir` enumerated (Grep `Add(File|Dir)\(` in `src/plugins`): with a
  NULL path - tar (root members, raw stream), FTP, SFTP, regedt, nethood, undelete, folders,
  portables, demoplug; with a folder path - ZIP, 7zip, unrar, unole, uniso, unchm, uncab, unmime
  (`""`). Core callers of `CSalamanderDirectory::AddFile` in `src/` (disk cache, plugins3) list
  disk names (at most 765 bytes).

## Analyze

- Run 1: no CRITICAL / HIGH. C1 MEDIUM (CHANGELOG task) fixed - T015. E1 LOW (no GNU-in-.deb probe
  row; the rule and the prefix are 306's, covered by its PAX-DEB row) and D1 LOW (refusal where a
  listing was - only for names that crashed) accepted.
- Run 2: no CRITICAL / HIGH.

## Probe before the change (T004)

Probe `probe/tar307_probe.ps1` (fixture `probe/mktar307.py`) on the unchanged build ->
`probe/result_before.txt`: **PASS 10, FAIL 4**.

- GNU-TOOLONG: END FAIL - the crash ("Stack memory corruption", under `CommonRefresh`).
- GNU-DEEP, GNU-255DIR: RUN FAIL - "Internal error: file data structure corrupted.", the archive
  does not open (folder part over the listing's 255 bytes / a 765-byte folder name with contents).
- GNU-255 (the 255-unit boundary at the root) and GNU-LONG: PASS.
- ZIP-TOOLONG: no crash; "Cannot add 1 or more files to the list. The total path is too long.",
  ok.txt extracted (the ZIP plug-in skips the entry, feature 222).
- 7Z-TOOLONG: no crash; "Internal error." at open (the 7-Zip plug-in passes a folder path, so the
  core refused the entry already), ok.txt extracted.
- Registry restored, SHA-256 identical.

The crash is reachable only through a NULL folder part; ZIP and 7-Zip use a folder path and were
already protected by feature 222's bound.

## Change

- `src/common/sallistingname.h` (new, header-only): `SalListingAcceptsFileU8` / `SalListingAcceptsDirU8`.
  With a folder part: feature 222's rule moved unchanged. With no folder part (`path == NULL`):
  refuse a name of `SAL_LISTING_NAME_MAX_BYTES` (= `SAL_FIND_NAME_U8`, 780) bytes or more, file
  or folder; nothing else (FS plug-ins keep names over 255 UTF-16 units and folders over 255 bytes).
- `src/zip.cpp` `CSalamanderDirectory::AddFile` / `AddDir` use it (`static_assert` the bound equals
  `SAL_FIND_NAME_U8`); `pathLen` still feeds the add cache as before.
- `src/plugins/tar/tar.h` / `untar.cpp`: `SCommonHeader::NameFromGnuLong`, set when a `GNUTYPE_LONGNAME`
  header supplied the name, reset in `Initialize`; feature 306's `SalPaxNameFitsListingU8` refusal
  applies when `NameFromPax || NameFromGnuLong` (member ignored, "(206)" + path once per listing /
  whole unpack, `ListingPrefixLen` for .deb counted).
- `src/saltests/saltests.cpp`: `TestListingName307`, 22 checks (779 / 780 bytes, the measured
  904-byte name, 300 ASCII letters, folder rules with a folder part, 255 / 256-byte folder parts).

## Checks after the change

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `build.cmd` -> `BUILD SUCCEEDED` (warnings only on unchanged lines).
- `saltests.exe` -> `saltests: 27174 checks, 0 failed` (306 closed at 27152; +22).
- Probe `tar307_probe.ps1 -Label after-final` -> `probe/result_after.txt`: **PASS 14, FAIL 0**
  (before 10 / 4): GNU-TOOLONG opens, "(206)" with the path, only ok.txt extracted; GNU-DEEP opens,
  "(206)", a.txt + ok.txt; GNU-255DIR opens, "(206)", ok.txt; GNU-255 and GNU-LONG whole; ZIP / 7Z
  unchanged (no crash, ok.txt). Registry restored identical.
- Regression: `pax306_probe.ps1` -> `probe/regress_306.txt` 28 / 0; its GNU-TOOLONG row (only with
  `-Only`) -> `probe/regress_306_gnutoolong.txt` 2 / 0 (opens, the message, nothing else to list);
  252 16 / 0, 273 12 / 0, 275 17 / 0 (`probe/regress_*.txt`) - the same numbers as feature 306.

## Negative controls (sources restored and rebuilt afterwards; the restored build re-measured above)

- (a) `header.NameFromGnuLong = TRUE` commented out (tar refusal off, core rule on) ->
  `probe/result_negctl_tar.txt` (GNU-TOOLONG, GNU-DEEP, GNU-255DIR): PASS 3, FAIL 3 - no crash in any
  row (END PASS: the core now refuses the 904-byte root name), but none of the three archives opens
  ("Internal error: file data structure corrupted.") - the tar refusal is what keeps the rest usable.
- (b) additionally both `path == NULL` branches of `sallistingname.h` returning true ->
  `saltests: 27174 checks, 4 failed` (the four NULL-path refusals) and
  `probe/result_negctl_core.txt` GNU-TOOLONG: END FAIL "Stack memory corruption" - the crash returns.
  Both layers are each measured to do their part.

## Review

### Review 1 (independent agent, refute-first)

Re-measured: saltests 27174 / 0, probe 14 / 0, 306 probe 28 / 0, negative-control files agree;
FR-003 holds (with a folder part the rule decides exactly as feature 222's test).

- **MUST-1 (fixed)**: an overflow was left below the new bound - `src/fileswn3.cpp`
  (`ReadDirectory`, archive panels with *Simple Icons In Archives*, and plug-in FS panels with
  simple icons) copied the extension unbounded into `char buf[SAL_FIND_NAME_U8]` and then wrote a
  DWORD of zeroes: `"." + 777 letters` (778 bytes, accepted by the listing) wrote 781 bytes. The
  reviewer crashed the branch build with a newc cpio (TAR plug-in) holding that name ("Stack
  memory corruption" under `CommonRefresh`); main crashed on it in any mode. Fix: both loops stop
  `sizeof(DWORD)` before the end, and an extension that did not fit has no association
  (`*s == 0 && IsAssociated(...)`) - never looked up cut. The other extension copies of the file
  write into `fileName[SAL_MAX_PATH_UTF8 + 4]` (safe). Probe rows CPIO-778 and CPIO-TOOLONG
  (open-only, simple icons on, run last; the registry restored at the end).
- **SHOULD-1 (fixed)**: a regression against 0.1.10 - an empty top-level folder of 86-255 CJK letters
  (258-765 bytes) in a GNU tar was now refused (306's folder-name rule applied to GNU names; the
  reviewer measured 0.1.10 listing and extracting a 100-letter one). 306's rule assumed `AddDir`
  refuses a folder name over 255 bytes, which it does only with a folder part. Fix in
  `SalPaxNameFitsListingU8`: the folder-name bound applies only with a folder part or a prefix;
  the same rule now lists such a top-level PAX folder too (its contents with a folder part over
  255 bytes are still refused alone). The tar plug-in has no delete / pack (view and unpack only),
  so feature 222's concern (deleting members never shown) does not apply. saltests: 306's checks
  of top-level folders corrected (+2); probe row GNU-DIR100.
- NOTE 1: a cpio / rpm top-level name of 780+ bytes no longer crashes but the whole archive does not
  open ("Internal error: file data structure corrupted.") - the changelog limitation reworded; an
  Inbox item records the per-member refusal for cpio (outside the item: GNU long names).
- NOTE 2 (accepted): regedt / nethood / undelete ignore a failed addition - a 780+ byte name is now
  simply missing instead of crashing; the changelog says "some leave just that entry out".
- NOTE 3 (fixed by the new rows): the probe did not reach the 777-779-byte boundary nor simple
  icons. Whole-archive unpack and GNU-in-.deb are 306's code paths and rows (PAX-DEB, its unpack
  measurement), unchanged in this feature.

After the fixes: `build.cmd` -> BUILD SUCCEEDED; `saltests: 27176 checks, 0 failed`; encoding
`TOTAL: 0 finding(s)`; probe `-Label after-review1` -> `probe/result_after.txt` **PASS 20, FAIL 0**;
306 probe 28 / 0 (`probe/regress_306.txt`; PAX-255DIR now lists the empty folder and names in.txt),
273 12 / 0.

Negative controls (c) + (d) - both review fixes reverted together (the loops unbounded, the folder
rule as in 306), `-Only CPIO-778,GNU-DIR100` -> `probe/result_negctl_review1.txt`: PASS 1, FAIL 3 -
CPIO-778 crashes again ("Stack memory corruption"), GNU-DIR100 "(206)" and the folder not
extracted; saltests 1 failed (the top-level folder check). Sources restored byte for byte, rebuilt,
re-measured (above).

### Review 2 (independent agent, refute-first; review 1 findings given) - rejected

Re-measured: saltests 27176 / 0; probe 20 / 0. Review 1's MUST-1 verified at the boundaries (776
bytes looked up whole, 777+ no association, the DWORD always inside the buffer; cpio rows with
779 bytes ending in `.txt`, `.` + 776, `.` + 778, `x.` + 777 - no crash). SHOULD-1 verified
(a top-level GNU / PAX folder of 100 CJK letters lists; its contents refused with "(206)").

- **MUST-1 (not fixed - the run stops)**: data loss in whole-archive Unpack. The `NameFromGnuLong`
  refusal sits in `CArchive::ReadArchiveHeader` (`src/plugins/tar/untar.cpp`, the check after the
  name conversion), which every pass runs - also `UnpackWholeArchive` / `DoUnpackArchive`, where no
  listing exists. It applies the LISTING-only bound (`SalPaxNameFitsListingU8`: a folder part over
  255 bytes, `src/common/salpaxheader.h`), so a member NTFS takes (a deep source tree - GNU tar
  writes an `L` long name for every path over 100 bytes) is skipped, the unpack still returns
  TRUE, and with "Delete archive after unpacking" the plug-in (`src/plugins/tar/tardll.cpp`, after
  the unpack) deletes the archive. Reviewer's rows (fixtures in `%TEMP%\rev307b`): 30 files under
  10 folders of 29 letters (folder part 299 bytes) + ok.txt - 0.1.10 extracts all 31, the branch
  only ok.txt with one "(206)" box; with Delete-after-unpack the branch deletes t.tar (30 files
  lost); `x*100/y*100/z*100/f.txt` and `CJK100/in.txt` dropped likewise. On `main` only
  `NameFromPax` refuses, so for GNU names the regression is feature 307's; feature 306's PAX route
  has the same mechanism on `main` (recorded as an Inbox item). The fix-log's NOTE 3 of review 1
  ("whole-archive unpack is 306's code path, unchanged") was wrong for GNU names.
  Direction given: apply the folder-part / folder-name byte bound only while building a listing
  (`ListArchive`); in unpack keep only the over-255-unit component refusal; make any refusal during
  a whole unpack return failure so that "Delete archive after unpacking" never fires.
- NOTE 1: analyze note D1 is inaccurate - a top-level GNU file of 300 ASCII letters or CJK(258).txt
  (778 bytes) listed in 0.1.10 without a crash and is now refused (nothing usable is lost: F3 said
  "resulting filename is too long", extraction failed with (123)); the changelog's *Before* sentence
  over-generalises (only names of 780+ bytes overflowed RefreshListBox).
- NOTE 2: a top-level folder of 256-765 bytes is now listed (PAX too) but cannot be entered ("The path
  specified is too long.") - the same as 0.1.10 for GNU names, no data involved.
- NOTE 3: F5 of such a folder creates it empty silently; the "(206)" box comes only at open (as 306).
- NOTE 4: the installed 0.1.10 Release build opened the 777-780-byte cpio names with simple icons
  without a visible crash - the overflow shows under the Debug run-time checks.
- Other buffers checked by reading and bounded for names up to 779 bytes: `IsFileLink`, quick search
  copies, `DrawItemBuff` / `DrawItemAlpDx`, `SplitText`, `ZIPPath[SAL_MAX_PATH_UTF8]`,
  `NextFocusName`, the info line.

## Stopped (2026-10-22)

Stop rule §3 #3: the independent review rejected the fix twice (review 1 MUST fixed; review 2 MUST
above). What the branch holds and is sound by both reviews: the core bound for entries with no
folder part (`src/common/sallistingname.h`, `AddFile` / `AddDir`), the bounded extension copies in
`src/fileswn3.cpp`, the saltests, the probe and its rows. What must change before closing: the GNU
refusal (and the folder rule change of review 1) must not act in extraction passes the way they act
in the listing - restrict the depth / folder-name bound to `ListArchive`, keep only the component
rule in unpack, and let a refusal fail a whole-archive unpack. Then re-run the probe (add Unpack and
Unpack + Delete-archive rows with a deep GNU tree, as in the reviewer's `%TEMP%\rev307b` rows),
the 306 probe and a fresh review. Inbox items recorded on `main`: the PAX (feature 306) unpack data
loss and the cpio / rpm per-member refusal.
