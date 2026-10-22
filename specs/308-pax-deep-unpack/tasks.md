# Tasks: Extraction of a PAX tar takes every member a file system takes

**Input**: `specs/308-pax-deep-unpack/` - plan.md, spec.md, research.md, data-model.md, quickstart.md
**Tests**: saltests checks of the rule (project rule: pure decisions in `src/common` with saltests) and
the hidden-desktop probe rows named in spec.md.

## Phase 1: Setup

- [X] T001 Start `specs/308-pax-deep-unpack/fix-log.md` with the measurement before the feature (probe `specs/308-pax-deep-unpack/probe/result_before.txt`: PASS 5 / FAIL 5) and the enumerated consumers of `ReadArchiveHeader` / `ReportRefusedNames` (research.md R1)

## Phase 2: Foundational (the rule)

- [X] T002 Add `SalPaxNameUsableU8(name, isDir, prefixLen, listing)` to `src/common/salpaxheader.h`: listing -> `SalPaxNameFitsListingU8`; extraction -> `!SalPaxPathHasTooLongComponentU8`
- [X] T003 Add saltests checks of `SalPaxNameUsableU8` in `src/saltests/saltests.cpp` (a 299-byte folder part, a 765-byte folder name with a folder part, a 255-byte folder part + .deb prefix: refused for the listing, usable for extraction; 300-unit and 256-unit components refused in both; 255 units usable in both)

## Phase 3: User Story 1 - whole Unpack extracts the deep members (P1)

**Independent test**: probe rows UNP-DEEP, UNP-DEEP-DEL, UNP-DEB.

- [X] T004 [US1] In `src/plugins/tar/tar.h` add `SCommonHeader::NameRefused`; replace `CArchive::ReportRefusedNames` with `CArchive::Listing`; declare `CArchive::ReportRefusedName(const char* name)`
- [X] T005 [US1] In `src/plugins/tar/untar.cpp`: reset `NameRefused` in `SCommonHeader::Initialize`; constructor initializes `Listing = FALSE`; `ListArchive` sets `Listing = TRUE`; `UnpackOneFile` / `DoUnpackArchive` set `Listing = FALSE`; `UnpackWholeArchive` no longer sets a report flag; `ReadArchiveHeader` refuses with `SalPaxNameUsableU8(..., Listing != FALSE)`, sets `Ignored` and `NameRefused`, and shows the box (moved into `ReportRefusedName`) only while listing

## Phase 4: User Story 2 - an unextractable member keeps the archive (P1)

**Independent test**: probe row UNP-TOOLONG-DEL.

- [X] T006 [US2] In `src/plugins/tar/untar.cpp` `DoUnpackArchive`: a member with `found && NameRefused` -> `ReportRefusedName(header.Name)` and remember the refusal; both successful ends (TAR_EOF and `Finished`) return FALSE when a refusal was remembered
- [X] T007 [US2] In `src/plugins/tar/untar.cpp` `UnpackOneFile`: `found && NameRefused` -> `ReportRefusedName` and return FALSE

## Phase 5: User Story 3 - Copy of a folder copies its whole subtree (P2)

**Independent test**: probe rows COPY-DEEP, COPY-TOOLONG (served by T005 - the selection pass no longer applies the listing bound; T006 covers the report).

- [X] T008 [US3] Confirm by reading that `CArchive::UnpackArchive` reaches `DoUnpackArchive` with `Listing == FALSE` and that `CNames::IsNamePresent` (`src/plugins/tar/names.cpp`) matches a selected folder's whole subtree; record in `specs/308-pax-deep-unpack/fix-log.md`

## Phase 6: Polish & checks

- [X] T009 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [X] T010 `.\build.cmd` (PowerShell) -> `BUILD SUCCEEDED`; `saltests.exe` -> 0 failed
- [X] T011 Add row COPY-TOOLONG to `specs/308-pax-deep-unpack/probe/unp308_probe.ps1` / `mkunp308.py` (a*29/top.txt, a*29/CJK(300).txt, ok.txt; Select All + Copy -> top.txt + ok.txt, a "(206)" box during the copy); run the probe `-Label after` -> `probe/result_after.txt` PASS 12 / FAIL 0
- [X] T012 Regression: `specs/306-tar-pax-headers/probe/pax306_probe.ps1` -> `specs/308-pax-deep-unpack/probe/regress_306.txt` 27 / 1 (PAX-DEB: its Copy now extracts the deep data member - expectation updated in `specs/306-tar-pax-headers/probe/pax306_probe.ps1`, row re-run `regress_306_deb.txt` 2 / 0); 252 / 273 / 275 probes `regress_*.txt`
- [X] T013 Negative control: the extraction pass with the listing bound again (`Listing` forced TRUE in `DoUnpackArchive`) -> UNP-DEEP / UNP-DEEP-DEL / UNP-DEB / COPY-DEEP fail again; and the refusal result ignored (return TRUE) -> UNP-TOOLONG-DEL deletes the archive again; sources restored and rebuilt; `probe/result_negctl.txt`
- [X] T014 Record checks, numbers and the negative control in `specs/308-pax-deep-unpack/fix-log.md`; add the CHANGELOG entry under the `— unreleased` heading in `CHANGELOG.md` (if one exists)

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006/T007 -> T008 -> T009..T014. US1 and US2 share `untar.cpp`
(sequential); US3 needs only T005.

## Parallel examples

T002/T003 (header + saltests) can be written while T004 is drafted; T009 and T010 are independent.

## Implementation strategy

MVP = US1 + US2 together (one change in one function chain; US2 is the data-loss half). US3 comes
with T005 at no cost.
