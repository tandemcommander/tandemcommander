# Closing report - 371-backlog-app-live-editing

Backlog item: - (the maintainer's request of 2026-11-01, not a backlog item)
Outcome: closed

## What changed

- The backlog app is writable while the loop lives and while a run is in progress. Three write
  channels decided by the gate: `tray` (no loop: the working tree, pending until committed),
  `commit` (a loop lives: the working tree, committed at once), `main-ref` (a run holds the run
  lock on its branch: the backlog tool runs in the app's sparse detached side worktree of `main`
  at `.git/tandem-backlog-app/main-worktree/`, the change is committed there and `main` moves by
  compare-and-swap). The primary working tree is never touched while a run holds the lock.
- The item a run works on is frozen: its own changes and indirect ones (a close that would rewrite
  its lists) are refused (`frozen-item`); reorders put the hidden item back where the files have
  it; bulk changes skip it.
- The loop holds the app's edit lock while a run starts (until the run lock names a branch) and
  while it returns to `main` (`bin/backlog-loop.sh returning`, called by the implement skill at
  step 9); the gate shows `run-starting` / `run-on-main` for those moments and opens again by
  itself. A short precheck hold of a waiting loop does not close the gate (the queue waits).
- The running item is shown in *In progress* with its feature number (an overlay of the board
  read from `main`), "next up" leaves it out (`backlog.py next --except`), the item page says a
  run works on it.
- A typed position and "Move to the top" on the item page and in the section tables (a reorder,
  no log line).
- A conversation with Claude about one item in a window of its own: one `claude -p` process in
  bidirectional stream-json mode, read-only tools, the item's context with the first message,
  streaming replies, stop, new conversation, transcripts in the state folder, a budget setting.
- Fixed: two time-dependent tests (a run lock dated 2026-10-30 turned stale on 2026-10-31).

## Measurements (before / after, commands)

- Before: *In progress* 0 during a run (the board read from `main`), the gate read-only for the
  whole run; `npm run check` 282 / 284.
- After: *In progress* shows the running item with its feature; a change during a fake run is on
  `main` within 10 s (e2e: the new item at Next #1 while the run holds the lock); positions by
  number within 3 s (e2e); the conversation's first reply streams in the e2e within seconds with
  the fake, 3.9 s per turn measured with the real claude (haiku); `npm run check` 329 / 329.

## Checks

- `python tools/backlog/test_loop.py` 113 / 113 (4 new), `test_backlog.py` 112 / 112 (1 new),
  `tools/test_bin_help.py` OK.
- `npm run check`: typecheck, lint, format clean; vitest 329 / 329 (+ 2 skipped: the opt-in
  soak) - new: write-gate 15, side-worktree 6, write-channels 8, read-model 4, chat 9.
- `npm run test:e2e`: 34 / 34 on Edge (new: us1-live-edit, us4-chat, the position test of
  us3-order; the lock date of Q9 computed).
- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s). Every page browsed on a shallow
  clone of this repository: 24 pages, 0 console errors; a typed position and *Move to the top*
  applied.
- Soak (`BACKLOG_APP_SOAK=1`, `write-race.test.ts`): SC-002 - 20 `branch-hang` runs with 3 changes
  during each run's branch phase: 60 / 60 changes on main, every run merged main (`ff_first`
  false) and closed, the check clean (147 s); SC-007 - 200 changes against 20 branch runs of
  10 s under a loop at a 50 ms tick: 200 / 200 commits on main, 0 lost, 0 runs started on a
  dirty tree, no run's commit swept an app change in (400 s). The first soak rounds failed in the
  test's assumptions (the fixture's own eligible item ran first; `close` runs end in half a
  second, before the first change; a run that never takes a branch holds the edit lock for its
  whole length, so changes queue up behind it) - see `fix-log.md`.

## Reviews

- One refute-first review (an independent agent, read-only): 2 MUST (M1 the side worktree's CRLF
  files against blob-hash revisions - fixed by per-worktree `core.autocrlf false` / `core.eol lf`
  and a CRLF test; M2 `git log --output=` in the conversation's allow-list writes files - fixed by
  file tools only), 4 SHOULD (S1 a leftover `returning` flag - fixed; S2 a commit failure in the
  `commit` channel - the change is undone; S3 the primary-HEAD check is best effort for a manual
  run - accepted and documented; S4 untested paths - the CRLF path tested, the rest recorded),
  5 NOTE (N1 a stale loop view for the never-stale rule - fixed by a fresh poll; N2-N5 recorded).
  Details in `fix-log.md`.

## Owed to a person

- The first real run with the app open: make a change during the run and watch the run's step 9
  (`bin/backlog-loop.sh returning`, the merge recipe) on the real repository.
- The maintainer's decisions recorded in the spec's *Clarifications* (commit at once while the
  loop lives; no queueing of refused changes; read-only on a manual branch) stand until overruled.

## New Inbox items

- `backlog-app-live-edit-real-run` (person step) - the first real run with a change made during it.
- `backlog-app-new-item-position-lost-during-a-run` (bug, not reproduced) - twice in eight e2e runs
  the item created during a run landed at the end of Next instead of #1.
