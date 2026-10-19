# Tasks: Desktop view column headers show the shell's names correctly

**Input**: Design documents from `specs/248-folders-column-names/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: no unit tests (research R4: no pure decision); the proof is the GUI probe
`probe/folders248_probe.ps1` plus the byte check in the fix log.

## Phase 1: Setup

- [X] T001 Record the measurement before (code sites, core readers of `CColumn::Name`, the cp1250 decoding of the UTF-8 names) in specs/248-folders-column-names/fix-log.md

## Phase 2: Foundational

- [X] T002 Run the probe specs/248-folders-column-names/probe/folders248_probe.ps1 with `-Expect before` on the unchanged build (negative control: COL2 / COL3 must FAIL; NAME and CELLS PASS), result to specs/248-folders-column-names/probe/result_before.txt; when another tandemcommander.exe runs, record NOT RUN in fix-log.md

## Phase 3: User Story 1 - Readable column headers in the Desktop view (Priority: P1) MVP

**Goal**: the shell's column names in the Desktop view's header read correctly in every Windows language.

**Independent Test**: probe rows NAME, COL2, COL3, CELLS, END PASS on a cs-CZ machine (quickstart.md step 3).

- [X] T003 [US1] In `CPluginDataInterface::GetShellColumns` convert the UTF-16 column name with `WideCharToMultiByte(CP_ACP, WC_NO_BEST_FIT_CHARS, ..., -1, col.Name, sizeof(col.Name), NULL, NULL)` instead of `SplWToU8`, leaving the name empty when the result is `<= 0`, with an English comment why (the core draws column names as code page) in src/plugins/folders/fs1.cpp
- [X] T004 [US1] State the encoding of `CShellColumn::Name` (Windows code page, as `CColumn::Name`) in its comment in src/plugins/folders/folders.h
- [X] T005 [US1] Build Debug x64 (`.\build.cmd`) and confirm `BUILD SUCCEEDED`; record in specs/248-folders-column-names/fix-log.md
- [X] T006 [US1] Run the probe with `-Expect fixed` on the new build, result to specs/248-folders-column-names/probe/result_after.txt (NAME, COL2, COL3, CELLS, END PASS - FR-001, FR-002, SC-001, SC-002); look at the saved header crop; record in fix-log.md (NOT RUN while another instance runs - then owed to a person)

## Phase 4: Polish & Cross-Cutting Concerns

- [X] T007 Run `python tools/check_encoding.py --strict` (expect `TOTAL: 0 finding(s)`) and record in specs/248-folders-column-names/fix-log.md
- [X] T008 Confirm the diff touches no file outside src/plugins/folders/ and the feature's records (SC-003): `git diff --stat main...248-folders-column-names -- src`

## Phase 5: Review round 1 (SHOULD 2, 3 - a name that does not fit)

- [X] T009 Write the header-only rule `SalWToCodePageWhole` (no best-fit, cut at a whole character, torn surrogate dropped, UTF-8 system code page) in src/common/salcpfit.h
- [X] T010 Use it in `GetShellColumns` in src/plugins/folders/fs1.cpp
- [X] T011 Add `TestCpFit248` to src/saltests/saltests.cpp; build; saltests 0 failed; negative control (best-fit allowed) must fail; record in specs/248-folders-column-names/fix-log.md
- [X] T012 Re-run the probe (`-Expect fixed`) on the final build, result to specs/248-folders-column-names/probe/result_after.txt

## Phase 6: Review round 2 (SHOULD 1 - checks that pin the rule)

- [X] T013 Add the pair-cut and ERROR_INVALID_FLAGS checks to `TestCpFit248` in src/saltests/saltests.cpp; negative controls (one-unit cut, no retry) must fail; record in specs/248-folders-column-names/fix-log.md

## Dependencies & Execution Order

T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008. T003 and T004 touch different files but
belong to one build; no parallel work worth splitting.

## Implementation Strategy

One story, one function: implement T003-T004, build, probe, check.
