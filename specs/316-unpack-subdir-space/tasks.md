# Tasks: Unpack never drops the leading space of a relative target

**Input**: Design documents from `specs/316-unpack-subdir-space/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: the project's acceptance evidence is the hidden-desktop probe (spec: "A probe row with
such an archive, before FAIL / after PASS"); probe tasks are included.

## Phase 1: Setup

- [X] T001 Start `specs/316-unpack-subdir-space/fix-log.md` with the measurement at b125acf7 (the probe command, 5 FAIL / 9 PASS, the cause) and the decisions of research.md R1-R2

## Phase 2: Foundational

- [X] T002 Update the probe `specs/316-unpack-subdir-space/probe/unpack316_probe.ps1` to the spec's acceptance: leading-space rows space-sd, space-sd-long, space2-sd, typed-space PASS = the "Error Creating Directory" box shown, nothing unpacked, no folder without the space created, an existing `ssss` untouched; add row space-sd-exists (a folder ` ssss` already next to ` ssss.zip`: files unpacked into it) and row space-file (a file ` ssss` next to the archive: refused, the file untouched); keep ctl-abs-space (refused), ctl-typed, ctl-blank
- [X] T003 Run the updated probe against the build of b125acf7 (negative control) into `specs/316-unpack-subdir-space/probe/result_before.txt`; the leading-space rows must FAIL (files in the folder without the space)

## Phase 3: User Story 1 - The offered subfolder is the folder used (Priority: P1) MVP

**Goal**: OK on an archive-name subfolder starting with a space uses that folder or refuses.
**Independent Test**: probe rows space-sd, space-sd-long, space2-sd, space-sd-exists PASS.

- [X] T004 [US1] In `src/fileswn7.cpp` `CFilesWindow::Unpack`, pass `allowRelPathWithSpaces = TRUE` to the `SalGetFullName` call after `CUnpackDialog` (with `NULL` callNethood and `MAX_PATH`, the size of `path`), with a feature-316 comment
- [X] T005 [US1] Build Debug x64 (`.\build.cmd`) - `BUILD SUCCEEDED`

## Phase 4: User Story 2 - A typed relative target keeps its space (Priority: P2)

**Goal**: a typed ` typed` is used or refused, never `typed`.
**Independent Test**: probe row typed-space PASS (same code path as T004 - no extra change).

- [X] T006 [US2] Run the probe on the new build into `specs/316-unpack-subdir-space/probe/result_after.txt` - every row PASS, registry restored and identical

## Phase 5: User Story 3 - Everything else unchanged (Priority: P3)

**Independent Test**: control rows PASS; 315's probe 11 / 0.

- [X] T007 [US3] Run 315's probe `specs/315-unpack-default-whole/probe/unpack315_probe.ps1` on the new build into `specs/316-unpack-subdir-space/probe/regress_315.txt` - 11 PASS / 0 FAIL

## Phase 6: Polish

- [X] T008 [P] `python tools/check_encoding.py --strict` - `TOTAL: 0 finding(s)`
- [X] T009 [P] `saltests.exe` - `0 failed`
- [X] T010 Record before / after, the commands and their results in `specs/316-unpack-subdir-space/fix-log.md`; record the out-of-scope finding (Pack and other `SalGetFullName` callers trim a relative name) and whether it goes to the Inbox

## Dependencies

T001 → T002 → T003 → T004 → T005 → T006, T007 → T008, T009 → T010. US2 and US3 depend on the US1
change (one call site serves all targets).

## Parallel Execution

T008 and T009 can run together; T006 and T007 run one after the other (the probes share the
registry key).

## Implementation Strategy

MVP = US1 (T004); US2 and US3 are verification of the same change.
