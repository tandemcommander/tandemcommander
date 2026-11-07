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
