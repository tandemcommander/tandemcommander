---
title: Live run view: a human-readable dashboard with story, metrics, gallery and chat
type: feature
status: blocked
severity: 4
area: tooling
source: manual
who: agent
created: 2026-11-07
updated: 2026-11-07
verified: -
effort: L
feature: -
related: []
depends-on: []
reason: the fifth independent review found a MUST (the fourth review with one, stop-rules 3 #3): the phase markers missed the $BL form of the backlog tool; fixed on the branch after it, not reviewed. The feature is complete there: review the review-5 fixes, then merge (feature 415, branch 415-live-run-dashboard)
---

# Live run view: a human-readable dashboard with story, metrics, gallery and chat

## Problem

The *Live run* page of the backlog app (feature 344, `tools/backlog-app/`)
shows the run the loop works on as a summary card (phase chips, task bar,
the tool in flight, cost) and below it the raw transcript: one line per
`stream-json` event of `trace.jsonl` (`Bash git status --short`,
`tool-result …`, `Read E:\…`). That is a machine record. A person who opens
the page to see how the item is getting on cannot tell from it what the
agent is doing, what it decided, what went wrong, how far it is or how long
it will still take; the cost appears only at the end of a turn (a loop run
is often one turn of hours), tokens are never shown, screenshots the run
takes are invisible, and a question about the run needs a separate chat
window.

Maintainer's request (2026-11-07, Czech, summarised): the live view must
give a person a **human-readable, continuously updated** picture of what the
agent does, which decisions it makes and what is happening now - not program
output. The whole window may be interactive: tabs, e.g. one with the
critical information that must reach the reader; screenshots and a whole
photo gallery (swipe) of the work where it makes sense; clearly formatted
progress with emphasis, bold, coloured text, icons and labels (a label is
text in another font on a background of the label's colour, rounded
corners) that mark the important parts; detailed real-time metrics (input
and output tokens, the API price computed live in USD); a real-time chat
with the AI to ask about the state of the running item; a progress bar with
the current state, elapsed time and the expected time to finish; diagrams
explaining the architecture of the current solution; and further proposals
that give the person a detailed, human-readable view of the running process.

## Evidence

At `a9a10c44`:

- `tools/backlog-app/packages/web/src/features/live/live-page.tsx` -
  `LivePage` renders `RunSummary` and `TraceView` only.
- `tools/backlog-app/packages/web/src/features/runs/trace-view.tsx` -
  `TraceView`: a virtualised list of `TraceEvent` rows (time, tool name,
  one-line summary), a filter box and a subagent switch.
- `tools/backlog-app/packages/shared/src/runs/run-state.ts` - `RunState`
  takes the cost only from `result` lines (`costUsd`, the `$x.xx` of the
  summary); `liveRun()` in `packages/server/src/runs/service.ts` reports
  every token count as 0.
- Measured on the trace of the run of feature 414
  (`.agent-traces/20261107-104104-claude-backlog-app-triage-position-on-move-from-inbox/`):
  1100 `assistant` lines (588 messages, 581 lines of subagents), 12
  `result` lines in a run of 3 hours; each assistant line carries
  `message.usage` (input, cache read, cache write 5 m / 1 h exact when
  counted once per message id; output tokens only as streamed at the
  start), `rate_limit_event` lines carry the 5-hour and 7-day utilisation,
  Bash calls carry a human `description`, the run read 13 PNG screenshots
  (probe captures under `specs/NNN-*/probe/` and `%TEMP%`).
- The token prices of `claude-opus-5-5` ($4 / $20 / cache read $0.20 /
  cache write 5 m $5, 1 h $8 per million) reproduce the trace's reported
  `costUSD` 33.90 from its `modelUsage` to the cent.

## Expected

The *Live run* page is a dashboard a person reads without knowing the
trace format:

- a header with the item, its feature and branch, a **progress bar** with
  the percentage, the elapsed time, the expected remaining time and the
  expected end, and the phase steps of the implementation flow in words;
- a **"now" panel**: what the agent is doing at this moment in a sentence,
  since when, and its latest message;
- **live metrics**: input, output and cache tokens, the price in USD
  computed live from the tokens and the model's prices (corrected by every
  reported total), the price per hour, the context in use, tool calls,
  errors, subagents, files changed, commits, the usage-limit utilisation;
- tabs:
  - **Story** - the run told in human sentences, grouped by phase, with
    icons, coloured labels (decision, build, test, probe, review, commit,
    backlog, error, warning, …), bold and colour for outcomes (build
    succeeded / failed, tests passed / failed), the agent's own messages as
    Markdown, routine reading collapsed, subagent work folded under its
    agent;
  - **Critical** - what the reader must know: errors that stopped a step,
    failed builds and tests, a stop or block, usage limits, review findings,
    items added to the backlog, steps owed to a person - with a count on the
    tab;
  - **Decisions** - the answers the run recorded (the *Clarifications* and
    *Assumptions* of the feature's `spec.md`) and the agent's statements of
    what it decided;
  - **Gallery** - every screenshot the run looked at or produced, as
    thumbnails, opened in a full-screen viewer with swipe, arrow keys and a
    thumbnail strip;
  - **Architecture** - diagrams of the current solution: the flow of the run
    (phases with their state), the map of the files the run changed grouped
    by component, and the diagrams of the feature's `plan.md`;
  - **Files** - files changed with how often, the commits;
  - **Documents** - the feature's `spec.md`, `plan.md`, `tasks.md`,
    `fix-log.md` as they are now;
  - **Raw trace** - the existing transcript, unchanged;
- a **chat** with Claude beside the dashboard about the running item: it
  knows the live state (a fresh snapshot of the run goes with every
  message), offers ready questions ("What is it doing now?", "What did it
  decide?", "What are the risks?", "How long will it take?") and keeps the
  read-only rules of the item conversation (feature 371).

Nothing of the backlog, the loop or the run changes through the page; the
run's files are read open-read-close; images are served only when the
run's own trace or its feature folder names them.

## Approach

Pure folds in `packages/shared/src/runs/` (unit-tested): a story fold from
the normalised trace events (with the few extra fields the events need: the
tool's description and file, the message id, model and usage, the reported
totals), a metrics fold with a price table, a progress estimate (phase
weights, task progress inside *implement*, the median duration of earlier
closed runs). The server adds the images, the documents and the estimate
basis of a run, and the live snapshot of the chat. The web page reuses the
item conversation as a panel.

## Log

- 2026-11-07 — created (source manual)
- 2026-11-07 — moved to Next position 1: maintainer asked to implement it now; maintainer 2026-11-07
- 2026-11-07 — blocked: the fifth independent review found a MUST (the fourth review with one, stop-rules 3 #3): the phase markers missed the $BL form of the backlog tool; fixed on the branch after it, not reviewed. The feature is complete there: review the review-5 fixes, then merge (feature 415, branch 415-live-run-dashboard)
