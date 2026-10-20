# Tasks: 7-Zip, TAR and SFTP listings declare case sensitivity

**Input**: `specs/252-archive-case-sensitivity/` (spec.md, plan.md, research.md, data-model.md,
contracts/case-twins.md, quickstart.md)
**Tests**: `saltests` checks of the pure rule (stop-rules §2.5) and the hidden-desktop probe.

## Phase 1: Setup

- [ ] T001 Start `specs/252-archive-case-sensitivity/fix-log.md` with the measurement by reading at 1cc16d0e
- [ ] T002 Write the probe `specs/252-archive-case-sensitivity/probe/arc252_probe.ps1` (rows TAR-/7Z- HIDE, GLOBAL, TREE, CONTROL; style of `specs/231-case-sensitive-reselect/probe/resel231_probe.ps1`, registry backup / restore, fixtures under %TEMP%)
- [ ] T003 Run the probe on the build of HEAD (before any change) -> `specs/252-archive-case-sensitivity/probe/result_before.txt`; record in fix-log.md

## Phase 2: Foundational

- [ ] T004 Create `src/common/salcasetwins.h` per `contracts/case-twins.md` (`SalCaseTwinName`, `SalNamesHaveCaseTwins`, `SalDirTreeHasCaseTwins<TDir>`; UTF-8-BOM, English comments)
- [ ] T005 Add the checks of the rule to `src/saltests/saltests.cpp` (ASCII twins, identical duplicates not twins, Unicode-only twins "C-caron"/"c-caron", legacy-only twins under the process code page, file vs folder twins, nested tree twins only in a sub-folder, empty tree, NULL sub-folder) and the `ClInclude` to `src/vcxproj/saltests/saltests.vcxproj`

## Phase 3: User Stories 1 + 2 + 4 - archives (P1)

**Goal**: 7-Zip and TAR listings with case twins are case-sensitive; without twins unchanged.
**Independent test**: probe rows HIDE / GLOBAL / TREE (fail before, pass after), CONTROL (pass both).

- [ ] T006 [US1] `src/plugins/7zip/7zclient.cpp` `C7zClient::ListArchive`: set `SALDIRFLAG_CASESENSITIVE` before the item loop, clear it after unless `SalDirTreeHasCaseTwins(dir)`; include `../../common/salcasetwins.h`
- [ ] T007 [P] [US1] `src/plugins/tar/tardll.cpp` `CPluginInterfaceForArchiver::ListArchive`: the same around `archive->ListArchive(NULL, dir)`; include the header

## Phase 4: User Story 3 - SFTP (P2)

- [ ] T008 [P] [US3] `src/plugins/sftp/fs.cpp`: `dir->SetFlags(SALDIRFLAG_CASESENSITIVE | SALDIRFLAG_IGNOREDUPDIRS)` with a comment (feature 252, as FTP)

## Phase 5: Polish & verification

- [ ] T009 `python tools/check_encoding.py --strict` -> TOTAL: 0; `.\build.cmd` -> BUILD SUCCEEDED; saltests -> 0 failed
- [ ] T010 Run the probe after the change -> `specs/252-archive-case-sensitivity/probe/result_after.txt`; record before / after in fix-log.md
- [ ] T011 Record NOT DRIVEN rows owed to a person (clipboard Paste route, SFTP) in fix-log.md

## Dependencies

T001-T003 before T004+ (measure first). T004 -> T005, T006, T007. T006/T007/T008 independent files.
T009 after T005-T008; T010 after T009.

## Implementation strategy

MVP = Phase 3 (archives); SFTP is a one-line declaration.
