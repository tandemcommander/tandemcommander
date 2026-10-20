# Tasks: Backlog tool tests pass on a fresh checkout

**Input**: Design documents from `specs/265-backlog-fixture-specs-folder/`
**Prerequisites**: plan.md, spec.md, research.md, quickstart.md

**Tests**: no new tests - the existing suites `tools/backlog/test_backlog.py` and
`tools/backlog/test_loop.py` are the acceptance tests (FR-003); the negative control is
quickstart step 4.

## Phase 1: Setup

- [ ] T001 Start `specs/265-backlog-fixture-specs-folder/fix-log.md` with the measurement before the fix (fixture `check` -> `TOTAL: 1` `feature-missing`; `test_backlog.py` 68 tests, 28 failures, 2 errors at `6085500d`)

## Phase 2: Foundational

None - no blocking prerequisites.

## Phase 3: User Story 1 - The backlog tool's tests pass on a fresh checkout (Priority: P1) 🎯 MVP

**Goal**: the fixture folder `specs/243-example/` is in git, so the valid fixture is clean and the suites pass on any checkout.

**Independent Test**: quickstart steps 1-3 in a fresh clone of the branch.

- [ ] T002 [US1] Create `tools/backlog/fixtures/valid/specs/243-example/README.md`: a short English note (UTF-8) saying the folder is the target of the `feature-missing` rule for the fixture's in-progress item of feature 243, that the file exists only so git keeps the folder, and that the `feature-missing` seed in `tools/backlog/test_backlog.py` deletes the folder (FR-001)
- [ ] T003 [US1] Edit `tools/backlog/fixtures/README.md`: where it lists `specs/243-example/`, add that the folder is kept in git by its `README.md` (git stores no empty folders; feature 265) (FR-005)
- [ ] T004 [US1] Run `python tools/backlog/backlog.py --root tools/backlog/fixtures/valid check` -> `TOTAL: 0` (FR-002); record in `specs/265-backlog-fixture-specs-folder/fix-log.md`
- [ ] T005 [US1] Run `python -m unittest tools/backlog/test_backlog.py` and `python -m unittest tools/backlog/test_loop.py` -> both `OK`; confirm the `feature-missing` seed test passes (FR-003, FR-004); record in `specs/265-backlog-fixture-specs-folder/fix-log.md`

## Phase 4: Polish & Cross-Cutting Concerns

- [ ] T006 Commit the fixture files, then in a fresh clone of the branch (`git clone` into `%TEMP%`) run quickstart steps 1-2 (SC-001, SC-002) and the negative control of step 4 (delete the folder -> failures return, SC-003); record in `specs/265-backlog-fixture-specs-folder/fix-log.md`, delete the clone
- [ ] T007 Run `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; confirm `git diff main...HEAD --stat` touches no file of `tools/backlog/*.py` or the product (FR-006); record in `specs/265-backlog-fixture-specs-folder/fix-log.md`

## Dependencies & Execution Order

- T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 (T002 and T003 touch different files and could run in parallel, but both are tiny).
- One user story; it is the MVP and the whole feature.

## Parallel Example

```text
T002 (new fixture README) and T003 (fixtures/README.md) - different files.
```

## Implementation Strategy

Single increment: add the file, verify with the existing suites in the working tree and in a
fresh clone, prove the dependency with the negative control.
