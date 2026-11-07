# Closing report - 415-live-run-dashboard

Backlog item: backlog-app-live-run-human-dashboard - Live run view: a human-readable dashboard with story, metrics, gallery and chat
Outcome: blocked - the fourth review with a MUST finding stopped the run (stop-rules §3 #3); the feature is complete on branch `415-live-run-dashboard`, the review-5 fixes are not yet reviewed, nothing is merged into `main`

## What changed

The backlog app's *Live run* page (and the page of an ended run) is a dashboard a person reads
without knowing the trace format:

- a progress head: the item, feature and branch, a progress bar with the percentage, elapsed
  time, expected remaining time and expected end (an estimate from the phase, the tasks of
  `tasks.md` and the median of earlier closed runs, its basis shown), and the steps of the
  flow with the time each took;
- a "now" panel: the current activity in one sentence and since when, the agent's latest
  message, a warning while a GUI probe runs;
- live figures: the price at list prices (claude's reported total plus the tokens since, priced
  per model - before, the page knew no cost for hours), $/h, input / output / cache tokens,
  context in use, tool calls and failures, subagents, files changed, commits, the usage-limit
  utilisation;
- tabs: **Story** (the run told in sentences grouped by phase, icons, coloured labels, outcomes in
  colour, routine reads and edits collapsed, subagent work folded under its agent, the agent's
  messages as Markdown, search, "only what matters", "Latest"), **Critical** (open and resolved:
  failed builds / tests / probes / encoding checks of the implementation, error turns, a stop,
  usage limits, review MUSTs, new backlog items and person steps; planned failures - measurements
  before the fix, negative controls, mutants - are not critical), **Decisions** (the spec's
  clarifications and assumptions, the agent's statements of a decision), **Gallery** (the
  screenshots the run looked at or saved and the images of its feature folder; a full-screen
  viewer with swipe, arrow keys, a thumbnail strip, Escape), **Architecture** (the flow of the
  run, a map of where the change happens by component, the diagrams of `plan.md`), **Files**,
  **Documents** (the feature's spec, plan, tasks, fix-log as they are now), **Raw trace**;
- a chat column (an overlay on narrow windows): the item conversation of 371 with ready
  questions; every message carries a fresh snapshot of the run (at most 8 000 characters, data
  never instructions).

Inside: pure folds in `packages/shared/src/runs/` (`run-story.ts`, `run-metrics.ts`,
`pricing.ts`, `run-progress.ts`, `time-index.ts`; `TraceEvent.info` carries the facts of each
line); the server gives every event a time (anchors saved per run), folds the live run for the
chat snapshot and serves the run's insight, documents and gallery images (by key, only from the
run's own list, only inside the repository or the temporary folder); the CSP allows `blob:`
images (fetched with the bearer token).

## Measurements (before / after, commands)

- Before (at 90667c3f): the page showed a summary card and one line per trace event; tokens 0,
  the cost only at a `result` line - in the 414 run the first came after about three hours.
- After, `node tools/backlog-app/packages/shared/test/fold-real-trace.ts <trace>` on real traces:
  every main-thread call told (0 untold), none by a raw command where it had a description, the
  price equal to claude's reported total after the last result (414: 34.091 / 34.091), within
  0.3 - 5.1 % before any result; fold of a 6 MB trace 10 - 22 ms.
- SC-003: the e2e test sees a line in the story within 3 s of its being written.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `npm run check` (tools/backlog-app): typecheck, lint, format clean; 451 tests passed, 2 skipped
  (baseline 366).
- `npm run test:e2e`: 39 passed after adapting one test to the dashboard (the run page's
  transcript is its *Raw trace* tab); after the review fixes `us7`, `us4-chat`, `a11y`,
  `us5-us6`, `us2-loop` passed again.
- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`; `bin/backlog.sh check`:
  `TOTAL: 0`.
- No product code changed: `build.cmd`, `saltests` and GUI probes are not affected.

## Reviews (findings and what was done)

- Review 1: 1 MUST (false build / test blame in the Critical tab), 5 SHOULD (late-follow times,
  calibration untested, image index, planned failures critical, attempt anchors), NOTEs - all
  fixed with tests and negative controls; accepted NOTEs recorded in `fix-log.md`.
- Review 2: 0 MUST, 5 SHOULD (classification by mention, runs without the implement skill,
  planned-failure words, half-followed ended runs, viewer by index), NOTEs - all fixed with
  tests.
- Review 3: 1 MUST (PowerShell / cmd forms not read), 4 SHOULD - fixed.
- Review 4: 3 MUST (probe "0 FAIL", a note saying "block", `git merge-base`), 7 SHOULD - fixed.
- Review 5: 1 MUST (the `$BL` form of the backlog tool not read by the phase markers) - fixed on the branch, not reviewed; the run stops here.

## Owed to a person (the lines added to the release checklist)

None: the backlog app is a development tool, not shipped; everything was driven by the e2e tests
(the real loop with the fake claude replaying a recorded trace). Optional by eye: open *Live run*
during the next real loop run.

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

See `fix-log.md` *Findings fixed on the way* and the review sections: false MUST criticals on
"no MUST", negative controls as failures, a probe summary "FAIL 0" counted, vitest's file count
taken as the test count, the story stuck after a search, paths of a repository in `%TEMP%`, two
accessibility violations, review MUSTs never resolved.

## New Inbox items (slug - title)

None.

## CHANGELOG

No entry: the backlog app is a development tool outside the product (features 344, 371 and 414
added none either).
