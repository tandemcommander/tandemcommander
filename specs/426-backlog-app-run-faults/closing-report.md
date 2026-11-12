# Closing report - 426-backlog-app-run-faults
Backlog item: backlog-app-and-loop-faults-during-a-run - In a run the backlog app refuses changes, the loop hangs, the phase falls back
Outcome: closed

## What changed

1. **Side worktree** (`tools/backlog-app/packages/server/src/backlog/side-worktree.ts`): `sync()`
   creates only the folders of `specs/` (`git ls-tree -d`; it made a folder of
   `specs/FEATURE-HISTORY.md` before), makes the worktree clean (`reset --hard`, `clean`) before
   the checkout, and sets the sparse pattern `/backlog/` on every sync (was `backlog`, which
   matched every folder of that name). A worktree left broken by the old code is repaired by the
   first sync. The web shows a refusal's textual detail (git's reason): `errorText()` in
   `web/src/lib/api.ts`, used by every change dialog and toast.
2. **A finished run that lingers** (`tools/backlog/loop.py`): `watch()` ends the run's claude when
   the run is finished (its journal row is written, the run lock is no longer its own), the newest
   stream object is a `result` and nothing came for 30 s (`FINISH_GRACE`); the edit lock of the
   return is then released and the run concluded as finished. The implement skill cancels pending
   wakeups (`ScheduleWakeup` `stop: true`) before its final message and never waits for the
   maintainer with a wakeup.
3. **Status after a hard stop**: `status` (and `status --json` `finished`) names a run record
   whose item has its row and no lock as finished; the next start records it (as it already did).
4. **The trace stream** (`tools/backlog-app/packages/server/src/api/runs.ts`): the catch-up sends
   the whole file (it stopped after the first 1 MB page) and every event of a line (the second was
   skipped); only the last event of a line carries the id. The run page shows the later of its fold
   and the server's phase (`laterPhase`, the stream's `phase` event).

## Measurements (before / after, commands)

| Part | Before (f8fc5084) | After |
|---|---|---|
| Side worktree, a file directly under `specs/` | sync 1: "could not be brought to main"; sync 2: "git checkout in the side worktree failed" | ten rounds landed; a dirty worktree repaired |
| `claude -p` with a pending wakeup | alive 122 s after its result (60 s wakeup) | `stop: true` → exit after 5 s; the loop ends a lingering finished run after the grace |
| Lingering closed run in the loop (fake) | 45.7 s (its whole linger) | < 20 s (grace 0.5 s in the test) |
| `status` after a hard stop of a finished run | "continues this run in the same session" | "the run finished (closed); the next bin/backlog-loop.sh start records it" |
| Stream of the 425 trace | 211 of 1694 events, phase `specify` | 1694 of 1694, phase `done` |

Commands: `specs/426-backlog-app-run-faults/fix-log.md`.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `npm run check` (`tools/backlog-app`): typecheck, lint, format clean; vitest 530 passed, 2 skipped (baseline 519).
- `python -m unittest` (`tools/backlog`): 264 tests OK (baseline 258).
- `python tools/test_bin_help.py`: OK. `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- No product code changed: no build, saltests or GUI probe applies.

## Reviews (findings and what was done)

Review 1: no MUST, no SHOULD; five NOTEs - the missing test for an orphaned claude found by the next
start was added; the others accepted with reasons in the fix-log (a line may be shown twice after a
cut mid-line; the kill ignores background tasks by design; `status` is cautious with a later manual
run of the same item; old review worktrees).

## Owed to a person (the lines added to the release checklist)

1 line in `manual-checks-owed-before-the-next-release`: during a real loop run, an item created in
the app lands on main; the loop concludes the run within about 30 s of its last message; the live
page shows the server's phase.

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- The second and later events of a trace line were never streamed (severity 4).
- The sparse pattern matched every `backlog` folder (severity 1).
- A refusal showed only its message, not git's reason (severity 3).

## New Inbox items (slug - title)

- none

## For the maintainer

- The repository's side worktree `.git/tandem-backlog-app/main-worktree/` still holds the state the
  old code left (an empty folder `specs/FEATURE-HISTORY.md`); the first change made in the app
  during the next run repairs it (tested by the review on such a worktree). Restart the backlog app
  so that it runs the new code.
- `git worktree list` shows eight old review worktrees under `%TEMP%/rev*` (features 325-414); they
  can be removed (`git worktree remove`), not done here.
- The loop's leftover record of the run of 425 (`.git/tandem-backlog-loop/run.json`, phase
  `killed`) is concluded as finished by the next `bin/backlog-loop.sh start` without claude.
