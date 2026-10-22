# Tasks: The Unpack dialog never offers a default target path or mask cut

**Input**: Design documents from `specs/315-unpack-default-whole/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/salunpackdefault.md, quickstart.md

**Tests**: requested by the spec (SC-001 probe, SC-002 saltests, SC-003 regression).

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [ ] T001 Start `specs/315-unpack-default-whole/fix-log.md` with the before measurement (probe result_before.txt / result_before_src.txt: 6 FAIL, 3 controls PASS), the sites and the enumerated consumers of plan.md

## Phase 2: Foundational (the pure rule)

- [ ] T002 Create `src/common/salunpackdefault.h` with `SalUnpackDefaultCopy` and `SalUnpackDefaultAddSubdir` per `contracts/salunpackdefault.md` (UTF-8-BOM, SPDX header in the style of `src/common/salumvalue.h`)
- [ ] T003 Add the header to `src/vcxproj/saltests/saltests.vcxproj` (ClInclude, and `.filters` if it lists headers) and `#include` it in `src/saltests/saltests.cpp`
- [ ] T004 Add saltests rows in `src/saltests/saltests.cpp`: copy whole at 259 bytes, empty at 260, CJK text whole / empty (no partial letter), NULL / size 0; subfolder appended with and without a trailing backslash, empty buffer gives the name alone, result of 259 bytes appended, 260 bytes empties the entry, nameLen 0 leaves it unchanged; mask whole or FALSE; never a prefix left in the buffer. Run once with a cut (lstrcpyn-like) copy as negative control and record the failures in fix-log.md

## Phase 3: User Story 1 - the other panel's long path is never offered cut (P1)

**Independent test**: probe rows other-ascii, other-cjk, alt-ascii, alt-cjk; control ctl, ctl-alt

- [ ] T005 [US1] In `CFilesWindow::Unpack` (`src/fileswn7.cpp`) replace the two `lstrcpyn(..., target->GetPath(), MAX_PATH)` with `SalUnpackDefaultCopy` (left out when it does not fit, `TRACE_I`), include `salunpackdefault.h`, update the feature-011 comment

## Phase 4: User Story 2 - the archive subfolder is never dropped silently (P2)

**Independent test**: probe row subdir; control ctl-subdir

- [ ] T006 [US2] In `CFilesWindow::Unpack` (`src/fileswn7.cpp`) replace the subfolder append loop body with `SalUnpackDefaultAddSubdir(buff, MAX_PATH, fileName, nameLen)` (the entry emptied when it does not fit)

## Phase 5: User Story 3 - the empty target never becomes a cut archive folder (P1)

**Independent test**: probe row src-long

- [ ] T007 [US3] In `CFilesWindow::Unpack` (`src/fileswn7.cpp`) replace `lstrcpyn(path, GetPath(), MAX_PATH)` of the `IDS_EMPTYNAMENOTALLOWED` branch with `SalUnpackDefaultCopy`; FALSE -> `text = LoadStr(IDS_TOOLONGPATH)` (the existing message box and `goto DO_AGAIN`)

## Phase 6: User Story 4 - a plug-in's long mask is never offered cut (P3)

**Independent test**: saltests rows (no plug-in passes a mask)

- [ ] T008 [US4] In `CFilesWindow::Unpack` (`src/fileswn7.cpp`) replace `lstrcpyn(mask, unpackMask, MAX_PATH)` with `SalUnpackDefaultCopy`; FALSE -> `strcpy(mask, "*.*")` with `TRACE_E`

## Phase 7: Polish & verification

- [ ] T009 Update the probe header (`specs/315-unpack-default-whole/probe/unpack315_probe.ps1` .DESCRIPTION: the src-long row) and its default `-Lib` path
- [ ] T010 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [ ] T011 `.\build.cmd` -> `BUILD SUCCEEDED`; `saltests.exe` -> `0 failed` (record the count)
- [ ] T012 Probe after (hidden desktop, quickstart step 3) -> every row PASS; save `probe/result_after.txt`
- [ ] T013 Regression: 299's `unpack299_probe.ps1` -> 12 / 0; save `probe/regress_299.txt`
- [ ] T014 Record before / after, commands and results in `specs/315-unpack-default-whole/fix-log.md`

## Dependencies

T001 -> T002 -> T003 -> T004; T005..T008 need T002 (same file: sequential); T009..T014 after T005..T008.

## Parallel execution

T009 (probe text) can run beside T005..T008 (different files). The four code sites share one file:
sequential.

## Implementation strategy

MVP = T002, T005, T007 (US1 + US3: no cut target path offered or used). Then US2, US4, polish.
