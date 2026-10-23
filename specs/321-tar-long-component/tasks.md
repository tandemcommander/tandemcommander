# Tasks: An archive member whose name the panel cannot hold never crashes the program

**Input**: Design documents from `specs/321-tar-long-component/` (spec, plan, research, data-model,
contracts, quickstart); the first run's record in `run307/`.
**Tests**: required by the project (`saltests` for pure rules, hidden-desktop probes).

## Phase 1: Setup

- [ ] T001 Build the carried-over tree once (`.\build.cmd`) and confirm `BUILD SUCCEEDED`; record in specs/321-tar-long-component/fix-log.md
- [ ] T002 [P] Adapt the first run's probe to this feature: specs/321-tar-long-component/probe/tar321_probe.ps1 and mktar321.py (names, `%TEMP%\tc321`, backup `tc321_backup.reg`, the `-t` title)
- [ ] T003 [P] Create the GNU-format unpack probe specs/321-tar-long-component/probe/unp321_probe.ps1 + mkunp321.py from specs/308-pax-deep-unpack/probe/unp308_probe.ps1 / mkunp308.py with `tarfile.GNU_FORMAT` (every path over 100 bytes becomes a GNU `L` long name)

## Phase 2: Foundational

- [ ] T004 Probe before the change: run tar321_probe.ps1 and unp321_probe.ps1 on a build of `main` (26c31a9d) in a worktree copy, results specs/321-tar-long-component/probe/result_before.txt and probe/unp_before.txt

## Phase 3: User Story 1 - A tar with an over-long GNU member name opens (P1)

Independent test: tar321_probe rows GNU-TOOLONG, GNU-DEEP, GNU-255DIR, GNU-255, GNU-LONG, GNU-DIR100.

- [ ] T005 [US1] SCommonHeader::NameFromGnu in src/plugins/tar/tar.h, reset in Initialize, set in the GNU long-name branch of CArchive::ReadTarHeader (src/plugins/tar/untar.cpp) - done in the carry-over; verify by reading
- [ ] T006 [US1] The refusal in CArchive::ReadArchiveHeader (src/plugins/tar/untar.cpp) covers `NameFromPax || NameFromGnu` with SalPaxNameUsableU8(..., Listing) - done in the carry-over; verify by reading
- [ ] T007 [US1] SalPaxNameFitsListingU8 top-level folder rule in src/common/salpaxheader.h (carried); verify 306's and 308's saltests still describe it

## Phase 4: User Story 2 - Unpacking a deep GNU tree keeps every member (P1)

Independent test: unp321_probe rows UNP-DEEP, UNP-DEEP-DEL, UNP-TOOLONG-DEL, UNP-DEB, COPY-DEEP, COPY-TOOLONG.

- [ ] T008 [US2] saltests: GNU-pass checks in src/saltests/saltests.cpp (TestListingName321: the deep name refused only while listing, the 300-letter component refused in both passes, a top-level CJK(100) folder accepted while listing)

## Phase 5: User Story 3 - No plug-in listing can overflow the panel (P2)

- [ ] T009 [US3] src/common/sallistingname.h + CSalamanderDirectory::AddFile / AddDir in src/zip.cpp (carried); re-enumerate the callers of AddFile / AddDir at HEAD (Grep `Add(File|Dir)\(` in src/ and src/plugins) and record them in fix-log.md
- [ ] T010 [US3] Bounded extension copies in CFilesWindow::ReadDirectory, src/fileswn3.cpp (carried); re-check the other extension copies at HEAD (research R7)

## Phase 6: User Story 4 - ZIP and 7-Zip archives with the same name (P3)

- [ ] T011 [US4] tar321_probe rows ZIP-TOOLONG and 7Z-TOOLONG (no crash; recorded)

## Phase 7: Polish & verification

- [ ] T012 `python tools/check_encoding.py --strict` -> TOTAL: 0
- [ ] T013 `.\build.cmd` -> BUILD SUCCEEDED; saltests -> 0 failed
- [ ] T014 Probes after: tar321_probe.ps1 (probe/result_after.txt), unp321_probe.ps1 (probe/unp_after.txt); regressions pax306_probe.ps1 and unp308_probe.ps1 (probe/regress_306.txt, probe/regress_308.txt)
- [ ] T015 Negative controls in a copy: (a) GNU flag not set; (b) + core NULL branch off; (c) the GNU refusal with the listing rule in every pass (`Listing` forced TRUE) -> the deep Unpack rows lose members (review-2 MUST reproduced)
- [ ] T016 fix-log.md complete (before / after, negative controls); CHANGELOG entry under `[0.1.11] — unreleased`, the 306 entry's "still crashes" sentence pointed at 321

## Dependencies

T001 -> T002/T003 -> T004 -> T005-T011 -> T012-T016. US1 and US2 share the tar change (T005/T006).

## Parallel opportunities

T002 and T003 (different files). Probes run one at a time (one program instance, shared registry key).

## Implementation strategy

MVP = US1 + US2 (the crash and the data-loss guard). US3 / US4 are carried code verified by saltests and rows.
