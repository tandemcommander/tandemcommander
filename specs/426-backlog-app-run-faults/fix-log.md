# Fix log - 426 the backlog app and the loop during a run

Backlog item `backlog-app-and-loop-faults-during-a-run`. Run started 2026-11-12 16:14 on `main`
at `f8fc5084` (HEAD0).

## Before the run (the maintainer's session, 2026-11-12)

- 15:3x the maintainer creates an item in the backlog app during the run of 425:
  "git checkout in the side worktree failed". `git -C .git/tandem-backlog-app/main-worktree
  checkout -q --detach main` → "Your local changes to the following files would be overwritten
  by checkout: specs/FEATURE-HISTORY.md"; status ` D specs/FEATURE-HISTORY.md`, `ls-files -v`
  `H` (skip-worktree cleared). HEAD `e1b1e2c9` since 2026-11-01 15:07, one reflog entry.
- The side worktree was removed (`git worktree remove --force`; its commit was in `main`). The
  next attempt: "the side worktree of main could not be brought to main"; `specs/FEATURE-HISTORY.md`
  is an empty **folder** (made by `sync()`'s `mkdirSync` over `ls-tree` output).
- 15:59:51 the run of 425 ended its last turn (`result`, `end_turn`) but `claude.exe` stayed alive
  with no child and no CPU; the trace had `ScheduleWakeup` 1800 s at 14:45:50Z. The loop held the
  edit lock. Ending the Unity MCP relay (child of claude) did not help. The maintainer ended the
  processes by hand.

## Measurements at f8fc5084 (step 3)

### M1 - side worktree (part 1)

A temporary server test (`packages/server/test/zz-measure-tmp.test.ts`, deleted afterwards):
fixture repo + `specs/FEATURE-HISTORY.md` + `tools/x/backlog/a.txt`, `SideWorktree.sync(main)`.

```
SYNC1 FAIL: the side worktree of main could not be brought to main "HEAD 85c943e28506, status: D specs/FEATURE-HISTORY.md"
history exists: true DIR
nested backlog checked out: true
SYNC2 FAIL: git checkout in the side worktree failed "error: Your local changes to the following files would be overwritten by checkout:\n\tspecs/FEATURE-HISTORY.md ..."
```

Also measured in a scratch worktree of the real repository with the commands of `ensure()`: 50
tracked files outside `backlog/` are not skip-worktree after creation, 49 of them under a
`.../backlog/...` folder (non-cone pattern `backlog` matches at any depth).

### M2 - a pending wakeup keeps `claude -p` alive (part 2)

`claude -p '<call ScheduleWakeup 60 s, end turn SCHEDULED; when woken answer WOKE>' --output-format
stream-json --verbose --strict-mcp-config --model haiku --permission-mode bypassPermissions`:
`RESULT end_turn 'SCHEDULED'` at once, then `command_lifecycle started wakeup_source loop_wakeup`,
`RESULT end_turn 'WOKE'`, exit 0 after **122 s**.
With `ScheduleWakeup 600 s` then `ScheduleWakeup {stop: true}` ("cancelled 1 pending
wakeup(s)"): exit after **5 s**.

### M3 - status after the hard stop (part 3)

`.git/tandem-backlog-loop/run.json` after the manual end of 425: phase `killed`, `rows_before`
189, `lock_started` null; `backlog/RUNS.md` has 190 rows (the item's `closed` row). By reading
`Loop.pending()`: `our_row()` finds `closed`, the lock is not the run's → `conclude()` →
`finished` - the next start would not resume. But `cmd_status` prints "the next
bin/backlog-loop.sh start continues this run in the same session". The trace's `meta.json`:
phase `killed`, `ended` null.

### M4 - the stream's catch-up (part 4)

`scratchpad/catchup.ts` replays the catch-up loop of `packages/server/src/api/runs.ts` (1 MB pages
of `RunService.events`, `send()` with its shared `offset`) over the 425 trace (15,750,652 bytes):

```
catch-up stopped after 1 pages at offset 1046802 (page next 1046802, events 211)
events sent by the catch-up: 211 of 1694; file read to 15750652
phase from the catch-up: specify; phase of the whole trace: done
```

`send()` sets `offset = event.end` = `page.next`, so `page.next <= offset` ends the catch-up after
the first page. A first replay that did not move the offset per event (my mistake) sent all 1694
and folded `done` - the per-event update is what breaks it.

## Baseline (T002)

- `npm run check` in `tools/backlog-app`: typecheck, lint, format clean; vitest 26 files passed,
  1 skipped; 519 tests passed, 2 skipped.
- `python -m unittest` in `tools/backlog`: 258 tests, OK (284 s).

## Part 1 - side worktree (T003-T005)

- Tests added to `side-worktree.test.ts` (a file directly under `specs/` + a nested `backlog/`
  folder, ten rounds of sync/change/land while main changes that file; a dirty worktree with a
  folder at the file's path, a deleted and a changed file). **Negative control on the old code:
  2 failed** - "the side worktree of main could not be brought to main" and "git checkout in the
  side worktree failed", the two errors the maintainer saw. After the fix: 9/9 passed.
- Fix (`side-worktree.ts`): `ls-tree -d` for the empty feature folders; `reset --hard` + `clean`
  before the checkout; `sparse-checkout set --no-cone /backlog/` on every sync (an existing
  worktree with the old pattern takes the new one; `reapply` kept the stored pattern).
- Measured (research R1): `reset --hard` alone replaces an empty folder standing at a tracked
  file's path - the dirty-worktree test passed with the explicit folder removal taken out, so that
  removal was dropped (no code that deletes anything was added).
- The refusal's reason: `errorText()` in `web/src/lib/api.ts` (message + textual detail, cut at
  600 whole characters) used by `useChange` (the change dialogs, among them the new item) and
  every toast that showed `error.message`; `test/error-text.test.ts` 4/4. Details that are
  objects (e.g. `{ written }` of a refusal) are not shown, as before.

## Part 2 - a finished run that lingers (T006-T009)

- `fake_claude.py`: `linger` (stay alive after the final result) and `after` (an assistant line
  after the result) for `close`/`block`/`split`/`notrepro`, `stall`, `row-keep-lock` and
  `branch-hang`.
- `test_loop.py` `FinishedRunTests` (5 tests, grace patched to 0.3-0.5 s). **Negative control
  with `loop.py` of HEAD: 3 failed** - the lingering closed run took 45.7 s (its whole linger),
  the lingering return held on 46.5 s, and `status` printed "the next bin/backlog-loop.sh start
  continues this run in the same session". The two guards (lock still held; activity after the
  result) pass on both, as they must. After the fix: 5/5 in 13.7 s.
- `loop.py`: `FINISH_GRACE = 30.0`; `LogInfo.last_kind` (the newest object that shows work;
  `rate_limit_event` does not count, a subagent line does); `watch()` ends the process when the
  run is finished (`run_finished()`: the item's row since `rows_before`, the lock not the run's),
  the newest object is a `result` and no line came for the grace period. `execute()` then
  releases the edit lock and `conclude()` records the run as finished (verdict `finished`).
- Skill: `tandem-backlog-implement/SKILL.md` step 7 (a wakeup only for a reviewer or a command;
  never to wait for the maintainer; `ScheduleWakeup` `stop: true` before the final message) and
  §11 (the first line).

## Part 3 - status after a hard stop (T010-T011)

- `finished_outcome()` + `describe()["finished"]`; `cmd_status` prints "the run finished
  (<outcome>); the next bin/backlog-loop.sh start records it" instead of the continuation lines.
- `conclude()` of a `finished` verdict already calls `drop_run()` → `finish_trace()` (final
  `meta.json` with `ended`): the test checks it; no change needed there.
- The app reads `status --json` with a non-strict zod schema: the new key is ignored there.

## Part 4 - the stream's catch-up and the page's phase (T012-T016)

- `test/trace-stream.test.ts`: a 2.5 MB trace with two-event lines through `GET
  /api/runs/{id}/stream`. **Negative control on the old code: 908 of 3025 events.** After the
  fix: all 3025, the fold `review` as the whole file's, one id per line; a resume with
  `Last-Event-ID` continues after the last whole line.
- Fix (`api/runs.ts`): `sent` (end of the last line whose events were all sent) apart from the
  catch-up's `readAt`; the catch-up ends only when a page makes no progress; every event of a line
  is sent, the id only on the last one.
- `laterPhase()` in `shared/src/runs/run-state.ts` (+ test); `useTraceStream` keeps the `phase`
  event; `RunDashboard` shows `laterPhase(fold, laterPhase(run.phase, serverPhase))` and adds
  that phase to the timeline when the fold has not reached it.
- T016, the 425 trace through the real route (a temporary test, deleted): **1694 of 1694 events,
  phase `done`** (before: 211, `specify`).

## Findings fixed on the way

- The second and later events of a trace line were never streamed (`send()` skipped
  `end <= offset` after the first event of the line): part of the part-4 fix; covered by
  `trace-stream.test.ts` (severity 4).
- The non-cone sparse pattern `backlog` matched every folder of that name (49 extra files):
  pattern `/backlog/`, covered by the ten-rounds test (severity 1).
- A refusal of the app showed only its message, not git's reason: `errorText()` (severity 3).

## Checks after the change (T017)

- `npm run check` in `tools/backlog-app`: exit 0 - typecheck, lint, format clean; vitest 28 files
  passed, 1 skipped; **530 passed**, 2 skipped (baseline 519).
- `python -m unittest` in `tools/backlog`: **263 tests OK** (baseline 258).
- `python tools/test_bin_help.py`: OK. `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- The product is not touched (no build, saltests or probe applies; no UI string of the program).

## Review

Review 1 (refute-first, general-purpose agent): **no MUST, no SHOULD**. It reproduced all four
faults on the old code in a scratch worktree (both side-worktree errors; 908 of 3025 stream
events; 3 of 5 `FinishedRunTests` failing: 45.8 s, 46.7 s, "continues this run"), re-ran
`npm run check` (530 passed) and the Python suite (263 OK), streamed the real 425 trace (1694/1694,
`done`; a resume from the middle id gave exactly the rest), and upgraded an old broken side
worktree (three failed old syncs, then three new rounds landed, the flags back to `S`, the
primary tree clean). NOTEs:

1. A resume after a cut between two events of one line can show that line's earlier events twice
   (only the last event of a line carries the id; the client does not deduplicate). Allowed by
   the contract; transcript only, the phase fold is forward-only. Accepted (not driven: needs a
   connection cut mid-line).
2. The finished-run kill ignores background tasks: by the skill's order the work is over once
   the lock is released (released last); accepted by design (FR-005).
3. No test for a lingering claude of a dead loop found by the next start (`pending()` → `watch()`):
   **added** `test_a_lingering_claude_of_a_dead_loop_is_ended_by_the_next_start` (the loop process
   killed alone, the next in-process start ends the orphan within the grace); `FinishedRunTests`
   6/6.
4. `status` counts any lock of the same item as the run's own (stricter than `holds()`), so with
   a later manual run of the same item it says "continues" while the start records it finished:
   the cautious side; accepted.
5. Old review worktrees `C:/Users/pavel/AppData/Local/Temp/rev*` (features 325-414) are still
   registered: not this feature's; named in the closing report for the maintainer.

## Owed to a person

One line added to `manual-checks-owed-before-the-next-release` (feature 426): an item created in
the app during a real loop run lands on main; the loop concludes a run within about 30 s of its
last message even with a scheduled wakeup; the live page shows the server's phase.
