# Fix log - 415 live run dashboard

Backlog item `backlog-app-live-run-human-dashboard`. Autonomous run started 2026-11-07 at
`90667c3f` (main), branch `415-live-run-dashboard`.

## Measure (before the change, at 90667c3f)

- Read `packages/web/src/features/live/live-page.tsx`: `LivePage` = `RunSummary` + `TraceView`.
  `TraceView` lists one row per event (time, tool name, one-line summary). Confirmed the gap.
- `packages/shared/src/runs/run-state.ts`: the cost comes only from `result` summaries
  (`$x.xx`); `RunsService.liveRun()` returns `inputTokens: 0 …`.
- Python fold of `.agent-traces/20261107-104104-claude-backlog-app-triage-position-on-move-from-inbox/trace.jsonl`
  (6.0 MB): line types `assistant` 1100 (588 unique `message.id`, 581 lines with
  `parent_tool_use_id`), `user` 611, `system/thinking_tokens` 614, `system/task_progress` 337,
  `task_started` 146, `task_notification` 146, `tool_progress` 93, `rate_limit_event` 61,
  `result/success` 12, `system/init` 12, one `backlog_loop.attempt`.
  - Usage per unique message summed: input 1 208, cache read 98 521 088, cache write 1 249 805
    (5 min 833 484, 1 h 416 321) = exactly the last result's `modelUsage`; output 8 455 vs
    344 201 reported (the stream carries the count at the start of the message only).
  - Text characters 49 225, tool input JSON 405 251 characters.
- Price check: Opus 5.5 at $4 / $20 / read $0.20 / write 5 min $5 / 1 h $8 per million on the
  `modelUsage` of a result (input 1 202, output 343 692, read 97 653 679, write 5 min 833 484,
  1 h 414 817) = $33.899 vs `costUSD` 33.8953.
- Images read by recent runs (grep of 40 traces): 13 distinct PNG paths, under
  `specs/NNN-*/probe/`, `backlog/items/*/evidence/` and `%TEMP%`.
- Baseline `npm run check` (tools/backlog-app): typecheck, lint, format clean; vitest 20 files
  passed, 1 skipped; 366 tests passed, 2 skipped (111.9 s).
- The Spec Kit branch script's dry run (`create-new-feature.sh --dry-run`) did not finish in
  90 s here (its remote-branch scan); the number was taken by hand (highest 414 in `specs/`, local
  and remote branches) and the real script ran with `GIT_BRANCH_NAME` (no scan) - created
  `415-live-run-dashboard`.

## Decisions

See `spec.md` *Clarifications* and `research.md`.

## Analyze (speckit-analyze, 2026-11-07)

- A1 HIGH: FR-005 "tool errors a step depended on" untestable -> FR-005 names the critical
  sources (builds, tests, probes, encoding guard, error turns, stop, limits, review MUST, new
  items, person steps); other tool errors are story warnings. Fixed.
- C1 MEDIUM: SC-003 (3 s) had no check -> T035 measures it in the e2e test. Fixed.
- F1, F2 LOW: wording in story-rules; edge case of replay times covered by research R4. Fixed.
- Second pass: no CRITICAL / HIGH left; coverage 18/18 FR, 7/7 SC.

## Work log

- Shared (`packages/shared/src/runs/`): `TraceEvent.info` (description, file, subagent type,
  message id, model, usage, output characters, a result's cost and totals, rate-limit windows,
  task status, the end of a long result, the session's cwd); `time-index.ts`, `pricing.ts`,
  `run-metrics.ts`, `run-progress.ts`, `run-story.ts`; tests `run-figures.test.ts`,
  `run-story.test.ts`, helper `test/helpers/trace.ts`, script `test/fold-real-trace.ts`.
- Server: time anchors of the live run (saved in `cache/times/<run>.json`, interpolated `at` for
  every event of the stream and the event pages, also for ended runs from `meta.json`); the live
  run folds `RunStory` + `RunMetrics` (the chat snapshot, `liveRun().cost` with tokens);
  `runs/insight.ts` + routes `/runs/:id/insight`, `/runs/:id/documents/:name`,
  `/runs/:id/images/:n`; CSP `img-src 'self' data: blob:`; `chat/live-snapshot.ts` and the snapshot
  before every message of a live item; one rule in `ai/prompts/chat.md`. Tests `insight.test.ts`,
  a gate test of the new routes.
- Web: `features/live/` (dashboard, progress header, now panel, metrics strip, story / critical /
  decisions, gallery + viewer, architecture diagrams, files / documents, labels, fold hook);
  `features/chat/chat-panel.tsx` (the conversation as a component, used by the chat window and the
  dashboard); the ended run's page uses the dashboard.
- Tests: `tools/backlog/fixtures/fake_claude.py` step `replay` (plays a recorded trace, copies a
  feature folder, names the branch in the lock); fixture `e2e/fixtures/live-run-trace.jsonl` (59
  lines) and `e2e/fixtures/live-feature/`; `e2e/us7-live-dashboard.spec.ts`.

## Measurements after the change

- Real traces folded by `node packages/shared/test/fold-real-trace.ts` (Node 24 = the browser's
  V8):

  | Run | events | story entries | critical | untold calls | raw titles with description | price / reported | price without results | fold |
  |---|---|---|---|---|---|---|---|---|
  | 414 triage position (6.0 MB) | 2496 | 388 | 4 | 0 / 267 | 0 | 34.091 / 34.091 | 33.981 (-0.3 %) | 13 ms |
  | 413 tab drag (3.1 MB) | 1052 | 220 | 4 (all resolved) | 0 / 182 | 0 | 18.184 / 18.184 | 17.578 (-3.3 %) | 10 ms |
  | 412 state files (3.6 MB) | 1340 | 264 | 2 | 0 / 209 | 0 | 16.914 / 16.914 | 16.589 (-1.9 %) | 10 ms |

  SC-001 (every main-thread call told; none by a raw command where it had a description) and
  SC-002 (price = reported total after the last result; within 3.3 % before any) hold; SC-004
  (< 2 s) by two orders of magnitude.
- `npm run check`: typecheck, lint, format clean; vitest 23 files passed, 1 skipped; 440 tests
  passed, 2 skipped (baseline 366).
- `npx playwright test e2e/us7-live-dashboard.spec.ts`: passed (1.2 min) - story lines, SC-003
  (the last line in the story within 3 s of being written), figures with a price and the usage
  limit, Critical (open: the new item; resolved: the failed build), Decisions, Gallery + viewer
  (arrow, Escape), Architecture, Documents, chat (the message claude received starts with the
  snapshot, carries `Tasks: 3 / 5` and the question), axe in light and dark (no serious or
  critical violation), the ended run's page.
- Screenshots of the e2e run (light, dark, each tab, viewer) were looked at; they are not
  committed (the fixture paths are temporary).

## Findings fixed on the way

- Severity 3: the first story fold counted "0 MUST" / "no MUST" review summaries as MUST findings
  (13 false critical entries in the 414 trace) -> `mustFinding` takes a count above zero only;
  unit test.
- Severity 3: negative controls (a test meant to fail) were critical failures -> told as
  "failed, as a negative control should" (warn); unit test.
- Severity 3: a probe's summary "Rows: PASS 29, FAIL 0" counted as a FAIL -> summary counts are
  summed; unit test.
- Severity 3: vitest's "Test Files 20 passed" was taken as the test count -> its `Tests` line is
  read; other runners' last summary; unit test (found by the e2e test).
- Severity 2: after a search the virtualised story stayed in the middle and stopped following the
  run -> a changed filter starts the list at its end; "Latest" returns to the end after scrolling
  up (found by the e2e test, SC-003).
- Severity 2: paths of a repository in `%TEMP%` (the fixtures) were all "temporary files" -> paths
  are relative to the session's `cwd` from `system/init`, top-level folders after it otherwise.
- Severity 2 (a11y): the progress header's `<dl>` nested its items too deep, the story used
  `role="feed"` without articles -> flat `dl`, `role="log"` (axe in the e2e test).

## Deviations

- The fold runs in the browser over the events it already receives (research R10); the server
  folds the live run again only for the chat snapshot.
- Output tokens between reported totals are an estimate (characters x calibration); the price is
  marked "estimate at list prices" until claude reports its total.
- The phase weights of the progress estimate are fixed (research R5), not learned from history;
  only the total duration uses history (median of the last 40 closed item runs).

## Full end-to-end suite

- `npm run test:e2e` (build + all specs): 38 passed, 1 failed - `us5-us6` Q16 looked for the
  transcript's first line on the run page, which is now the dashboard with the transcript under
  *Raw trace* (an intended change). The test opens that tab (and checks the dashboard's head
  first); rerun `npx playwright test e2e/us5-us6.spec.ts -g Q16`: passed.
