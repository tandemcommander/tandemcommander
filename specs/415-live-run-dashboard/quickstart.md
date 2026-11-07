# Quickstart - feature 415 validation

Prerequisites: Node.js 24.15+, Python, `tools/backlog-app` dependencies installed (`npm ci`).

## Q1 - unit rules (shared folds, server)

```sh
cd tools/backlog-app
npm run check          # typecheck, lint, format, unit tests - all green
```

Expected: the new suites `run-story`, `run-metrics`, `run-progress`, `time-index`, `pricing`,
`trace-event` (info), `insight`, `live-snapshot` pass; the gate test covers the new routes.

## Q2 - the real trace of feature 414 (SC-001, SC-002, SC-004)

```sh
node tools/backlog-app/packages/shared/test/fold-real-trace.ts .agent-traces/20261107-104104-claude-backlog-app-triage-position-on-move-from-inbox/trace.jsonl
```

Expected: every main-thread tool call yields an entry; no entry title is a raw command where the
call had a description; the live price after the last result is within 1 % of the reported total;
the fold time is printed (< 2 s).

## Q3 - end to end (us7-live-dashboard)

```sh
cd tools/backlog-app && npx playwright test e2e/us7-live-dashboard.spec.ts
```

The loop runs the fake claude with the step `replay`, which plays a recorded trace (fixture) into
the run's trace while holding the item. Expected: the live page shows the progress bar, the "now"
panel, metrics with a price, the story with labelled entries, a Critical tab with a count, the
gallery thumbnail of the fixture screenshot opening in the viewer (arrow keys, Escape), the
Architecture map, the chat panel sending a ready question whose message (seen by the fake chat)
starts with the live snapshot; axe finds no serious violation in both themes.

## Q4 - by eye (optional, a person)

Start the app on a copy of the repository with `--root`, start the loop on a small item, open
*Live run*: read the story while the run works; open the gallery during a GUI feature.
