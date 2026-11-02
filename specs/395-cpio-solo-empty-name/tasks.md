# Tasks: Unpack reports a file whose only name normalizes to empty

**Input**: `specs/395-cpio-solo-empty-name/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: saltests checks for the pure rule (project rule: pure decisions get saltests) and the
hidden-desktop probe `probe/cpiosolo_probe.ps1` (measured before at bb8aa693).

## Phase 1: Setup

- [ ] T001 Record the before measurement and the probe in specs/395-cpio-solo-empty-name/fix-log.md and specs/395-cpio-solo-empty-name/probe/ (result_before.txt, cpiosolo_probe.ps1, mkcpiosolo.py)

## Phase 2: Foundational

- [ ] T002 Add `SAL_EMPTY_NAME_*`, `SalEmptyNameDataDecide` and `SalEmptyNamePendingCleared` to src/common/salcpiolink.h (research R4)
- [ ] T003 Add saltests checks `TestEmptyNameData395` for both rules in src/saltests/saltests.cpp
- [ ] T004 Add `SCommonHeader::NameEmptyRegular`, `SCpioGroup::EmptyLost` / `EmptyLostName`, `CArchive::EmptyNameShown`, declarations `ReportEmptyName` / `ReportCpioEmptyLost` and the extra `emptyAsked` parameter of `WriteOutCpioGroupMember` in src/plugins/tar/tar.h; reset `NameEmptyRegular` in `SCommonHeader::Initialize` and `EmptyNameShown` in the `CArchive` constructor in src/plugins/tar/untar.cpp

## Phase 3: User Story 1 - a whole Unpack never deletes an archive whose file data stayed inside (P1)

**Independent test**: the 9 data rows of the probe - "(123)" box, archive kept.

- [ ] T005 [US1] In `ReadArchiveHeader`'s "skip invalid names" branch set `NameEmptyRegular` (cpio: mode is a regular file; tar: the member was a regular file - not Ignored, not a folder, no link type - before the branch) in src/plugins/tar/untar.cpp
- [ ] T006 [US1] Implement `ReportEmptyName` (system text `ERROR_INVALID_NAME`, the raw name in quotes, once per operation) in src/plugins/tar/untar.cpp
- [ ] T007 [US1] In `DoUnpackArchive` compute `emptyAsked` (raw `IsNamePresent` before 394's `found = FALSE`, `NameEmptyRegular`); a non-group member: `SalEmptyNameDataDecide` -> REPORT -> `ReportEmptyName`, `refused = TRUE` in src/plugins/tar/untar.cpp
- [ ] T008 [US1] In `WriteOutCpioGroupMember` take `emptyAsked`: before acting, `SalEmptyNameDataDecide` -> PENDING marks the group (`EmptyLost`, `EmptyLostName`); after a `WRITE` / `COPY` / `REPORT` action `SalEmptyNamePendingCleared` clears the mark, in src/plugins/tar/untar.cpp
- [ ] T009 [US1] Implement `ReportCpioEmptyLost` (a pending group -> `ReportEmptyName`, `refused = TRUE`) and call it at both ends of `DoUnpackArchive` (TAR_EOF and the trailer) in src/plugins/tar/untar.cpp

## Phase 4: User Story 2 - harmless empty-named members stay silent (P2)

**Independent test**: the 7 control rows of the probe.

- [ ] T010 [US2] Verify the controls stay silent (folder, size 0, 394's waiting name, mask `*.txt`, Copy of the listing) - probe run after T005-T009, specs/395-cpio-solo-empty-name/probe/result_after.txt

## Phase 5: Polish

- [ ] T011 `.\build.cmd` -> BUILD SUCCEEDED; saltests 0 failed; `python tools/check_encoding.py --strict` TOTAL 0 - recorded in specs/395-cpio-solo-empty-name/fix-log.md
- [ ] T012 Negative control: the T007 / T009 report calls removed temporarily, rebuilt, probe rows fail, restored (`git checkout HEAD -- src/plugins/tar/untar.cpp`), rebuilt - specs/395-cpio-solo-empty-name/probe/result_negctl.txt
- [ ] T013 Regression probes 306, 308, 309, 310, 321 (tar, unpack), 393, 394 on the branch build - specs/395-cpio-solo-empty-name/probe/regress_*.txt

## Dependencies

T001 -> T002 -> T003; T004 -> T005 -> T006 -> T007 -> T008 -> T009 -> T010 -> T011 -> T012 -> T013.
T002 / T004 may be done in parallel (different files). US2 has no code of its own: it checks that US1
changed nothing else.

## Implementation strategy

MVP = US1 (the data-loss rows); US2 is its regression guard, run in the same probe.
