# Tasks: Copying into an archive folder typed in another case packs into that folder

**Input**: `specs/383-arc-typed-target-case/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: requested by the spec (FR-008 saltests, SC-001..SC-004 probe rows).

## Phase 1: Setup

- [ ] T001 Record the measurement before (probe 22 / 10 at e3dfe127) and the enumerated `PackCompress` callers in specs/383-arc-typed-target-case/fix-log.md

## Phase 2: Foundational (blocks all stories)

- [ ] T002 Add the pure helper `SalArcPathApplyResolved(char* typed, const char* resolved)` with its header comment (feature 383) to src/common/salarcpathspell.h
- [ ] T003 Add `TestArcPathApplyResolved383` (leading / trailing backslash kept, length mismatch and empty input leave the typed root unchanged, an unchanged spelling returns FALSE, composed with `SalArcPathResolveCase` over the 382 fake listing for TYPED / DEEP / NEWTAIL / TWINEX / AMBIG) and call it from main in src/saltests/saltests.cpp

## Phase 3: User Story 1 - pack into the existing folder typed in another case (P1) - MVP

**Independent test**: probe rows TYPED, DEEP, MOVE, TWINS for 7Z and ZIP.

- [ ] T004 [US1] Add the static helper `RespellTypedArchiveRoot` (panel listing of the same unchanged archive, else - when the format's unpacker can list - `PackList` with the wait window; `ResolvePathCase` + `SalArcPathApplyResolved`; listing and plug-in data released as in src/salamdr3.cpp) in src/fileswn8.cpp
- [ ] T005 [US1] Call it in the archive branch of `CFilesWindow::FilesAction` after the zero-size test, only when `hasPath`, and pass the re-spelled copy to `PackCompress` (typed `path` / `secondPart` untouched) in src/fileswn8.cpp
- [ ] T006 [US1] Build (`.\build.cmd`) and run saltests (`build\tandemcommander\Debug_x64\saltests\saltests.exe`)

## Phase 4: User Story 2 - a new folder under an existing one (P2)

**Independent test**: probe row NEWTAIL for 7Z and ZIP.

- [ ] T007 [US2] Confirm by the probe row NEWTAIL that only the existing leading components are re-spelled (specs/383-arc-typed-target-case/probe/arctarget383_probe.ps1)

## Phase 5: User Story 3 - exact names, twins, ambiguity (P2)

**Independent test**: probe rows EXACT, TWINEX, AMBIG for 7Z and ZIP.

- [ ] T008 [US3] Add the row PANEL (right panel opened on the archive, typed `\DOCS\` - the panel's listing is reused) to specs/383-arc-typed-target-case/probe/arctarget383_probe.ps1, run the whole probe after the fix on the hidden desktop -> specs/383-arc-typed-target-case/probe/result_after.txt (PASS 36, FAIL 0)
- [ ] T009 [US3] Negative control: the call of T005 disabled in a copy of the tree (worktree under the scratchpad, own build folder) -> the probe fails again (10 FAIL); record in specs/383-arc-typed-target-case/fix-log.md

## Phase 6: Polish & cross-cutting

- [ ] T010 [P] Regression probes of 273 (specs/273-tar-case-root/probe/arccase273_probe.ps1, 12 / 0) and 382 (specs/382-arc-case-twins-path/probe/arctwins382_probe.ps1, 24 / 0)
- [ ] T011 [P] Encoding guard `python tools/check_encoding.py --strict` -> TOTAL: 0
- [ ] T012 Record after-measurements, commands and results in specs/383-arc-typed-target-case/fix-log.md

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 / T008 -> T009 -> T010 / T011 -> T012.
US2 and US3 need no code of their own: they are proven by the probe rows on the US1 code.

## Parallel opportunities

T010 and T011 (different tools, no shared files). Probes must not run at the same time (one
program instance, shared registry key).

## Implementation strategy

MVP = Phase 2 + US1 (the defect of the item); US2 / US3 are verification of the same change.
