---
description: "Task list for 268-damaged-list-entries"
---

# Tasks: A damaged viewer, editor or User Menu entry no longer erases the entries after it

**Input**: `specs/268-damaged-list-entries/` - plan.md, spec.md, research.md, data-model.md, quickstart.md
**Tests**: the hidden-desktop probe `probe/dmg268_probe.ps1` (measure-first rule of the project).

## Phase 1: Setup

- [X] T001 Write the probe specs/268-damaged-list-entries/probe/dmg268_probe.ps1 (cases V-CONTROL, V-NOTYPE, V-PIPE, V-NOMASKS, AV-NOTYPE, E-CONTROL, E-NOMASKS, E-WRONGTYPE, E-MULTI, U-CONTROL, U-NONAME, U-WRONGTYPE; START / END / KEYS / SAVED rows; registry backup / restore / verify)
- [X] T002 Run the probe on the HEAD build and record specs/268-damaged-list-entries/probe/result_before.txt and the measurement in specs/268-damaged-list-entries/fix-log.md

## Phase 2: Foundational

None - the change is three loops.

## Phase 3: User Story 1 - A damaged entry costs only itself (P1)

**Goal**: a damaged entry of the viewers, alternative viewers, editors or User Menu list is closed and
skipped; the entries after it are loaded; every opened entry key is closed, also on the low-memory
paths (FR-001 - FR-006).
**Independent test**: the probe - the nine damaged rows save the good entries in order, no row reports
a handle left open, the wrong-type rows show at most one box; the CONTROL rows unchanged.

- [ ] T003 [P] [US1] In src/salamdr2.cpp, LoadViewers and LoadEditors: remove the `else break;` after the required-value test so a damaged entry reaches `itoa(++i, buf, 10)` and `CloseKey(subKey)`; add `CloseKey(subKey)` before each low-memory `break` (item not created / not added); keep the body for a readable entry unchanged; a short English comment naming feature 268
- [ ] T004 [P] [US1] In src/mainwnd2.cpp, CMainWindow::LoadConfig, the User Menu loop: the same change (remove `else break;`, close the key before the two low-memory `break`s, comment naming feature 268)
- [ ] T005 [US1] Build Debug x64 with `.\build.cmd` (PowerShell) - BUILD SUCCEEDED
- [ ] T006 [US1] Run the probe on the new build (quickstart.md), record specs/268-damaged-list-entries/probe/result_after.txt (expected PASS 48, FAIL 0, registry restored identical) and the result in specs/268-damaged-list-entries/fix-log.md

## Phase 4: Polish & cross-cutting

- [ ] T007 Run `python tools/check_encoding.py --strict` (TOTAL: 0 finding(s)) and saltests (`build\tandemcommander\Debug_x64\saltests\saltests.exe`, 0 failed); record in specs/268-damaged-list-entries/fix-log.md
- [ ] T008 Check clang-format on the edited lines of src/salamdr2.cpp and src/mainwnd2.cpp (no change expected)

## Dependencies

T001 -> T002 -> (T003, T004) -> T005 -> T006 -> T007; T008 after T003 / T004.

## Parallel opportunities

T003 and T004 edit different files.

## Implementation strategy

MVP = User Story 1 (the only story): T003-T006.
