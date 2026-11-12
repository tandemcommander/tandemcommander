# Research - 426 the backlog app and the loop during a run

All measured at `f8fc5084` (`main`) before any change; the commands are in `fix-log.md`.

## R1 - The side worktree breaks itself

- **Decision**: in `sync()` list `specs/` with `git ls-tree -d` (trees only). Before the
  checkout, bring the tree back to its own HEAD: remove an empty folder that stands at the path of
  a tracked file under `specs/` (what the old code left), then `git reset -q --hard` and
  `clean`; only then `checkout --detach <commit>`, `sparse-checkout reapply`, `reset --hard`,
  `clean` as before. The sparse pattern becomes `/backlog/` (non-cone, anchored). Measure in the
  test whether `reset --hard` alone already replaces the empty folder (then the explicit removal
  is kept only if needed).
- **Rationale**: measured with the real class in a fixture: the first sync leaves
  ` D specs/FEATURE-HISTORY.md` (a folder there), the second fails at the checkout. Cleaning first
  makes `sync()` idempotent from any dirty state, which its doc comment already promises.
- **Alternatives**: `checkout -f` (also discards changes, but leaves a folder in place of a
  file and would not remove untracked folders); deleting and recreating the worktree on every
  failure (slow: a new worktree; and the 412 rule says an unreadable worktree is never deleted).

## R2 - A finished run that does not end

- **Decision**: (a) `loop.py` `watch()`: when the watched process belongs to this run, the run is
  finished (`our_row()` is not None and the lock is not the run's), the newest stream object is a
  `result`, and no new line has come for `--finish-grace` seconds (default 30), end the process
  tree (`kill_tree`) and let `execute()` / `conclude()` record it as finished. (b) the implement
  skill: before the final message of §11, if the run scheduled a wakeup, call `ScheduleWakeup`
  with `stop: true`; a wait for the maintainer's program is never a wakeup.
- **Rationale**: measured with `claude -p`: a pending wakeup keeps the process alive after
  `result` (122 s for a 60 s wakeup, a second turn ran); `stop: true` cancels it (exit after 5 s).
  (a) protects every skill and every harness version; (b) avoids the 30 s and a woken turn that
  could do work after the run released its lock.
- **Alternatives**: end the process at the first `result` (wrong: a run waiting for a reviewer
  ends turns while it holds its lock); only the skill rule (a future skill or a model that
  forgets leaves the hang).

## R3 - `status` after a hard stop of a finished run

- **Decision**: `describe()` computes `finished` (the outcome of the item's journal row written
  since `rows_before`, when the lock is not the run's); `cmd_status` prints
  `the run finished (<outcome>); the next bin/backlog-loop.sh start records it` instead of the
  continuation lines. `conclude()` of a `finished` verdict calls `finish_trace` so `meta.json`
  gets its end (check what it does today).
- **Rationale**: `pending()` already concludes such a record without starting claude (measured
  by reading: `our_row` + not `holds`); only the words were wrong.

## R4 - The live page falls back to Specify

- **Decision**: in `runs.ts` the catch-up keeps its read position (`readAt`) apart from the sent
  position; it stops only when a page makes no progress (`page.next <= readAt`), not when a page
  has no events; `send()` skips only events whose line ended at or before the position the batch
  started from, so all events of a line go out. The client handles the `phase` event and the
  dashboard shows the later of its fold and the server's phase (`laterPhase`, forward order of
  `PHASE_ORDER`, `stopped` wins).
- **Rationale**: a replay of the catch-up loop over the 425 trace sent 211 of 1694 events and
  folded `specify`; the fold of the whole trace is `done`. The trace grows past 1 MB early in a
  run (run 425 crossed it during specify), so every page opened or reconnected after that showed
  Specify.
- **Alternatives**: give the event id a sub-index per line (changes the resume contract; the
  per-batch floor is enough because one line's events are sent together).
