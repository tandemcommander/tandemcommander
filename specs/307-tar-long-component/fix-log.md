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
