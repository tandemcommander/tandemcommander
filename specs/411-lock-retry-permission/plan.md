# Implementation Plan: Run lock update and release survive a reader holding the lock open

**Branch**: `411-lock-retry-permission` | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/411-lock-retry-permission/spec.md`

## Summary

`bin/backlog.sh lock update` / `lock release` (`tools/backlog/backlog.py` `cmd_lock`) fail with
a traceback when another process has the run lock open (Windows: WinError 5 on the replace,
WinError 32 on the delete; measured at b5bb8329). One small retry helper in `backlog.py` wraps
every file operation of `cmd_lock` - create (acquire), read (all four actions), replace (update),
delete (release) - retrying `PermissionError` 40 times at 50 ms, the window of
`traces.write_json_atomic` (342). A persistent failure raises `Refused` (one `refused:` line,
exit 1, nothing changed). A lock gone between check and read is "no lock". Tests hold the lock
open from a second process.

## Technical Context

**Language/Version**: Python 3.14 (the repository's tool Python; `backlog.py` targets 3.10+ syntax)
**Primary Dependencies**: standard library only (`os`, `time`, `tempfile`, `subprocess` in tests)
**Storage**: the file `.git/tandem-backlog-run.lock` (four `key: value` lines)
**Testing**: `python -m unittest tools/backlog/test_backlog.py` (plus `test_loop.py`, `test_traces.py` unchanged)
**Target Platform**: Windows 11 (the sharing semantics that cause the defect are Windows'); the tool also runs elsewhere
**Project Type**: developer CLI tool (backlog tooling, feature 242 / 247 / 344)
**Performance Goals**: no added delay without a reader; at most about 2 s of waiting with one
**Constraints**: output and exit codes unchanged in the uncontended case; nothing half-written
**Scale/Scope**: one function (`cmd_lock`) and one helper in `tools/backlog/backlog.py`; tests in `tools/backlog/test_backlog.py`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check |
|---|---|
| I. Build reproducibility | not touched: no build input changes |
| II. Backward compatibility | the lock file format, the commands' arguments, outputs and exit codes stay; only a former traceback becomes a `refused:` line - PASS |
| III. Incremental modernization | a local fix in one function, following the pattern of 342 - PASS |
| IV. Windows commitment | fixes a Windows-specific failure; tests are Windows tests - PASS |
| V. Plugin architecture | not touched |
| VI. UI consistency | not touched (no product UI; no UI strings, no translations) |

No violations. Post-design re-check: unchanged (PASS).

## Project Structure

### Documentation (this feature)

```text
specs/411-lock-retry-permission/
├── spec.md
├── plan.md              # this file
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/lock-commands.md
├── fix-log.md
└── tasks.md
```

### Source Code (repository root)

```text
tools/backlog/
├── backlog.py           # cmd_lock + new helpers lock_retry / lock_fields; constants LOCK_RETRY_*
└── test_backlog.py      # new class LockHeldOpenTests (Windows)
```

**Structure Decision**: change only `tools/backlog/backlog.py` and its tests. `tools/backlog/loop.py`
already retries its own lock reads (`Repo.lock`) and is not changed; the backlog app calls the
tool and gains the fix through it.

## Complexity Tracking

None.
