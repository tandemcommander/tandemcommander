# Tasks: Renamer "Include subdirectories" never descends into a junction or folder link

**Input**: Design documents from `specs/388-renamer-subdir-links/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: requested by the project rules - `saltests` checks for the pure rule (FR-006) and the
hidden-desktop probe `probe/ren_link_probe.ps1` (SC-001).

## Phase 1: Setup

- [ ] T001 Record the measurement before the change in specs/388-renamer-subdir-links/fix-log.md (probe result_before.txt, 6 FAIL / 8 PASS)

## Phase 2: Foundational (the rule, blocks every story)

- [ ] T002 Add `SalListedDirIsLink(DWORD listedAttr, BOOL tagRead, DWORD tag)` to src/common/salreparse.h per data-model.md (no reparse bit → FALSE; tag unread or 0 → TRUE; else `SalDeleteAsDirLinkDecision(FALSE, TRUE, tag)`)
- [ ] T003 Add `TestListedDirIsLink388` to src/saltests/saltests.cpp (plain dir, junction / mount point, symlink, LX symlink, unknown surrogate, cloud, OneDrive, dedup, WOF, tag 0 with the bit, tag unread, a file attribute set without the directory bit is not the rule's business) and call it from the test list
- [ ] T004 Give `CSourceFile(WIN32_FIND_DATAW&, const char*, const char*, int)` an `isDir` argument (default FALSE) in src/plugins/renamer/crenamer.h and src/plugins/renamer/crenamer.cpp: a folder has `Ext` at the end of its name and `IsDir = 1`

## Phase 3: User Story 1 - a link below the selected folder is listed, never walked (P1)

**Goal**: `LoadSubdir` lists a link (mask matched as a folder) and does not enumerate it.
**Independent test**: probe rows `out`, `loop`, `symlink`, `mask`, `rename`.

- [ ] T005 [US1] In `CRenamerDialog::LoadSubdir` (src/plugins/renamer/rendlg.cpp) branch a found directory on `SalListedDirIsLink(fd.dwFileAttributes, TRUE, fd.dwReserved0)`: a link matching `AgreeMasks(fileName, NULL)` is added as a folder item (`new CSourceFile(fd, fileName, path, pathLen, TRUE)`, the existing `NameLen < MAX_PATH` refusal with `IDS_TOOLONGPATH`), never passed to `LoadSubdir`
- [ ] T006 [US1] In `CRenamerDialog::ReloadSourceFiles` (src/plugins/renamer/rendlg.cpp) count the folders of the count line from the listed items (`IsDir`) after the listing, so links added by `LoadSubdir` count as folders

## Phase 4: User Story 2 - a selected link is an item (P2)

**Goal**: a selected / focused panel folder that is a link is listed, not walked.
**Independent test**: probe row `selected`.

- [ ] T007 [US2] Add a helper in src/plugins/renamer/rendlg.cpp that, for a selected folder whose `Attr` has `FILE_ATTRIBUTE_REPARSE_POINT`, looks up its own entry (`FindFirstFileW` on `SplU8ToWExtAlloc(FullName)`) and returns `SalListedDirIsLink(...)` (look-up failed → `tagRead` FALSE → a link); without the bit it returns FALSE with no system call
- [ ] T008 [US2] In `ReloadSourceFiles` walk a selected folder only when the helper says it is not a link; a link goes the non-recursive branch (mask, added as a folder item)

## Phase 5: User Story 3 - plain and non-link reparse folders keep being walked (P3)

**Goal**: no regression for plain folders, cloud placeholders, dedup folders.
**Independent test**: probe row `plain`; the saltests rows for cloud / OneDrive / dedup / WOF.

- [ ] T009 [US3] Confirm by reading that a directory without the reparse bit and one with a non-surrogate tag still reach `LoadSubdir` unchanged (src/plugins/renamer/rendlg.cpp) and record it in specs/388-renamer-subdir-links/fix-log.md

## Phase 6: Polish & verification

- [ ] T010 `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`
- [ ] T011 `.\build.cmd` → `BUILD SUCCEEDED`
- [ ] T012 `saltests.exe` → `0 failed` (the new checks included)
- [ ] T013 Negative control: the new saltests checks fail against a rule that ignores the tag (temporary local edit in a scratch copy, never committed) - record the result in fix-log.md
- [ ] T014 Probe after the change → specs/388-renamer-subdir-links/probe/result_after.txt, every row PASS (or `symlink` NOT DRIVEN with the reason)
- [ ] T015 Regression probes of the area: specs/209-renamer-subdir-reload/probe/ren_subdir_probe.ps1 → specs/388-renamer-subdir-links/probe/regress_209.txt
- [ ] T016 Update specs/388-renamer-subdir-links/fix-log.md with after-measurements, commands and results

## Dependencies

- T002 → T003; T002, T004 → T005 → T006; T002 → T007 → T008; T005–T008 → T009 → T010–T016.
- US1 and US2 touch the same file (rendlg.cpp): sequential.

## Parallel opportunities

- T003 [saltests] and T004 [renamer constructor] are independent once T002 is written.
- T014 and T015 run one after the other (the hidden desktop runs one program instance at a time).

## Implementation strategy

MVP = Phase 2 + US1 (the defect of the item). US2 closes the same descent one level up; US3 is
the regression guard. One build, one probe run of all rows.
