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
  SC-002 (price = reported total after the last result) holds; before any result the estimate was within 3.3 % on these three and within 5.1 % on six traces of review 1; SC-004
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

## Review

### Review 1 (refute-first agent, at a4cf83f0)

No security hole, the read-only promise holds (routes, CSP, `meta.json` only of indexed runs,
open-read-close, chat snapshot cap and labelling, StrictMode-safe fold cache). Findings:

- **M1** (MUST) The Critical tab said "The build failed" / "Tests failed" when false: a combined
  command (build + saltests, build + probe) blamed the build for any non-zero exit; `saltests` in
  any path (a `grep` of `saltests.cpp`) was a test run. Fixed: a build fails only by `BUILD FAILED`
  or an error code; a `saltests:` summary or a probe's `FAIL n` in a build command blames the
  tests / the probe; a non-zero exit without them is a warning; saltests only when `saltests.exe`
  runs. Tests `blames only what failed in a combined command`.
- **S1** Times collapsed when the app started during a large run (each 4 MB chunk anchored "now";
  a truncated trace kept the old anchors). Fixed: one anchor at the file's size before reading,
  anchors reset on truncation. Test `spreads a large trace ...` (12 MB) - negative control with the
  old anchoring: fails (a line at a third of the trace stamped "now"); with the fix: passes.
- **S2** The output calibration had no test; research said 2.5, the code 2.7. Fixed: test
  `calibrates the output estimate ...`; research R3 says 2.7 (measured on 414).
- **S3** A gallery image was addressed by its place in a list that can grow in the middle.
  Fixed: a stable key (16 hex of SHA-256 of the real path) in the list and the route
  `/images/:key`; tests use the listed key and refuse a number, an unknown key, a path.
- **S4** Planned failures (mutants, probes before the fix) filled the Critical tab; one probe's pass
  resolved another probe's failure. Fixed: a failure before *implement* is a measurement, and
  mutant / before or without the fix / pre-fix / old build / at HEAD / baseline / reproduce mark a
  failure as intended (warn, not critical); a pass resolves only failures of the same subject
  (`checkSubject`: the probe scripts, the test files, the build, saltests). Tests. Over the 40
  latest real traces the open critical entries are now new backlog items, review MUSTs, a usage
  limit, a stop and a few probe and test failures of implementation.
- **S5** Attempt separators and the attempts' ends in `meta.json` were not anchors. Fixed: live
  separators anchor at once; an ended run without saved times anchors every separator's start
  and each attempt's end (before the next separator). Test `anchors an ended run's attempts ...`
  - negative control without the anchors: fails; with them: passes.
- NOTEs fixed: an object URL made after the image was no longer shown (now never made); the
  viewer keeps the focus inside (Tab cycles); the feature folder walk follows no links or
  junctions and stops at 300 folders; a document is cut by bytes at a line end; an unpriced run
  shows no price instead of "$0.00".
- NOTEs accepted (recorded): a tiny race between the real-path check and the read of an image (a
  local process swapping a link in the window - the app serves only to the same user on
  127.0.0.1); the per-attempt price sum is unverified on a real continued run (none of 265
  traces has a second attempt; if `claude --resume` restored its cost, a continued run's price
  would double - the next continued run shows it, and a reported total is labelled as such);
  past 50 000 events the stream's list is trimmed every batch and refolded (about 300 ms a
  frame; no real run has come near); `cache/times/*.json` (a few KB each) are not pruned; each
  live snapshot stays in a resumed chat's context (the cost of a long conversation grows; the
  snapshot is capped at 8 000 characters).

After the fixes: `npm run check` 445 passed, 2 skipped; Playwright `us7`, `us4-chat`, `a11y`
(both themes), `us5-us6`, `us2-loop`: 13 passed.

### Review 2 (refute-first agent, at 2289abf0)

No MUST; security and the read-only promise re-verified; review 1 fixes confirmed (M1 for the
tested cases, S1 live, S2, S3 server side, S5 without saved times, the NOTEs). Five SHOULDs, all
fixed:

- **S-A** Commands were classified by text anywhere in them (heredocs, `grep msbuild`, `sed ...
  run-story.test.ts`), so a mention could "resolve" a real failure; a saltests failure of a
  combined command was resolved by a plain build. Fixed: `programsOf` - the programs a command
  runs (first word of each part, heredoc bodies left out, the script of `powershell -File`,
  `python`, `node`, `bash`, the subcommands of `npm`, `npx`, `git`); classification uses only
  them, from the full command with its lines (`info.command`; the summary joins lines);
  `checkSubjects` lists every check a command runs and the failing one is remembered, so a pass
  resolves only failures of a check it ran too. Tests (the four commands of the review are
  SHELL; build failure not resolved by `grep msbuild`; combined saltests failure resolved by
  saltests only).
- **S-B** Runs that never call `speckit-implement` stayed in *analyze* and hid every failure as a
  measurement. Fixed: the first change of a source file (not `specs/`, `backlog/`, traces,
  temporary files) in *tasks* / *analyze* starts *implement* (`RunState`); a failure is a
  measurement only before implement **and** before any source changed. Test; negative control by
  reasoning (without the marker the phase stays *tasks*: the test's timeline check fails).
- **S-C** More words of failures on purpose: mutation, on purpose, before-probe, old handler /
  binary, "with the ... removed / disabled / reverted / altered / broken / undone", altered,
  reverted. Test with the review's phrases.
- **S-D** An ended run the app had followed for a while kept only its saved anchors, so every
  line after them got one time. Fixed: the separators and `meta.json`'s ends are added always.
  Test (saved anchors for the first fifth); negative control with the old condition: fails.
- **S-E** The viewer kept the open image by its place. Fixed: by key; thumbnails keyed by key.
- NOTEs fixed: stale "by number" comments; a document without a line end in its first 1 MB is
  cut at a character boundary; truncation reset now tested; attempt texts are parsed safely
  (`safeParse` in `RunState`, `RunMetrics`, `RunStory`); consecutive turn ends are one line. Found
  on the way (severity 2): a review's MUST entry stays open after a later review reports none or
  the MUST fixed -> resolved by such a message (test).
- NOTE accepted: thumbnails fetch the full image (at most 200, 25 MB each; the gallery of a real
  run holds a few probe captures).

Over the 40 latest real traces the open critical entries after these fixes: review MUSTs not
reported fixed in the trace (6), a usage limit, a stop, two probe failures of implementation,
new backlog items and person steps - each a fact the reader should know. Feature 414's trace:
5 critical entries, all resolved later (three test failures passed again, two review MUSTs
fixed).

After the fixes: `npm run check` 451 passed, 2 skipped; Playwright `us7`, `us4-chat`, `a11y`,
`us5-us6`: 9 passed.

### Review 3 (refute-first agent, at 52570947)

- **M1** (MUST) The `programsOf` of review 2 read only the first word of each part, so the
  PowerShell and `cmd` forms the runs use (`$o = .\build.cmd`, `cmd /c build.cmd`, probes inside
  `foreach { }`, `& "...saltests.exe"` after an assignment, `Start-Process`, `powershell -Command
  "..."`) were no builds, tests or probes: four real build failures and three probe failures of
  real traces became warnings, a stale pass after a failed build resolved a real probe failure,
  and a saltests failure found no check to blame. Fixed: a new module `command-parse.ts` reads
  commands with quotes, line continuations, heredocs (also cut short), parts split at `; | || &&`,
  a background `&`, line ends, braces and parentheses outside quotes, assignments, call operators,
  `cmd /c`, `Start-Process [-FilePath]`, `powershell -File / -Command`, `bash -c`, `timeout N`,
  npm options (`--prefix`, `-w`). A command's checks are judged together (`judgeChecks`): the
  build by `BUILD FAILED` / an error code even when the command also runs saltests or a probe,
  saltests by its summary, a probe by its FAIL rows, tests by their counts; the first failing
  check is blamed. Tests: the review's 42 adversarial commands (`command-parse.test.ts`, all
  pass; the review-2 code missed 25), plus checks of combined and launched commands.
- **S1** Splitting ignored quotes (a `grep -E "powershell|msbuild"` or a commit message with
  `; ./build.cmd` became a build). Fixed by the same reading (tests).
- **S2** `isSourcePath` counted scratch probe scripts under `build\` or outside the repository as
  source changes, so planned before-probes became critical. Fixed: inside the session's root
  only, not under `specs`, `backlog`, `build`, `out`, `dist`, `node_modules`, `test-results`,
  traces, `.specify`, `.claude`, `.git` (a repository in `%TEMP%` judged by its own folders).
  `RunState` takes the root from `system/init` too. Tests.
- **S3** More phrasings of planned failures (mutated, with control A-E, with the ... bug, before
  (the) review fix, before probe, on the installed, the HEAD build); a pass on purpose resolves
  nothing. Tests.
- **S4** `MUST_CLEARED` cleared open MUSTs on loose wording. Fixed: only "found / has / with no
  MUST", "0 MUST", "the MUST (of review N) is fixed", "review N's MUST is fixed", and not with
  "still open", "stays open", "brings it back", "next: the MUST", "not fixed", "but ... MUST"; a
  MUST "which is fixed" in the same message opens none. Tests with the review's phrases.
- NOTEs fixed: npm with `--prefix` / `-w` reads its subcommand; the test-runner rule lists only
  test subcommands; a heredoc cut short is left out to the end; an ended run's times are rebuilt
  when its trace grows; the gallery closes the viewer for good when its image leaves the list;
  `trim()` never drops a critical entry. NOTE accepted: a document whose only early line end
  leaves just its first line within the 1 MB cut.
- Re-measured with the review's scripts over all 264 traces (against the review-1 code): open
  critical entries lost 51 / gained 15. The lost ones are now resolved by a later pass of the same
  check or marked as planned ("with the broken rule", "without the M1 fix", "pre-review build",
  "negative-control build"); the gained ones are real probe and build failures now recognised in
  PowerShell forms (regression probes, probes inside loops). Real build failures by their
  output: 20 build and 27 saltests failures critical as before.

After the fixes: `npm run check` 499 passed, 2 skipped (125 in `shared`); Playwright `us7`,
`a11y`, `us5-us6`, `us4-chat`: 9 passed.

### Review 4 (refute-first agent, at 709c0f08)

Three MUSTs - the third review with a MUST finding (reviews 1, 3, 4). Stop-rules §3 #3 makes
that a stop; its preamble asks first to remove the cause with a different approach. The three
findings are narrow and concrete (two of them are older defects of the phase machine of 344 that
the new Critical tab made visible), so they were fixed with tests and negative controls, and a
fifth review decides: a MUST in it blocks the item (work kept on the branch).

- **M1** A probe whose output says "RESULT: 2 row(s), 0 FAIL" or "TOTAL: 42 PASS / 0 FAIL"
  counted the word FAIL as one failed row ("A GUI probe failed" on runs that closed green).
  Fixed: per line, a summary count before or after the word ("FAIL 0", "0 FAIL") is the count;
  only a line without a count is a row. Test; on all 264 real traces the review's script finds 0
  such entries (it found 7).
- **M2** `BLOCK_MARKER` matched the whole command text, so a note saying "block" put a closing
  run on the stop path for the rest of the run (3 real traces). **M3** `git merge-base` and
  quoted mentions of `git merge` jumped the phase to *merge* (3 real traces). Fixed: the phase
  markers of `RunState` are read from the programs a command runs (`programsOf`, which now names
  the backlog tool's subcommand: `backlog block`, `backlog lock acquire`, `backlog verify`, ...),
  never from its text. Tests; the review's timeline script finds none on the real traces.
- **S1** Bash's `'\''` escape, **S2** a PowerShell string ending in a backslash
  (`"$env:TEMP\x\"`), **S3** `#` comments, **S4** a quoted text assigned to a variable: read
  right now (tests; the build and probe commands of the review's real traces are recognised).
- **S5** More planned-failure words: main's build / Release / plug-in, on main's, as a control,
  pre-review. **S6** A commit chained with backlog steps is told as the commit (a new item or a
  block stays that); the chat snapshot counts the branch's commits from git (a run commits with
  `-q`, so the trace shows none). **S7** MUST counts read the upper-case MUST only and never
  "review 1 MUST"; "fixed at once" needs "MUST ... which is fixed". Tests.
- NOTEs fixed: the encoding guard's total is its own `TOTAL: n finding(s)` line; a document is
  read only when its real path lies inside the repository. NOTEs accepted: tests with a non-zero
  exit and a passing count end as a warning (the counts are believed); `Start-Process ...
  -ArgumentList` with a probe, `pwsh -f`, `Invoke-Expression`, `xargs` are not read (none in the
  real traces).
- Negative control: the six new tests (`review4.test.ts`) all fail with the code before these
  fixes and pass with it.

After the fixes: `npm run check` 506 passed, 2 skipped; Playwright `us7`, `a11y`, `us5-us6`,
`us4-chat`, `us2-loop`: 13 passed.
