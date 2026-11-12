---
title: In a run the backlog app refuses changes, the loop hangs, the phase falls back
type: bug
status: open
severity: 5
area: tooling
source: manual
who: agent
created: 2026-11-12
updated: 2026-11-12
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# In a run the backlog app refuses changes, the loop hangs, the phase falls back

## Problem

The maintainer steers the backlog from the backlog app (344, 371) while the loop runs an item.
On 2026-11-12, during the run of feature 425, four faults of the app and the loop showed up
together:

1. **Every change from the app during a run is refused.** Creating a new item gave
   "git checkout in the side worktree failed". After the side worktree was removed (so that it
   was created again), the next attempt gave "the side worktree of main could not be brought to
   main". The app's own `sync()` breaks the side worktree on every preparation, so no change made
   in the app during a run can ever land. Feature 371 (changes during a run) has very likely
   never worked: the file that triggers it has been in the tree since 2026-10-09 and the code
   since 2026-11-01.
2. **A finished run does not end, and the loop holds the app's edit lock meanwhile.** The run's
   last turn ended with `end_turn` (item closed, `main` fast-forwarded, run lock released), but
   `claude -p` stayed alive because a `ScheduleWakeup` from an earlier turn was still pending
   (1800 s). The loop waits for the process to exit and keeps the edit lock
   ("the run ... returns to main") all that time, so the app refuses every change. The
   maintainer had to end it by hand.
3. **After ending it by hand, the loop treats a finished run as cut off.** `bin/backlog-loop.sh
   status` says "the next bin/backlog-loop.sh start continues this run in the same session",
   although the item is closed, its row is in `RUNS.md` and `main` holds the merge.
4. **The live run page shows an early phase (Specify) while the run is far later.** While a run
   is going on, the app's page of the run sometimes shows "Specify" although the run is in
   implement, verify or review. The maintainer saw it on an earlier run as well: the page first
   showed implementation, then fell back to "Specify" and stayed there until the run ended
   (closed). The phase steps and the progress built on them are then wrong; nobody can tell from
   the page how far the run is.

## Evidence

Everything at `49262ba9` (`main`, after the merge of 425) unless said otherwise. Times are local
(CET); trace timestamps are UTC.

**1. The side worktree** (`.git/tandem-backlog-app/main-worktree/`,
`tools/backlog-app/packages/server/src/backlog/side-worktree.ts`):

- `SideWorktree.sync()` (lines 176-182) creates "the feature folders, empty" from
  `git ls-tree --name-only -z <commit> -- specs/` and calls `mkdirSync` for every entry that
  matches `^specs\/[^/]+$`. `ls-tree` without `-d` lists files too, so it also creates an empty
  **directory** named `specs/FEATURE-HISTORY.md` (the only file directly under `specs/`, added
  by `dbd896a4` on 2026-10-09). Measured: in a freshly created side worktree, after one failed
  change, `specs/FEATURE-HISTORY.md` is an empty directory, `git ls-files -v` shows it as `H`
  (git cleared its skip-worktree bit because something is present at that path) and
  `git status` shows ` D specs/FEATURE-HISTORY.md`.
- First attempt: the final check of `sync()` (lines 183-191) sees a non-empty status and
  throws "the side worktree of main could not be brought to main".
- Every later attempt: `sync()` runs `git checkout -q --detach <commit>` (line 172) **before**
  `reset --hard` / `clean` (lines 174-175), and git refuses:
  `error: Your local changes to the following files would be overwritten by checkout:
  specs/FEATURE-HISTORY.md` (because `main` has changed that file since). `inTree()` (lines
  83-93) throws "git checkout in the side worktree failed". The worktree never recovers by
  itself.
- The old side worktree had stood at `e1b1e2c9` since it was created on 2026-11-01 15:07; its
  reflog had a single entry, so no `sync()` had ever completed there. It was removed with
  `git worktree remove --force` on 2026-11-12 (its commit was in `main`, its only change was the
  false deletion); the new one shows the same state after one attempt.
- Side finding: the non-cone sparse pattern `backlog` (`SPARSE_PATTERNS`, line 39) matches a
  folder named `backlog` at any depth, so 49 files of `tools/backlog/` and
  `tools/backlog-app/.../backlog/` are checked out too. Harmless now (they stay clean), but not
  what the comment says ("the backlog only"). Reproduced in a scratch worktree with the
  commands of `ensure()`.

**2. The finished run that did not end** (run
`20261112-140713-claude-ikona-na-desktop-vede-kamsi-neznamo-kam`, feature 425, session
`4031c33e`):

- `trace.jsonl`: `ScheduleWakeup` with `delaySeconds: 1800` at 14:45:50Z (15:45:50 local),
  prompt "reviews done (3, no MUST); waiting for the maintainer's tandemcommander.exe to close so
  the final probe can run". The run then finished another way: `bin/backlog.sh lock release`,
  the final report and a `result` event with `stop_reason: end_turn` (last trace write
  15:59:51). Nothing cancelled the pending wakeup (due at about 16:16).
- At 16:03-16:08 `claude.exe` (pid 29940, child of the loop's `python loop.py`, pid 15156) was
  still alive, with no child process (after its Unity MCP server `relay_win.exe` was ended) and
  no CPU use; `bin/backlog-loop.sh status` showed `lock: free`,
  `edit: held by the loop since 2026-11-12T15:59:35 - loop: the run of ... returns to main`,
  `control: stop requested`.
- `.claude/skills/tandem-backlog-implement/SKILL.md` lines 365-383: while a reviewer runs,
  every turn must end with a fallback wakeup (at most 600 s). Nothing says that the last turn
  of a run cancels a pending wakeup, and this wakeup (1800 s) waited for the maintainer's
  program, not for a reviewer.
- `tools/backlog/loop.py` line 543 stores the `result` object of the stream, but the loop
  keeps waiting for the process to exit.
- Not the cause, but noted: the run's `claude -p` loaded the user's MCP servers (Unity relay,
  `~/.unity/relay/relay_win.exe --mcp`), which a run does not need.

**3. After the manual end:**

- `meta.json` of the run: `"phase": "killed"`, `"outcome": "closed"`, `"ended": null`,
  `"commits": []`, `"why": "a hard stop (Ctrl+C) killed the process"`, attempt 1
  `"exit_code": 1`.
- `bin/backlog-loop.sh status`: "the next bin/backlog-loop.sh start continues this run in the
  same session", while the item folder is gone, `backlog/RUNS.md` has the row
  `2026-11-12 15:59 | ikona-na-desktop-vede-kamsi-neznamo-kam | closed | 425` and `main` is at
  `49262ba9`.

**4. The live phase** (by reading on branch `425-desktop-drive-item`, unchanged in `main`):

- Run `20261112-140713-claude-ikona-na-desktop-vede-kamsi-neznamo-kam`, around 14:20: the page
  shows "Specify". At the same time the live run snapshot (server fold of the same trace) gives
  "review (Independent review)", 93 %, 18/19 tasks, and `tasks.md` has 18 of 19 tasks ticked.
  The earlier run where it happened: <run id - fill in>.
- The page takes its phase from its own fold of the streamed events, and from the server's
  phase only before the first event arrives:
  `const folded = events.length > 0 ? runView.phase : run.phase`
  (`tools/backlog-app/packages/web/src/features/live/run-dashboard.tsx:95`).
- The server sends an SSE `phase` event with its own phase
  (`packages/server/src/api/runs.ts:133-136`), but the client ignores it: `useTraceStream`
  handles only `trace`, `attempt` and `ended`
  (`packages/web/src/features/runs/trace-view.tsx:64-71`).
- The browser fold starts again from "starting" whenever the first event's offset changes or
  the list gets shorter (`packages/web/src/features/live/use-run-insight.ts:79`). It then folds
  only the events it still has. Several markers move the phase only once it is at least at
  implement: Agent calls → review, builds/saltests/probes → verify
  (`packages/shared/src/runs/run-state.ts:310-334`). So a fold that misses the early markers of
  the run cannot get past the early phases.
- One way the list loses its start: the cap `MAX_EVENTS = 50_000` that drops the oldest events
  (`trace-view.tsx:28, 57-60`). That is not the cause here: this run's trace has 2,051 lines.
  Still to check: a reconnect of the stream (resumes from `last-event-id`, `runs.ts:79`) and a
  remount of the page. Can either of them leave the client with a list that does not start at
  offset 0, or with duplicated events?
- `meta.json` of the running run had `"phase": "running"`, `"feature": null`,
  `"branch": null`, `commits: []`, and the RUNS.md row had feature "-". Check that no view
  takes the phase or feature from these.

## Expected

1. A change made in the app during a run lands on `main` through the side worktree:
   `sync()` creates only the folders of `specs/` (`git ls-tree -d`), never a directory in place
   of a file. `sync()` brings a side worktree left in any dirty state (a tracked file deleted or
   changed, a directory in place of a file) back to `main` by itself, without a person. The
   sparse pattern selects only the top-level `backlog/` folder. A server test with a file
   directly under `specs/` reproduces the refusal on the old code (negative control) and passes
   on the new; a second test starts from a dirty side worktree.
2. A run whose last turn has ended (`result` with `end_turn`, run lock released) ends: no
   pending wakeup keeps `claude -p` alive, and the loop does not hold the edit lock beyond the
   end of the run. Either the implement skill cancels pending wakeups before its final report
   and never waits for the maintainer's program with a wakeup, or the loop ends the process
   when a `result` arrives and nothing remains to do (no background task in
   `background_tasks_changed`), or both. A loop test with the fake harness
   (`tools/backlog/fixtures/fake_claude.py`) reproduces the hang and checks that it no longer
   happens.
3. A run whose item is closed (row in `RUNS.md`, item removed, `main` holds the merge) is not
   offered for continuation after a hard stop; `status` reports it as finished, and `meta.json`
   records the outcome and the end.
4. The phase on the page of a live run is never behind the server's phase for the same run. It
   never moves back: phases are forward-only in the server's fold, and the page shows the same.
   Either the page takes the server's `phase` event (and timeline) as the lower bound of its own
   fold, or any rebuild of the fold starts from the whole trace and never from a tail. A test
   reproduces the drop to "Specify" (the cause found first, not guessed) and checks that it no
   longer happens; a negative control fails on the old code.

## Approach

- Part 1: `git ls-tree -d --name-only -z`; in `sync()` run `reset -q --hard` (or
  `checkout -f`) before the checkout, and remove a non-directory/directory mismatch under
  `specs/` before it; pattern `/backlog/`. Measure first in a scratch side worktree with the
  commands of `ensure()` / `sync()` (that is how the state above was reproduced).
- Part 2: measure first what keeps `claude -p` alive (the pending wakeup is the suspect; no
  child process was left). Prefer a fix in the loop (it holds for every skill), plus a rule in
  the implement skill for its last turn.
- Part 4: reproduce first (measure first); the cause is not confirmed.

## Notes

- Severity 5: functions do not work (changes from the app during a run, the end of a run, the
  live phase) and the workarounds are poor: wait until the run ends, end the hung process by
  hand, read the trace or the chat's run snapshot for the phase. No data is lost: a refused
  change writes nothing.
- One item at the maintainer's request (2026-11-12): all four faults showed during the same run
  and all are about the app and the loop while a run is going on.
- Part 4 was written by the maintainer (severity 4 on its own). The id of the earlier run is
  still to be filled in.
- Not verified: whether the app's error dialog shows the detail of the error (git's stderr).
  The maintainer saw only the message "git checkout in the side worktree failed"; the reason
  was found only from the command line.
- Not verified: whether the tests of 371 have a fixture with a file directly under `specs/`
  (suspected not, since they pass).

## Log

- 2026-11-12 — created (source manual)
- 2026-11-12 — title shortened to 80 characters
- 2026-11-12 — moved to Next position 1
