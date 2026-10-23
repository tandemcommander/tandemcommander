# Tasks: Pack never drops the leading space of a relative archive name

**Input**: Design documents from `specs/317-pack-name-space/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: the project's acceptance evidence is the hidden-desktop probe (item: "A probe row with
such a name, before FAIL / after PASS"); probe tasks are included.

## Phase 1: Setup

- [X] T001 Start `specs/317-pack-name-space/fix-log.md` with the measurement at d526127f (the scratch probe command, 7 FAIL / 11 PASS, the cause) and the decisions of research.md R1-R4

## Phase 2: Foundational

- [X] T002 Put the probe into `specs/317-pack-name-space/probe/pack317_probe.ps1` (from the scratch measurement probe) updated to the spec: row ctl-blank becomes typed-spaces-only (the entry `   ` -> `   .zip`, spec Clarifications); add row ctl-empty (the entry empty: refused with a message, nothing created) and rows typed-space-dots (` ..`) and typed-space-dot (` .`) (spec FR-004: no new file, no file changed); add rows space-add (folder ` report`, an existing ` report.zip` holding seed.txt: the question names ` report.zip`, Add puts the folder into it) and space-over (the same, Overwrite: ` report.zip` replaced, seed.txt gone, no aside left) (spec FR-002); keep the other rows
- [X] T003 Run the probe against the build of d526127f (negative control) into `specs/317-pack-name-space/probe/result_before.txt`; the leading-space rows must FAIL (archive without the space; `report.zip` asked about and changed)

## Phase 3: User Story 1 - The offered archive name is the archive written (Priority: P1) MVP

**Goal**: OK on an offered name starting with a space writes that archive.
**Independent Test**: probe rows space-dir, space-dir-exists, space-file, space2-dir PASS.

- [X] T004 [US1] In `src/fileswn7.cpp` `CFilesWindow::Pack`, pass `allowRelPathWithSpaces = TRUE` to the `SalGetFullName` call after `CPackDialog` (`NULL` callNethood, `MAX_PATH` = the size of `fileBuf`), with a feature-317 comment; after the first after-run (research R4: ` ..` / ` .` created literal files) also refuse a name whose last part is only spaces and dots through the existing error path (`IDS_PATHISINVALID`), the rule `SalPackNameIsOnlyDotsAndSpaces` in `src/common/salpackname.h` with checks `TestPackName317` in `src/saltests/saltests.cpp` (header listed in `src/vcxproj/saltests/saltests.vcxproj`)
- [X] T005 [US1] Build Debug x64 (`.\build.cmd`) - `BUILD SUCCEEDED`

## Phase 4: User Story 2 - A typed relative archive name keeps its space (Priority: P2)

**Goal**: a typed ` typed.zip` / ` typed` writes ` typed.zip`, never `typed.zip`.
**Independent Test**: probe rows typed-space, typed-space-noext PASS (same code path as T004).

- [X] T006 [US2] Run the probe on the new build into `specs/317-pack-name-space/probe/result_after.txt` - every row PASS, registry restored and identical

## Phase 5: User Story 3 - Everything else unchanged (Priority: P3)

**Independent Test**: control rows PASS before and after; 316's and 241's probes unchanged.

- [X] T007 [US3] Run 316's probe `specs/316-unpack-subdir-space/probe/unpack316_probe.ps1` on the new build into `specs/317-pack-name-space/probe/regress_316.txt` - 18 PASS / 0 FAIL
- [X] T008 [US3] Run 241's probe `specs/241-pack-long-nested-folder/probe/pack241_probe.ps1` on the new build into `specs/317-pack-name-space/probe/regress_241.txt` - no FAIL

## Phase 6: Polish

- [X] T009 [P] `python tools/check_encoding.py --strict` - `TOTAL: 0 finding(s)`
- [X] T010 [P] `saltests.exe` - `0 failed`
- [X] T011 Record before / after, the commands and their results in `specs/317-pack-name-space/fix-log.md`; record out-of-scope findings and whether they go to the Inbox

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008 -> T009, T010 -> T011. US2 and US3
depend on the US1 change (one call site serves all names).

## Parallel Execution

T009 and T010 can run together; the probes (T006-T008) run one after the other (they share the
registry key).

## Implementation Strategy

MVP = US1 (T004); US2 and US3 are verification of the same change.
