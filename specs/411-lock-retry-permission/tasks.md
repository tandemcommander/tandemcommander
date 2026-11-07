# Tasks: Run lock update and release survive a reader holding the lock open

**Input**: `specs/411-lock-retry-permission/` (spec.md, plan.md, research.md, data-model.md, contracts/lock-commands.md, quickstart.md)
**Tests**: requested by the spec (FR-007).

## Phase 1: Setup

- [X] T001 Record the measurement at b5bb8329 (command, output, WinError 5 / 32, lock kept) in specs/411-lock-retry-permission/fix-log.md, section *Before*

## Phase 2: Foundational

- [X] T002 Add `import time`, the constants `LOCK_RETRY_ATTEMPTS = 40` / `LOCK_RETRY_DELAY = 0.05` and the helper `lock_retry(path, what, action)` (retries `PermissionError`, raises `Refused` with `the run lock <path> could not be <what>: another process holds it open (<error>); nothing changed` when the attempts run out) in tools/backlog/backlog.py, next to `lock_path` / `read_lock`
- [X] T003 Add the helper `lock_fields(path)` (the lock's fields through `lock_retry(..., "read", ...)`, `None` on `FileNotFoundError`) in tools/backlog/backlog.py

## Phase 3: User Story 1 - update and release succeed while the lock is being read (P1) - MVP

**Independent test**: a child process holds the lock open for 0.5 s; `lock update` and `lock release` exit 0 with their normal output.

- [X] T004 [US1] Add a Windows-only test class `LockHeldOpenTests` with a helper that starts a child Python process holding `open(lock, 'rb')` for N seconds (signals once open; killed in cleanup) in tools/backlog/test_backlog.py
- [X] T005 [US1] Tests: update, release and `release --force` with a 0.5 s holder exit 0, take at least 0.3 s, and leave the new branch / no lock; negative control with `LOCK_RETRY_ATTEMPTS = 1` refuses, in tools/backlog/test_backlog.py
- [X] T006 [US1] In `cmd_lock` of tools/backlog/backlog.py: `update` writes through `lock_retry(path, "updated", ...)`; `release` deletes through `lock_retry(path, "released", ...)` treating `FileNotFoundError` as released

## Phase 4: User Story 2 - a lock held open for long gives a clear refusal (P2)

**Independent test**: attempts shortened to 3, holder 3 s: both commands print one `refused:` line, exit 1, the lock unchanged, no `*.tmp~`.

- [X] T007 [US2] Tests: update refused (exit 1, output starts `refused:`, lock bytes unchanged, no `*.tmp~` in the lock folder) and release refused (lock still exists) in tools/backlog/test_backlog.py
- [X] T008 [US2] Make the tests of T007 pass (the refusal path of `lock_retry`, `write_text` cleanup verified) in tools/backlog/backlog.py

## Phase 5: User Story 3 - reading the lock does not fail at the same moments (P3)

**Independent test**: `lock status` survives a briefly byte-range-locked lock, and a lock removed between check and read prints `free`.

- [X] T009 [US3] Tests: status with a `msvcrt.locking` lock released by a timer after 0.3 s prints the holder line; status / update / release with `read_lock` wrapped to delete the file first print `free` / `no lock to update` / `no lock to release`; acquire whose create meets a PermissionError for a short time succeeds, in tools/backlog/test_backlog.py
- [X] T010 [US3] In `cmd_lock` of tools/backlog/backlog.py: replace `path.exists()` + `read_lock` with `lock_fields`; `acquire` creates through `lock_retry(path, "created", ...)` and, on `FileExistsError`, reads the holder (a vanished holder: create again, bounded)

## Phase 6: Polish

- [X] T011 Run `python -m unittest tools/backlog/test_backlog.py tools/backlog/test_loop.py tools/backlog/test_traces.py` and `python tools/test_bin_help.py`; all pass
- [X] T012 Repeat the measurement (`specs/411-lock-retry-permission/probe/repro_lock.py`), record *After* in specs/411-lock-retry-permission/fix-log.md
- [X] T013 `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`; `bin/backlog.sh check` → `TOTAL: 0`

## Dependencies

T001 → T002 → T003 → US1 (T004 → T005 → T006) → US2 (T007 → T008) → US3 (T009 → T010) → T011–T013.
All tasks touch the same two files, so there is no parallel work.

## Implementation strategy

MVP = US1 (the item's main point). US2 is the item's "clear refusal"; US3 is the severity-3 finding
fixed on the way. No build of the product is needed (no C++ or UI change).
