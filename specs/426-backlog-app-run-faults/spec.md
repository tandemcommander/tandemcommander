# Feature Specification: The backlog app and the loop during a run

**Feature Branch**: `426-backlog-app-run-faults`
**Created**: 2026-11-12
**Status**: Draft
**Input**: From backlog item backlog-app-and-loop-faults-during-a-run. Backlog item `backlog-app-and-loop-faults-during-a-run` ("In a run the backlog app refuses changes, the loop hangs, the phase falls back"): four faults of the backlog app (features 344, 371, 415) and the backlog loop (247) seen together during the run of feature 425 on 2026-11-12.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Change the backlog from the app while a run is going on (Priority: P1)

The maintainer opens the backlog app while the loop implements an item and creates a new item,
moves one, or edits one. The change is committed on `main` at once through the app's side
worktree; the running item stays frozen.

**Why this priority**: today every such change is refused (two different errors), so the main
promise of feature 371 does not hold at all; the maintainer can only wait for the run to end.

**Independent Test**: a server test builds a fixture repository whose `specs/` holds a file
(as the real `specs/FEATURE-HISTORY.md`) besides feature folders, prepares the side worktree for
`main`, then again after `main` changed that file; both preparations succeed and a change lands
on `main`. The same test fails on the old code (negative control).

**Acceptance Scenarios**:

1. **Given** a repository whose `specs/` holds a file directly (not only folders), **When** the
   app prepares its side worktree for `main`, **Then** the preparation succeeds, the file is not
   replaced by a folder, and the worktree is clean at `main`.
2. **Given** a side worktree left in a dirty state (a tracked file deleted, changed, or a folder
   standing where a file belongs) and `main` moved on, **When** the app prepares it again,
   **Then** it is brought back to `main` by itself, without a person.
3. **Given** a repository with a folder named `backlog` deeper in the tree (e.g.
   `tools/backlog/`), **When** the side worktree is prepared, **Then** only the top-level
   `backlog/` is checked out.
4. **Given** the side worktree cannot be prepared for a reason git reports, **When** the change
   is refused, **Then** the maintainer sees git's reason, not only "git checkout ... failed".

---

### User Story 2 - A finished run ends, and the app is free again (Priority: P1)

A run closes its item (journal row written, `main` fast-forwarded, run lock released) and ends
its last turn. The `claude -p` process ends then, the loop concludes the run, releases the app's
edit lock and goes on (or stops when asked), instead of waiting for a wakeup scheduled earlier.

**Why this priority**: a hang keeps the edit lock, so the app refuses every change; the loop does
not continue; the maintainer has to end processes by hand (and that leads to Story 3).

**Independent Test**: a loop test with the fake harness: the fake claude finishes the item and
ends its turn with a result but keeps running (as a pending wakeup keeps the real one alive);
the loop must end it within a short grace period and record the item as closed.

**Acceptance Scenarios**:

1. **Given** a run whose journal row is written and whose run lock is released, **When** its
   turn has ended (a result event) and the process does not exit, **Then** the loop ends the
   process after a short grace period, concludes the run as finished and releases the edit lock.
2. **Given** a run that ended a turn while it still holds its lock (waits for a reviewer),
   **When** the process stays alive, **Then** the loop does not end it (the existing behaviour).
3. **Given** the implement skill scheduled a wakeup during the run, **When** it writes its final
   message, **Then** it has cancelled pending wakeups first.

---

### User Story 3 - The status of a finished run after a hard stop is right (Priority: P2)

After the maintainer ends a finished but hanging run by hand, `bin/backlog-loop.sh status` says
the run is finished and the next start records it as such; it never offers to continue a closed
run in the same session.

**Why this priority**: a misleading status makes the maintainer fear the next start resumes a
finished session.

**Independent Test**: a loop test: a run record whose item has its journal row and no run lock
(a hard stop after the end); `status` prints that the run finished with that outcome; the next
start concludes it without starting claude.

**Acceptance Scenarios**:

1. **Given** a run record with phase `killed` whose item has a journal row written since the run
   began and whose lock is gone, **When** `status` runs, **Then** it reports the run as finished
   with the row's outcome and that the next start records it, and no "continues this run" line.
2. **Given** the same record, **When** the loop starts, **Then** it concludes the run as finished
   without starting claude, and the trace's `meta.json` records the outcome and an end.

---

### User Story 4 - The live run page shows the run's real phase (Priority: P2)

While a run goes on, the run's page shows the same phase as the server's fold of the trace, and
never falls back to an earlier phase, also after a reconnect or a reopened page, and for traces
larger than one page of the stream.

**Why this priority**: the page is how the maintainer follows a run; a wrong phase and progress
make it useless.

**Independent Test**: a server test streams a trace larger than one catch-up page and checks that
every event of the file arrives (each event of a multi-event line too); a web test checks that the
page's phase is never earlier than the server's phase event. The stream test fails on the old code.

**Acceptance Scenarios**:

1. **Given** a live run whose trace is larger than one page of the stream's catch-up, **When** the
   page connects (first time, after a reconnect or a reopened page), **Then** it receives every
   event of the trace and its phase equals the server's.
2. **Given** a trace line that yields several events, **When** it is streamed, **Then** every one
   of them arrives.
3. **Given** the server reports a phase later than the page's own fold (a list trimmed at its
   start), **When** the page shows the phase, **Then** it shows the server's phase.

### Edge Cases

- A side worktree in which the path of a tracked file is a folder (the state the old code left).
- `specs/` without any file (the old fixtures): nothing changes for them.
- A run whose turn ended while it still holds its lock (waits for a reviewer): it must not be
  ended by the loop.
- A finished run whose process exits by itself during the grace period: concluded normally.
- A trace page without events (only lines that give none): the catch-up goes on to the next page
  instead of stopping.
- The client reconnects with `Last-Event-ID` in the middle of a multi-event line: the rest of
  that line's events are not lost.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The side worktree's preparation MUST create only the folders of `specs/` (never a
  folder in place of a file) for the backlog tool's `feature-missing` rule.
- **FR-002**: The preparation MUST bring a side worktree in any dirty state of its tracked files
  (deleted, changed, a folder in place of a file) back to `main` by itself before it checks out
  `main`'s commit; it MUST still refuse (never delete) a worktree it cannot read (feature 412).
- **FR-003**: The sparse checkout MUST select only the top-level `backlog/` folder.
- **FR-004**: A refusal of the side worktree MUST show git's reason to the maintainer.
- **FR-005**: The loop MUST end a run's process when the run is finished (its journal row is
  written since it began and the run lock is no longer the run's) and the process has ended its
  last turn (a result event, no newer activity) but is still alive after a grace period; it
  MUST then conclude the run as finished and release the app's edit lock.
- **FR-006**: The loop MUST NOT end a process that holds its run lock, or whose turn has not
  ended.
- **FR-007**: The implement skill MUST cancel pending wakeups (`ScheduleWakeup` with `stop`)
  before its final message, on every path that ends a run, and MUST NOT wait for the maintainer's
  program with a wakeup.
- **FR-008**: `status` MUST report a run record whose item has its journal row and whose lock is
  gone as finished (with the outcome), never as a run that the next start continues.
- **FR-009**: When the loop concludes such a record, the trace's `meta.json` MUST record the
  outcome and the end.
- **FR-010**: The trace stream's catch-up MUST send every event of the trace file (all pages,
  every event of a multi-event line) before following the live run.
- **FR-011**: The live page's phase and timeline MUST never be earlier than the phase the server
  reports for the same run (its `phase` stream event), and MUST never move back.
- **FR-012**: Tests MUST reproduce each of the four faults on the old code (negative controls)
  and pass on the new code.

### Key Entities

- **Side worktree**: the app's sparse, detached worktree of `main` in the app's state folder.
- **Run record**: the loop's `run.json` (phase, `rows_before`, child process) and the trace's
  `meta.json`.
- **Trace stream**: the server's SSE stream of a run's trace events (catch-up, then live, plus
  a `phase` event).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a repository with a file directly under `specs/`, 10 of 10 changes made through
  the side worktree in a row land on `main` (today 0).
- **SC-002**: A finished run whose process stays alive is ended and concluded by the loop within
  the grace period plus one tick (today it waits for the wakeup, up to an hour).
- **SC-003**: After a hard stop of a finished run, `status` names it finished (0 lines offering
  continuation).
- **SC-004**: For the 15.7 MB trace of run 425, the stream delivers 1694 of 1694 events (today
  211) and the page's phase equals the server's.

## Assumptions

- Assumption (autonomous run): the grace period after the last result of a finished run is 30 s
  (long enough for the final message to be flushed, short against the reported hour); the loop's
  existing kill path (`kill_tree`, as for an idle run) is reused.
- Assumption (autonomous run): the earlier run where the phase fell back (its id was not filled
  in) had the same cause: every page opened or reconnected once the trace was larger than 1 MB
  folds only the first megabyte.
- Assumption (autonomous run): the user's MCP servers loaded by a run (noted in the item, not the
  cause) stay as they are; changing the harness options of a run is not part of this item.
- The changes are in development tooling only (`tools/backlog-app/`, `tools/backlog/`, the
  implement skill); nothing of the product, its strings or its installer changes.
