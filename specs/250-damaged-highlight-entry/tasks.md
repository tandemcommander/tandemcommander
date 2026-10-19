---
description: "Task list for 250-damaged-highlight-entry"
---

# Tasks: A damaged highlighting entry no longer hangs the start-up

**Input**: `specs/250-damaged-highlight-entry/` - plan.md, spec.md, research.md, data-model.md, quickstart.md
**Tests**: the hidden-desktop probe `probe/hlt250_probe.ps1` (measure-first rule of the project).

## Phase 1: Setup

- [X] T001 Write the probe specs/250-damaged-highlight-entry/probe/hlt250_probe.ps1 (rows CONTROL, NOMASKS, MIDDLE, EMPTYKEY, WRONGTYPE, LONG; registry backup / restore / verify)
- [X] T002 Run the probe on the HEAD build and record specs/250-damaged-highlight-entry/probe/result_before.txt and the measurement in specs/250-damaged-highlight-entry/fix-log.md

## Phase 2: Foundational

None - the change is one loop.

## Phase 3: User Story 1 - The program starts with a damaged highlighting entry (P1)

**Goal**: every round of the highlighting-list loop advances and closes its key; a damaged entry is
skipped once (FR-001 - FR-006).
**Independent test**: the probe - the five damaged rows start, show at most one box, save the good
entries in order; CONTROL unchanged.

- [ ] T003 [US1] In src/mainwnd2.cpp, CMainWindow::LoadConfig, the "load colors for file highlighting" loop: move `itoa(++i, buf, 10)` and `CloseKey(hSubKey)` to the end of every round; replace the low-memory `continue` so that path also reaches them; keep the body for a readable Masks value unchanged; a short English comment naming feature 250
- [ ] T004 [US1] Build Debug x64 with `.\build.cmd` (PowerShell) - BUILD SUCCEEDED
- [ ] T005 [US1] Run the probe on the new build, record specs/250-damaged-highlight-entry/probe/result_after.txt (expected PASS 18, FAIL 0) and the result in specs/250-damaged-highlight-entry/fix-log.md

## Phase 4: Polish & cross-cutting

- [ ] T006 Run `python tools/check_encoding.py --strict` (TOTAL: 0 finding(s)) and saltests (`build\tandemcommander\Debug_x64\saltests\saltests.exe`, 0 failed)
- [ ] T007 Record the settings-import mismatch (feature 245's import ends its highlighting list at a damaged entry; the loader now skips it) as an Inbox item via `BL new` (source measure:250)

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006; T007 independent.

## Parallel opportunities

T007 can run beside T003-T006 (backlog only).

## Implementation strategy

MVP = User Story 1 (the only story): T003-T005.
