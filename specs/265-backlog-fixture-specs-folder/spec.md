# Feature Specification: Backlog tool tests pass on a fresh checkout

**Feature Branch**: `265-backlog-fixture-specs-folder`
**Created**: 2026-10-20
**Status**: Draft
**Input**: Backlog item backlog-fixture-empty-specs-folder-missing - "Backlog tool tests fail on a fresh checkout: the fixture folder specs/243-example is not in git". From backlog item backlog-fixture-empty-specs-folder-missing.

## Background (measured at 6085500d)

The valid backlog fixture of the backlog tool's tests (`tools/backlog/fixtures/valid/`)
holds an in-progress item of feature 243; the consistency check requires a folder
`specs/243-*` for it. The fixture's README and feature 242's task T010 say the fixture
contains `specs/243-example/`, but the folder was empty, and git does not store empty
folders, so no checkout has it.

Measured at `6085500d` on the maintainer's machine:

- `python tools/backlog/backlog.py --root tools/backlog/fixtures/valid check` →
  `feature-missing: no folder specs/243-* for the in-progress feature`, `TOTAL: 1`.
- `python -m unittest tools/backlog/test_backlog.py` → `Ran 68 tests`,
  `FAILED (failures=28, errors=2)`.
- `tools/backlog/fixtures/valid/specs/` does not exist in the working tree;
  `git ls-tree -r HEAD tools/backlog/fixtures` lists nothing under `valid/specs/`.
- `tools/backlog/test_loop.py` (feature 247) creates `specs/243-example/README.md` itself in
  its temporary repository as a workaround.

## Clarifications

### Session 2026-10-20

- Q: Should the workaround in `tools/backlog/test_loop.py` (it creates `specs/243-example/README.md` in its temporary copy) be removed now that the folder is committed? → A: Yes - revised after review 1: the same workaround in the 247 end-to-end probe (`specs/247-backlog-run-loop/probe/e2e_real_claude.py`, `mkdir` without `exist_ok`) crashes with `FileExistsError` once the folder is in the fixture, and the comment in `test_loop.py` would become false; both workarounds are removed so every consumer takes the folder from the fixture (autonomous run: conservative - first answer "keep it" withdrawn because it broke a caller)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The backlog tool's tests pass on a fresh checkout (Priority: P1)

A maintainer or an agent clones the repository (or works in a checkout that never had the
folder created by hand) and runs the backlog tool's test suite before or after changing the
tool. All tests pass, so a failure means a real defect of the tool, not a missing fixture.

**Why this priority**: It is the whole item; today 30 of 68 tests fail for a reason that has
nothing to do with the tool, which hides real regressions.

**Independent Test**: In a fresh clone of the branch, run the valid fixture's check and the
test suite.

**Acceptance Scenarios**:

1. **Given** a fresh checkout, **When** the consistency check runs on the valid fixture,
   **Then** it reports no finding (`TOTAL: 0`).
2. **Given** a fresh checkout, **When** the backlog tool's test suite runs, **Then** all its
   tests pass.
3. **Given** the fixture with its feature folder present, **When** the seeded
   `feature-missing` defect is applied (the folder is deleted in the test's copy), **Then**
   the check reports exactly the `feature-missing` finding, as before.

### Edge Cases

- The file that keeps the folder in git must not itself make the check report anything
  (the check accepts any content inside a `specs/NNN-*` folder).
- The seeded `feature-missing` defect must still remove the whole folder, file included, so
  the negative case keeps failing the check.
- The loop tool's tests and its end-to-end probe (feature 247), which created the folder
  with a file in their own temporary copy, must keep working once the folder comes from the
  fixture.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The repository MUST contain the fixture folder
  `tools/backlog/fixtures/valid/specs/243-example/`, kept in git by a short `README.md`
  inside it that says why the folder exists.
- **FR-002**: The consistency check of the valid fixture MUST report `TOTAL: 0` on a fresh
  checkout.
- **FR-003**: The backlog tool's test suite (`tools/backlog/test_backlog.py`) MUST pass on a
  fresh checkout; the loop tool's suite (`tools/backlog/test_loop.py`) MUST keep passing.
- **FR-004**: The seeded `feature-missing` defect MUST still delete the folder and MUST
  still be detected by the check.
- **FR-005**: The fixture description (`tools/backlog/fixtures/README.md`) MUST say how the
  folder is kept in git.
- **FR-006**: The backlog tool itself (`tools/backlog/backlog.py`) and the product MUST NOT
  change.
- **FR-007**: The consumers that created the folder themselves (`tools/backlog/test_loop.py`
  and `specs/247-backlog-run-loop/probe/e2e_real_claude.py`) MUST take it from the fixture
  instead; the probe's repository set-up MUST no longer fail.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a fresh clone, the backlog tool's test suite reports 0 failures and 0
  errors (before: 28 failures and 2 errors of 68 tests).
- **SC-002**: In a fresh clone, the valid fixture's check reports 0 findings (before: 1).
- **SC-003**: Deleting the fixture folder again (negative control) brings the failures back,
  showing the tests depend on the committed folder.

## Assumptions

- Assumption (autonomous run): the folder is kept by a `README.md` (the item's own example)
  rather than a `.gitkeep`, so it explains itself.
- Assumption (autonomous run): no product code, build or UI string changes; the change is
  user-invisible, so no `CHANGELOG.md` entry.
