# Loop CLI additions - 371 (`tools/backlog/loop.py`, `bin/backlog-loop.sh`)

Amends `specs/344-backlog-web-app/contracts/loop-cli-additions.md`. Backward compatible: every
existing command, flag and file keeps its meaning.

## The loop holds the edit lock while a run starts

Before its precheck the loop takes `<git-common-dir>/tandem-backlog-edit.lock` (exclusive
create; the four lines `pid`, `started_epoch`, `started`, `purpose`; `purpose: loop: starting a
run`). A live lock of another process (the app's change in progress) is waited for as today
(`waiting: the backlog app is changing the backlog`); a dead one is replaced.

The loop keeps the lock:

- through `precheck` and, when a run starts, through the start of claude until the run lock shows
  a `branch` other than `-` (the skill's step 4.5 `BL lock update --branch`) or claude ends;
- for a continued run (`pending()`), only while the run lock's branch is `-`;
- through the auto-triage (it already keeps the app read-only through the loop state).

It releases the lock at once when the precheck does not lead to a run (waiting, idle, gone), and
always on its way out (stop, hard stop, an exception).

## `returning` - the run announces its return to `main`

```text
bin/backlog-loop.sh returning [--timeout SECONDS]     (default 300)
```

Called by `/tandem-backlog-implement` at the start of step 9, before `git checkout main`:

1. writes `.git/tandem-backlog-loop/returning` (`<slug> <time>`, the slug from the run lock, `-`
   without one);
2. waits until no live edit lock of a process other than the loop exists (an app change lands
   within seconds);
3. when a loop is live: waits until the loop holds the edit lock (`purpose: loop: the run of
   <slug> returns to main`) - the loop's `watch` takes it within a tick of seeing the flag;
4. prints `ok: main is yours (<who holds the edit lock>)` and exits 0.

Exit 1 with `refused: ...` after the timeout (the app's lock did not clear) - the skill then goes
on; the app's own HEAD check (research R2) remains the guard. Without a live loop (a manual run)
step 3 is skipped.

The loop removes the flag and releases the lock when claude ends; the next `start` removes a
leftover flag.

## `status --json`

`edit_lock` gains `holder`: `"loop"` when the lock's pid is the live loop's pid, else `"other"`
(null when there is no lock); new top-level `returning: bool` (the flag exists).

## `bin/backlog-loop.sh`

`returning` is listed in `--help` and passed through like the other commands.

## Tests (`tools/backlog/test_loop.py`)

- the loop holds the edit lock from precheck until the fake run writes the branch into the lock
  (fake step `branch-hang`), and releases it on a precheck that waits;
- an app lock taken before the precheck makes the loop wait, and the loop never starts a run while
  it exists (a fake app that holds the lock and writes a file, then commits);
- `returning` waits for a foreign lock, then for the loop's hold; prints `ok`; times out with
  `refused`;
- the flag is removed when claude ends and at the next start.
