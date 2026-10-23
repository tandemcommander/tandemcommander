# Fix log - 321-tar-long-component

Backlog item `opening-a-tar-whose-member-name-has-a-300-letter-component` (measure:306). Second run:
the first (feature 307, `origin/307-tar-long-component`, stopped 2026-10-22 after review 2) is the
starting record - its spec, plan, research, fix-log, probe and results are copied into `run307/`.

## Measurement at 26c31a9d (main, before the feature)

- `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED.
- `powershell -File tools\run_on_hidden_desktop.ps1 -Log %TEMP%\tcrun_scratch\result_before_gnu_main.txt
  -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File
  specs\306-tar-pax-headers\probe\pax306_probe.ps1 -Only GNU-TOOLONG -Label before-HEAD -Exe
  build\tandemcommander\Debug_x64\tandemcommander.exe"` -> GNU-TOOLONG END FAIL: "A problem has
  occurred, forcing Tandem Commander to close", report "Error Number: 2 / Description: Stack memory
  corruption", innermost call-stack message `CFilesWindow::CommonRefresh`; RUN FAIL (did not open).
  Registry restored, SHA-256 identical. The defect is present at HEAD (`BL verify`).
- Root cause as in `run307/fix-log.md` / `run307/research.md` R1, re-read at HEAD: a root member
  (`header.Path = NULL`) -> `CSalamanderDirectory::AddFile(NULL, ...)` (`src/zip.cpp`) applies feature
  222's bound only under `path != NULL` (`AddDir` likewise, unchanged since 307) -> the 904-byte name
  is listed -> `RefreshListBox` formats it into `char formatedFileName[SAL_FIND_NAME_U8]`.

## Carry-over of 307 (SKILL.md 4.6)

`main` moved 120 commits since 307's base (d92d8278): features 308 (pass-dependent PAX refusal:
`SalPaxNameUsableU8`, `CArchive::Listing`, `SCommonHeader::NameRefused`), 309 (links, `LinkName`; the
GNU long-name branch now writes through `char** longName`), 310 (cpio hard links), 315-320.

`git diff --binary d92d8278 origin/307-tar-long-component -- . ':!backlog' ':!specs' ...` and
`git apply -3`: clean for `sallistingname.h` (new), `salpaxheader.h`, `fileswn3.cpp`, `zip.cpp`;
conflicts in `tar.h`, `untar.cpp`, `saltests.cpp`, `CHANGELOG.md`, resolved by the item's logic:

- `tar.h` / `untar.cpp`: `main`'s code kept; 307's GNU flag re-applied on it as `NameFromGnu`
  (set in the GNU long-name branch when `longName == &header.Name`, reset in `Initialize`), and
  the refusal of `ReadArchiveHeader` is now 308's pass-dependent one for both sources:
  `(NameFromPax || NameFromGnu) && !SalPaxNameUsableU8(..., Listing)` - the depth / folder-name
  bound only while listing, only the over-255-unit component in an extraction, a refused member
  asked for by an extraction reported and the extraction failed (308's `NameRefused` path). This
  is review 2's MUST of the first run.
- `saltests.cpp`: both sides kept (308-319 tests and 307's `TestListingName307`, its include).
- `CHANGELOG.md`: `main`'s side; the entry is written at closing.
- The carried code's comments and the test renamed from feature 307 to 321 (307 never reached
  `main`).

## Analyze

- Run 1: no CRITICAL / HIGH. F1 MEDIUM (the before-probe needs `main`'s build, T001 rebuilt first)
  and F2 MEDIUM (spec counted 31 files, the reused 308 deep-tree fixture holds 34) fixed in
  `tasks.md` / `spec.md`. C1 LOW (the saltests task serves US1 and US2) accepted.
- Run 2: no CRITICAL / HIGH / MEDIUM.

## Probes before the change (T004, on main's build 26c31a9d)

- `probe/tar321_probe.ps1 -Label before-main-26c31a9d` -> `probe/result_before.txt`: **PASS 12, FAIL 8**.
  GNU-TOOLONG, CPIO-778, CPIO-TOOLONG: END FAIL (the crash, "Stack memory corruption" under
  `CommonRefresh`); GNU-DEEP, GNU-255DIR: RUN FAIL ("Internal error: file data structure
  corrupted.", the archive does not open). GNU-255, GNU-LONG, GNU-DIR100, ZIP, 7Z: PASS.
- `probe/unp321_probe.ps1` (308's probe with GNU long names, `mkunp321.py` writes `tarfile.GNU_FORMAT`:
  33 `L` headers, no PAX header in the deep tree) -> `probe/unp_before.txt`: **PASS 9, FAIL 3**.
  UNP-DEEP / UNP-DEEP-DEL / UNP-DEB PASS (no GNU refusal on main); UNP-TOOLONG-DEL FAIL (no
  "(206)": the extraction tries the 300-letter name and fails with "(123) invalid name"; ok.txt was
  not written in the probe's answer path); COPY-DEEP / COPY-TOOLONG FAIL (the archive does not open).

## Build fix (T001)

The carry-over's `saltests.cpp` merge lost the closing brace of `TestPackName319` (diff3 aligned
the shared `}` after 307's function): `C2601 local function definitions are illegal`. Brace added.

## Checks after the change

- `.\build.cmd` -> BUILD SUCCEEDED. `saltests.exe` -> `saltests: 27698 checks, 0 failed`.
- T008: `TestListingName321` (the 22 checks of the first run) + 12 checks of the GNU rule per pass
  (`SalPaxNameUsableU8`: the deep name refused only while listing, the 300-letter component in both
  passes, the top-level CJK(100) folder listed, inside a folder part refused while listing only).
- `probe/tar321_probe.ps1 -Label after` -> `probe/result_after.txt`: **PASS 20, FAIL 0**. The first
  run's GNU-255DIR expectation ("tgt ok.txt") predated feature 308: the top-level folder CJK(255) is
  listed, so Copy of it extracts `CJK(255)/in.txt` too (only the listing refuses it, folder part 765
  bytes) - the row now expects ok.txt + in.txt; "(206)" at open still required.
- `probe/unp321_probe.ps1 -Label after` -> `probe/unp_after.txt`: **PASS 12, FAIL 0**: UNP-DEEP 34/34,
  UNP-DEEP-DEL 34/34 and the archive deleted (all extracted), UNP-TOOLONG-DEL ok.txt + "(206)" +
  archive KEPT, UNP-DEB 5/5, COPY-DEEP 33/33 (expectation +1: `CJK(255)/in.txt`, same reason as
  above), COPY-TOOLONG 2/2 + "(206)" during the copy.
- Regression: `pax306_probe.ps1` -> `probe/regress_306.txt` 28 / 0; `unp308_probe.ps1` ->
  `probe/regress_308.txt` 12 / 0; `link309_probe.ps1` -> `probe/regress_309.txt` 16 / 0;
  `cpio310_probe.ps1` -> `probe/regress_310.txt` 52 / 0. 306's PAX-255DIR and 308's COPY-DEEP
  expected the top-level folder CJK(255) not to be listed (306's folder rule); with the first run's
  review-1 change it is listed for PAX too, and Copy extracts its `in.txt` (more is extracted,
  nothing is lost). The first run of each failed exactly that row (27/1, 11/1); both rows' expectations
  updated with a `feature 321` comment, then 28/0 and 12/0.
- T009: callers of `AddFile` / `AddDir` at HEAD (Grep `(->|\.)Add(File|Dir)\(`): core - `fileswn7.cpp`,
  `fileswna.cpp` pass `""` (a folder part: rule unchanged), `pack1.cpp` a folder part; NULL path -
  tar (root members), ftp, sftp, regedt, nethood, undelete, folders, portables, demoplug; with a
  folder path - zip, 7zip, unrar, unole, uniso, unchm, uncab, unmime. Same set as the first run.
- T010: `fileswn3.cpp` extension copies at HEAD: the two into `buf[SAL_FIND_NAME_U8]` bounded (carried);
  the others write into `fileName[SAL_MAX_PATH_UTF8 + 4]` / `nameU8[3 * MAX_PATH + 4]` (disk names) - safe.

## Negative controls (T015; each source edit restored with `git checkout HEAD -- <file>`, rebuilt, re-measured)

- (c) the GNU refusal with the listing rule in every pass (`header.NameFromGnu ? true : Listing`) -
  the first run's review-2 defect -> `probe/result_negctl_pass.txt` (`-Only UNP-DEEP,UNP-DEEP-DEL`):
  PASS 2, FAIL 2 - both Unpack rows write 2 of 34 files (the deep members lost); thanks to 308's
  failure path the archive is kept even with Delete. The pass-dependent rule is what keeps them.
- (a) `header.NameFromGnu = TRUE` removed (tar refusal off, core rule on) ->
  `probe/result_negctl_tar.txt` (GNU-TOOLONG, GNU-DEEP, GNU-255DIR): PASS 3, FAIL 3 - no crash (END
  PASS: the core refuses the 904-byte root name), but none of the three archives opens ("Internal
  error: file data structure corrupted.").
- (b) (a) + both `path == NULL` branches of `sallistingname.h` returning true -> `saltests: 27698
  checks, 4 failed` and `probe/result_negctl_core.txt` GNU-TOOLONG: END FAIL "A problem has occurred"
  (the crash returns).
- Restored: `git status` clean of sources, no `NEGCTL` left; `build.cmd` BUILD SUCCEEDED; `saltests:
  27698 checks, 0 failed`; encoding `TOTAL: 0 finding(s)`; `tar321_probe -Label after-restored` 20 / 0
  (`probe/result_after.txt`), `unp321_probe -Label after-restored` 12 / 0 (`probe/unp_after.txt`).

## Changelog (T016)

Entry at the top of `[0.1.11] — unreleased` (feature 321); the 306 / 308 entry's limitation "still
crashes the program on opening - recorded for later" now says "crashed ... - fixed by feature 321".
