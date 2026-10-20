# Implementation Plan: Backlog tool tests pass on a fresh checkout

**Branch**: `265-backlog-fixture-specs-folder` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/265-backlog-fixture-specs-folder/spec.md`

## Summary

The valid fixture of the backlog tool's tests needs the folder
`tools/backlog/fixtures/valid/specs/243-example/` (target of the `feature-missing` rule), but
the folder was empty and git never stored it, so 28 tests fail and 2 error on every checkout.
Commit the folder with a short `README.md` inside it that says why it exists, and say in
`tools/backlog/fixtures/README.md` how the folder is kept. No code changes: the check accepts
any content inside a `specs/NNN-*` folder (measured, research R1), and the `feature-missing`
seed deletes the folder with `shutil.rmtree`, file included.

## Technical Context

**Language/Version**: Python 3 (the backlog tool and its `unittest` suites); Markdown
**Primary Dependencies**: none (standard library only)
**Storage**: files in the repository (test fixture)
**Testing**: `python -m unittest tools/backlog/test_backlog.py`, `python -m unittest tools/backlog/test_loop.py`; fixture check `python tools/backlog/backlog.py --root tools/backlog/fixtures/valid check`
**Target Platform**: Windows 11 developer machine (Git Bash / Python)
**Project Type**: developer tooling (test fixture only)
**Performance Goals**: n/a
**Constraints**: `backlog.py` and the product unchanged (FR-006); `.gitattributes` `* text=auto` normalises the README's line endings, which the check ignores
**Scale/Scope**: one new file, one edited README

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status |
|---|---|
| I. Build reproducibility | Pass - no build input changes; the fix makes a test suite reproducible on any checkout |
| II. Backward compatibility | Pass - no product, registry, plug-in or file-format change |
| III. Incremental modernization | Pass - smallest possible change |
| IV. Windows commitment | Pass - not affected |
| V. Plugin architecture | Pass - not affected |
| VI. UI consistency | Pass - no UI |
| Release documentation | Pass - user-invisible developer tooling; no `CHANGELOG.md` entry |

Post-design re-check: unchanged, all pass.

## Project Structure

### Documentation (this feature)

```text
specs/265-backlog-fixture-specs-folder/
├── spec.md
├── plan.md
├── research.md
├── quickstart.md
├── fix-log.md
├── closing-report.md
└── tasks.md
```

No `data-model.md` (no entities) and no `contracts/` (no interface changes).

### Source Code (repository root)

```text
tools/backlog/fixtures/
├── README.md                              # edited: how specs/243-example/ is kept in git
└── valid/
    └── specs/
        └── 243-example/
            └── README.md                  # new: why the folder exists
```

**Structure Decision**: fixture files, plus the removal of the now redundant workaround in
`tools/backlog/test_loop.py` and `specs/247-backlog-run-loop/probe/e2e_real_claude.py`
(after review 1, FR-007); `tools/backlog/backlog.py` and `tools/backlog/test_backlog.py`
stay unchanged.

## Complexity Tracking

No violations.
