# Feature Specification: Run lock update and release survive a reader holding the lock open

**Feature Branch**: `411-lock-retry-permission`
**Created**: 2026-11-07
**Status**: Draft
**Input**: User description: "Backlog item run-lock-update-release-no-retry - implement exactly what it describes: `lock update` and `lock release` of `bin/backlog.sh` fail with PermissionError when another process has the run lock file open." From backlog item run-lock-update-release-no-retry.

## Clarifications

### Session 2026-11-07

- Q: How long do the lock commands retry a PermissionError before giving up? → A: 40 attempts at 50 ms (about 2 s), the window of `write_json_atomic` (autonomous run: item)
- Q: How is a PermissionError that persists past the window reported? → A: one `refused: ...` line, exit 1, nothing changed - the run contract's "nothing was written" form (autonomous run: item + rule, SKILL.md §0.8)
- Q: Are the loop's own lock readers in `tools/backlog/loop.py` changed? → A: no, they already retry; only `tools/backlog/backlog.py` changes (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A run's lock update and release succeed while the lock is being read (Priority: P1)

An autonomous backlog run updates the run lock after it creates its branch (`lock update`) and
releases it at its end (`lock release`). Meanwhile the loop, the backlog app (every 2 seconds) or
a person (`lock status`) reads the lock file. On Windows a reader that has the file open makes the
replace and the delete fail at once. The run must not fail, and must not end with the lock still
held, because of such a read.

**Why this priority**: a failed release leaves the lock held, which closes the backlog app's write
gate and makes the loop wait until a person releases the lock by hand; a failed update stops a run
with an unexpected tool error.

**Independent Test**: a test holds the lock file open from a second process for a short time
(shorter than the retry window), runs `lock update` and `lock release` meanwhile, and both
succeed with their normal output; the lock then holds the new branch, or is gone.

**Acceptance Scenarios**:

1. **Given** a lock held by item X and a second process holding the lock file open for 0.5 s,
   **When** `lock update --slug X --branch B` runs, **Then** it waits until the file is free,
   prints `lock updated: branch B`, exits 0, and the lock names branch B.
2. **Given** the same, **When** `lock release --slug X` runs, **Then** it prints `lock released`,
   exits 0, and the lock file is gone.
3. **Given** no reader, **When** either command runs, **Then** it behaves exactly as before (no
   added delay).

---

### User Story 2 - A lock held open for long gives a clear refusal (Priority: P2)

When the file stays open longer than the retry window, the command reports a clear refusal (a
line starting `refused:`, exit 1) instead of a Python traceback, and changes nothing: an update
leaves the lock's old content and no temporary file, a release leaves the lock in place.

**Why this priority**: the run's contract reads exit 1 + `refused:` as "nothing was written, fix
the cause and repeat"; a traceback is not part of that contract.

**Independent Test**: with the retry window shortened for the test and a holder that stays open
longer, both commands print `refused: ...`, exit 1, the lock content is unchanged and no
`*.tmp~` file is left in the lock folder.

**Acceptance Scenarios**:

1. **Given** a holder that keeps the lock open longer than the retry window, **When**
   `lock update` runs, **Then** it prints a line starting `refused:` naming the lock file and
   that another process holds it open, exits 1, and the lock file keeps its previous bytes.
2. **Given** the same, **When** `lock release` runs, **Then** it prints `refused: ...`, exits 1,
   and the lock file still exists.

---

### User Story 3 - Reading the lock does not fail at the same moments (Priority: P3)

`lock status` and the reads that `acquire`, `update` and `release` make of the lock also meet the
same windows: a read while the file is being replaced (PermissionError on Windows) or a release
between the existence check and the read (the file is gone). These reads retry a PermissionError
the same way, and a lock that disappeared between the check and the read counts as free / no lock.

**Why this priority**: the same commands, the same cause; found while measuring (severity 3, fixed
on the way under stop-rules rule 11).

**Independent Test**: `lock status` while a holder has the file open in a way that blocks reading
(a byte-range lock for a short time) still prints the holder line; `lock status` against a lock
removed after the existence check prints `free`.

**Acceptance Scenarios**:

1. **Given** a lock briefly unreadable (PermissionError for less than the retry window), **When**
   `lock status` runs, **Then** it prints the lock's description and exits 0.
2. **Given** a lock deleted between the existence check and the read, **When** `lock status`
   runs, **Then** it prints `free`.

### Edge Cases

- `acquire` meeting a lock file in the "delete pending" state (released while a share-delete
  reader still had it open): creating the file fails with PermissionError; it is retried, then it
  either succeeds or meets the existing lock (`another run in progress`), and a persistent failure
  is a `refused:` line.
- An error other than PermissionError (disk full, missing folder) is not retried and is reported
  as before.
- `release --force` follows the same retry and refusal as `release`.
- A retried update writes a fresh temporary file each attempt and removes it on failure, so no
  `*.tmp~` file is left behind.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `lock update` MUST retry the replace of the lock file when it fails with
  PermissionError, for a retry window of about 2 seconds (40 attempts at 50 ms, as the loop's own
  atomic writer does).
- **FR-002**: `lock release` (with or without `--force`) MUST retry the delete of the lock file
  on PermissionError within the same window; a lock that is already gone during a retry counts as
  released.
- **FR-003**: When the PermissionError persists past the window, both commands MUST print one line
  starting `refused:` that names the lock file and says another process holds it open, exit 1,
  and change nothing (the lock keeps its previous content, no temporary file remains).
- **FR-004**: The reads of the lock by `lock status`, `acquire` (in its "another run in progress"
  message), `update` and `release` MUST retry a PermissionError within the same window; a lock
  that disappears between the existence check and the read MUST be treated as no lock (`free`
  for status, `no lock to release` / `no lock to update` otherwise).
- **FR-005**: `acquire` MUST retry a PermissionError from creating the lock file within the same
  window; a persistent one is a `refused:` line, exit 1, nothing created.
- **FR-006**: Without a concurrent reader, every lock command's output, exit code and lock file
  content MUST stay exactly as before.
- **FR-007**: Tests MUST cover: update and release succeed while another process holds the lock
  open for less than the window (and take at least that long, proving the holder blocked them);
  both refuse with nothing changed when the holder stays longer than a shortened window; status
  survives a briefly unreadable lock and a lock removed between check and read.

### Key Entities

- **Run lock**: the file `.git/tandem-backlog-run.lock` (`started`, `slug`, `branch`, `host`
  lines); held by one run at a time; read by the loop, the backlog app and `lock status`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With a reader holding the lock open for 0.5 s, `lock update` and `lock release`
  succeed in 100% of test runs (before: 0%, a traceback each time — measured at b5bb8329).
- **SC-002**: With a reader holding it open past the window, both commands end with one
  `refused:` line and exit 1, never a traceback, and the lock is unchanged.
- **SC-003**: Without a reader, the existing lock tests pass unchanged and no command takes longer
  than before.

## Assumptions

- Assumption (autonomous run): the retry window is the one the Evidence names — 40 attempts at
  50 ms (about 2 s), as `write_json_atomic` (342) uses; readers hold the lock for microseconds, so
  this is ample, and a person waiting on a refusal waits at most about 2 s.
- Assumption (autonomous run): a persistent failure is reported as `refused: ...` with exit 1, the
  first form of exit 1 in the run contract (nothing written), rather than a new exit code.
- Assumption (autonomous run): the read-side retries (FR-004) and the acquire retry (FR-005) are
  findings of the measurement of severity 3, fixed on the way (stop-rules rule 11); the readers in
  `tools/backlog/loop.py` already retry and are not changed.
- The tests that hold a file open are Windows tests (on other systems an open file does not block
  a replace or a delete); they are skipped elsewhere, as the existing byte-range lock test is.
