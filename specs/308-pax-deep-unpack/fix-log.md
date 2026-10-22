# Fix log - 308-pax-deep-unpack

Backlog item `whole-archive-unpack-of-a-pax-tar-skips-deep-members-and-may` (review:307).

## Measurement at aa7f08bb (main, before the feature)

- `.\build.cmd` (Debug x64) at HEAD -> up to date.
- New probe `probe/unp308_probe.ps1` (fixture `probe/mkunp308.py`, Python 3.14 `tarfile`, PAX format),
  run from a scratch copy with `-Lib specs\098-long-path-overruns\probe\fix_probe_lib.ps1`:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine "powershell
  -NoProfile -ExecutionPolicy Bypass -File ...\unp308_probe.ps1 -Label before-main -Lib ... -Exe
  build\tandemcommander\Debug_x64\tandemcommander.exe"` -> `probe/result_before.txt`: **PASS 5 (the END
  rows), FAIL 5**:
  - UNP-DEEP (Alt+F9, mask `*.*`): 2 of 34 files; one "(206)" box naming `a*29\...\j*29\f01.txt`.
  - UNP-DEEP-DEL (+ "Delete archive after unpacking"): 2 of 34 files, **t.tar deleted** (32 members lost).
  - UNP-TOOLONG-DEL (`CJK(300).txt`, `ok.txt`, + Delete): ok.txt, "(206)", **t.tar deleted**.
  - UNP-DEB (whole Unpack of a .deb): 3 of 5 (both deep data members missing).
  - COPY-DEEP (Select All + Copy; the listed folder a*29 holds the deep files): 2 of 32, no message
    during the copy (the "(206)" box came only at opening).
  - Registry restored, SHA-256 identical.
- Reachability: Alt+F9 -> `CFilesWindow` unpack handler (`src/fileswn7.cpp`) -> `ExecuteUnpacker` ->
  `CPluginData::UnpackWholeArchive` -> tar `CPluginInterfaceForArchiver::UnpackWholeArchive`
  (`archiveVolumes->Add` before the unpack) -> `CArchive::UnpackWholeArchive` -> `DoUnpackArchive` ->
  `ReadArchiveHeader` (feature 306's refusal with the listing bound). On TRUE the core deletes the
  volumes with `SalDeleteFile` ("unpacking succeeded (no Cancel, Skip may have occurred)").

## Consumers enumerated (Grep `ReadArchiveHeader`, `ReportRefusedNames`, `RefusedNameShown`,
`NameFromPax`, `ListingPrefixLen` in `src/plugins/tar`)

- `ReadArchiveHeader`: `ListArchive`, `UnpackOneFile`, `DoUnpackArchive` (from `UnpackArchive` and
  `UnpackWholeArchive`) - all in `untar.cpp`.
- `ReportRefusedNames`: set in the constructor (FALSE), `ListArchive` and `UnpackWholeArchive` (TRUE);
  read only in `ReadArchiveHeader`.
- `ListingPrefixLen`: `deb/deb.cpp` (`SetListingPrefixLen` for both tar parts); read only in the refusal.
- `.deb`: `CDEBArchive::ListArchive` / `UnpackWholeArchive` / ... call the two `CArchive` objects; the
  whole unpack ANDs their results.
- cpio / rpm: `CpioDoUnpackArchive` / `CpioUnpackOneFile`, no `NameFromPax` - not affected.
- `CNames::IsNamePresent` (`names.cpp`): a selected folder matches its whole subtree (`isDir && *name == '\\'`).

## Analyze

- Run 1: CRITICAL 0, HIGH 0. E1 MEDIUM (no probe row for the Copy + too-long-member decision of
  clarification Q1) fixed - row COPY-TOOLONG in T011. F1 LOW (one box per operation vs per tar part)
  fixed in the spec's edge case. C1 LOW (several refused members in one unpack not probed) accepted -
  the once-flag is 306's unchanged code.
- Run 2: no CRITICAL / HIGH.

## Change

- `src/common/salpaxheader.h`: `SalPaxNameUsableU8(name, isDir, prefixLen, listing)` - while listing,
  feature 306's `SalPaxNameFitsListingU8` unchanged; in an extraction only `SalPaxPathHasTooLongComponentU8`
  (a component over 255 UTF-16 units) refuses.
- `src/plugins/tar/tar.h` / `untar.cpp`: `SCommonHeader::NameRefused` (reset in `Initialize`);
  `CArchive::Listing` replaces `ReportRefusedNames` (TRUE in `ListArchive`, FALSE in the constructor,
  `UnpackOneFile`, `DoUnpackArchive`); the refusal in `ReadArchiveHeader` uses the new rule with the
  pass, sets `Ignored` + `NameRefused`, and shows the box only while listing; the box text moved
  unchanged into `CArchive::ReportRefusedName` (once per CArchive object).
  `DoUnpackArchive`: a member with `found && NameRefused` (asked for by mask / selection) -> the box,
  `refused = TRUE`; both successful ends return `!refused`. `UnpackOneFile`: `found && NameRefused` ->
  the box, FALSE (it returned TRUE with nothing extracted; unreachable from the listing, kept consistent).
  `UnpackWholeArchive` no longer sets a report flag.
- T008 (read): `UnpackArchive` -> `DoUnpackArchive` (Listing FALSE); `CNames::IsNamePresent` matches a
  selected folder's subtree (`isDir && *name == '\\'`) -> Copy of a folder takes its deep members.
- `src/saltests/saltests.cpp`: `TestPaxNameUsable308`, 18 checks (the probe's 299-byte folder part,
  CJK(90) folder, 765-byte folder name, .deb prefix: listing refuses, extraction accepts; 300 / 256-unit
  components refused in both; 255 units usable in both; listing pass identical to 306's rule).
- Probe: row COPY-TOOLONG added (analyze E1).

## Checks after the change

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (warnings C4267 only on unchanged lines 1217 / 1238 / 1855).
- `saltests.exe` -> `saltests: 27170 checks, 0 failed` (27152 before, +18).
- Probe `unp308_probe.ps1 -Label after` -> `probe/result_after.txt` **PASS 12, FAIL 0** (before: 5 / 5,
  COPY-TOOLONG not yet a row): UNP-DEEP 34/34 nothing asked; UNP-DEEP-DEL 34/34 and t.tar deleted (all
  extracted); UNP-TOOLONG-DEL ok.txt, "(206)", t.tar KEPT; UNP-DEB 5/5; COPY-DEEP 32/32; COPY-TOOLONG
  top.txt + ok.txt and "(206)" during the copy. Registry restored identical.
- Regressions (`probe/regress_*.txt`): 252 16 / 0, 273 12 / 0, 275 17 / 0 - the numbers of feature 306.
  306: **27 / 1** - row PAX-DEB: Copy of the selected folder `data` now also extracts
  `data/a*125/b*125/f.txt` (251 bytes + the listing's "data\" over 255: not listed, "(206)" at open as
  before). That is FR-002 / the item's "every extraction pass"; the row had encoded the omission. Its
  expectation updated in `specs/306-tar-pax-headers/probe/pax306_probe.ps1` (comment names 308),
  `-Only PAX-DEB` re-run -> `probe/regress_306_deb.txt` 2 / 0 -> the 306 probe is 28 / 0 with it.
  Clarification recorded in spec.md, SC-002 reworded.

## Negative controls (sources restored byte for byte afterwards - `cmp` with the saved copy - rebuilt, re-measured)

- (A) `Listing = TRUE` in `DoUnpackArchive` (the listing bound back in extraction) + (B) both
  successful ends of `DoUnpackArchive` return TRUE (refusal ignored) -> `probe/result_negctl.txt`
  PASS 7 / FAIL 5: UNP-DEEP, UNP-DEEP-DEL (t.tar deleted), UNP-DEB, COPY-DEEP back to 2 of 34 / 3 of 5 /
  2 of 32 (A); UNP-TOOLONG-DEL deletes t.tar again (B - with A alone the refusal still fails the unpack).
  COPY-TOOLONG passed: under A the listing-mode refusal shows the box itself.
- (B) + (C) the `ReportRefusedName` call in `DoUnpackArchive` removed, A undone ->
  `probe/result_negctl_report.txt` `-Only COPY-TOOLONG,UNP-TOOLONG-DEL,UNP-DEEP-DEL`: PASS 4 / FAIL 2 -
  COPY-TOOLONG no box during the copy (C), UNP-TOOLONG-DEL silent and t.tar deleted (B + C);
  UNP-DEEP-DEL still 34/34 (the depth fix is independent).
- Restored build: `probe/result_after.txt` re-run `-Label after-restored` -> PASS 12 / FAIL 0.

## Review

### Review 1 (independent agent, refute-first) - no MUST

Re-measured on the branch: probe 12 / 0, 306 probe 28 / 0, saltests 27170 / 0, encoding 0. Negative
control by the reviewer: the extraction pass of `SalPaxNameUsableU8` with the listing bound -> saltests
6 failed; restored (cmp, git status clean), 0 failed. Own rows (copy of the probe in the reviewer's
%TEMP%\rev308), 16 / 16 PASS: .tgz deep + Delete (34 files, deleted); .tgz CJK(300) + Delete ("(206)",
kept); mask `*.txt` matching the refused member + Delete (kept); mask `ok*` not matching it (deleted -
the agreed rule); .deb with a CJK(300) data member + Delete (kept); .deb deep + Delete (deleted, all
files); Copy from inside a*29 (archiveRoot set, 32 / 32). Callers enumerated: Copy (`src/fileswn7.cpp`),
drag and drop (`src/salshlib.cpp`), Unpack (`src/fileswn7.cpp`), `deb.cpp`, `UnpackStream`; a FALSE
from Copy only keeps the selection and removes created empty folders - nothing extracted is deleted;
the tar plug-in has no Move.

- SHOULD-1 (fixed): `CHANGELOG.md` - feature 306's unreleased entry still said a member deeper than the
  listing "is left out", and 308's separate entry described as "Before" a behaviour no release had
  (306 is unreleased too). 308 folded into 306's entry ("features 306, 308"): its *Now* says such
  members are not shown in the panel but Unpack and copying their folder extract them, and a member
  no file system takes makes the unpack fail so Delete keeps the archive; the separate entry removed.
- SHOULD-2 (fixed): the hand-off to branch 307 was not recorded - logged on item
  `opening-a-tar-whose-member-name-has-a-300-letter-component` (its GNU refusal must use
  `SalPaxNameUsableU8` with the pass flag when resumed).
- NOTE 1 (accepted): a symbolic link whose name has a 300-unit component fails the unpack ("(206)",
  archive kept) although links are never extracted - the safe side; the message is the only cost.
- NOTE 2 (accepted): a path over ~32,767 characters is not refused by the plug-in; the core shows
  "(123)" with Retry / Skip / Cancel - Skip lets the unpack succeed (the core's Skip rule, the user's
  choice; before 308 it was a silent skip and a delete).
- NOTE 3 (new Inbox item): hard links (and symbolic links) are skipped silently and the whole unpack
  succeeds, so Delete-after-unpack deletes the archive - inherited behaviour, outside this item ->
  `tar-unpack-drops-hard-links-and-deletes-archive` (review:308).
- NOTE 4 (accepted): the box at opening covers members a Copy of their folder will extract; the free
  space check and the Copy confirmation count only listed members.
- NOTE 5 (accepted): the `UnpackOneFile` change has no probe row - unreachable from the listing.

After the fixes (documents only - no source changed): encoding guard and backlog check re-run at closing.
