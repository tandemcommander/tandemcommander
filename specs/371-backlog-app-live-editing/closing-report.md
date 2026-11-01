# Closing report - 371-backlog-app-live-editing

Backlog item: - (the maintainer's request of 2026-11-01, not a backlog item)
Outcome: closed (pending: the final numbers below are filled in at the end of the session)

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
- After: see *Checks*.

## Checks

- `python tools/backlog/test_loop.py` 113 / 113 (4 new), `test_backlog.py` 112 / 112 (1 new),
  `tools/test_bin_help.py` OK.
- `npm run check`: typecheck, lint, format - FILLED AT THE END; vitest FILLED AT THE END
  (new: write-gate 15, side-worktree 6, write-channels 8, read-model 4, chat 9).
- `npm run test:e2e`: FILLED AT THE END (new: us1-live-edit, us4-chat, the position test of
  us3-order).
- Soak (`BACKLOG_APP_SOAK=1`): FILLED AT THE END.

## Reviews

- FILLED AT THE END (one refute-first review).

## Owed to a person

- The first real run with the app open: make a change during the run and watch the run's step 9
  (`bin/backlog-loop.sh returning`, the merge recipe) on the real repository.
- The maintainer's decisions recorded in the spec's *Clarifications* (commit at once while the
  loop lives; no queueing of refused changes; read-only on a manual branch) stand until overruled.

## New Inbox items

- FILLED AT THE END.
