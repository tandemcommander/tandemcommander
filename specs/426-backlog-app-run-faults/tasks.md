# Tasks: The backlog app and the loop during a run

**Input**: Design documents from `specs/426-backlog-app-run-faults/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/trace-stream.md
**Tests**: required by the spec (FR-012: each fault reproduced on the old code, negative controls).

## Phase 1: Setup

- [X] T001 Start `specs/426-backlog-app-run-faults/fix-log.md` with the measurements of step 3 (the four reproductions, commands and results)

## Phase 2: Foundational

- [X] T002 Run the suites before any change and record the baseline in `specs/426-backlog-app-run-faults/fix-log.md`: `npm run check` in `tools/backlog-app`, `python -m unittest` in `tools/backlog`

## Phase 3: User Story 1 - change the backlog from the app during a run (P1)

**Independent test**: `side-worktree.test.ts` with a file directly under `specs/` fails on the old code and passes on the new.

- [X] T003 [US1] Add tests to `tools/backlog-app/packages/server/test/side-worktree.test.ts`: (a) a fixture with `specs/FEATURE-HISTORY.md` and a nested `tools/x/backlog/a.txt`: ten rounds of sync + change + commit + landOnMain while main also changes `specs/FEATURE-HISTORY.md`, the file never becomes a folder, the nested file is not checked out; (b) a dirty worktree (an empty folder at the path of a tracked file under `specs/`, a tracked file deleted, one changed) after main moved: `sync()` repairs it; run them on the old code first (negative control, record in fix-log)
- [X] T004 [US1] Fix `SideWorktree.sync()` and `SPARSE_PATTERNS` in `tools/backlog-app/packages/server/src/backlog/side-worktree.ts`: `ls-tree -d`, the clean-up before the checkout (empty folder at a file's path, `reset --hard`, `clean`), pattern `/backlog/`; update the file comment
- [X] T005 [P] [US1] Add `errorText(error)` (message plus a string detail, shortened) to `tools/backlog-app/packages/web/src/lib/api.ts` and use it in the toasts of the backlog changes (`features/backlog/*.tsx`, `features/tray/tray-drawer.tsx`, the new-item form and the other `toast.error(... error.message ...)` sites); a web test of `errorText` in `tools/backlog-app/packages/web/test/`

## Phase 4: User Story 2 - a finished run ends (P1)

**Independent test**: a loop test where the fake claude closes the item, prints its result and keeps running; the loop records it closed within seconds (fails on the old code: the deadline ends it).

- [X] T006 [US2] Add a `linger` option to `finish()` in `tools/backlog/fixtures/fake_claude.py` (sleep that many seconds after the result, as a pending wakeup does) and describe it in the docstring
- [X] T007 [US2] Add tests to `tools/backlog/test_loop.py`: a lingering closed run is ended and counted closed well before its linger ends and the edit lock is released; a run that ends a turn while it still holds its lock is not ended (existing `hang`/`stall` behaviour stays); a finished run whose stream shows new activity after the result (a further assistant line) within the grace period is not ended before that activity is followed by quiet; run the first on the old code (negative control)
- [X] T008 [US2] Implement the finished-run end in `watch()` of `tools/backlog/loop.py` (`--finish-grace` hidden option, default 30 s; condition: this run's process, the item's journal row since `rows_before`, the lock not the run's, the newest stream object a `result`, no new line for the grace period); a `say()` line naming it
- [X] T009 [P] [US2] Add the rule to `.claude/skills/tandem-backlog-implement/SKILL.md` (step 7 wakeup rules and §11): cancel pending wakeups with `ScheduleWakeup` `stop: true` before the final message on every path; never wait for the maintainer's program with a wakeup

## Phase 5: User Story 3 - status of a finished run after a hard stop (P2)

**Independent test**: a loop test with a `killed` run record whose row is written and lock gone: `status` says finished; `start` concludes it without calling claude.

- [X] T010 [US3] Add tests to `tools/backlog/test_loop.py` for the status text and JSON `finished`, and for the start that concludes without a claude call and writes `meta.json`'s end
- [X] T011 [US3] Implement in `tools/backlog/loop.py`: `describe()` key `finished`, `cmd_status` lines; check that `conclude()` of `finished` finalizes `meta.json` (fix if not)

## Phase 6: User Story 4 - the live page shows the real phase (P2)

**Independent test**: a server stream test with a trace larger than one page and multi-event lines delivers every event (fails on the old code); a shared test of `laterPhase`.

- [X] T012 [US4] Add a stream test in `tools/backlog-app/packages/server/test/` (a trace of more than 1 MB with multi-event lines; read `GET /api/runs/{id}/stream` of an ended run and count events) and run it on the old code (negative control)
- [X] T013 [US4] Fix the catch-up and `send()` in `tools/backlog-app/packages/server/src/api/runs.ts` per `contracts/trace-stream.md` (read position apart from the sent position; every event of a line sent; the SSE `id` only on the last event of a line)
- [X] T014 [P] [US4] Add `laterPhase(a, b)` to `tools/backlog-app/packages/shared/src/runs/run-state.ts` (exported; forward order; `stopped` wins) with a test in `tools/backlog-app/packages/shared/test/`
- [X] T015 [US4] Handle the `phase` event in `useTraceStream` (`tools/backlog-app/packages/web/src/features/runs/trace-view.tsx`) and use it as the lower bound of the phase and timeline in `tools/backlog-app/packages/web/src/features/live/run-dashboard.tsx`
- [X] T016 [US4] Replay the 425 trace with the new catch-up (the measurement script of research R4) and record the numbers in the fix-log

## Phase 7: Polish

- [X] T017 Run `npm run check` in `tools/backlog-app`, `python -m unittest` in `tools/backlog`, `python tools/test_bin_help.py`, `python tools/check_encoding.py --strict`; record in the fix-log
- [X] T018 Update `architecture/` or the app's `README.md` only where they describe the changed behaviour (search `side worktree`, `catch-up`)

## Dependencies

- T001-T002 first. US1 (T003-T005), US2 (T006-T009), US3 (T010-T011), US4 (T012-T016) are independent.
- In each story the test task comes before its fix (negative control).
- T017-T018 last.

## Parallel examples

- T005, T009 and T014 touch separate files and can be done alongside the other stories.

## Implementation strategy

All four stories belong to the item; they are done in order US1, US2, US3, US4, each tested on the
old code first, then fixed, then the full suites.
