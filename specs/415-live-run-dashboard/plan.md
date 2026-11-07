# Implementation Plan: Live run view - a human-readable dashboard

**Branch**: `415-live-run-dashboard` | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/415-live-run-dashboard/spec.md`

## Summary

The *Live run* page of the backlog app becomes a dashboard: a progress header (percentage, elapsed,
remaining, expected end, phase steps), a "now" panel, a live metrics strip (tokens, live price,
context, counts, usage limits), tabs (Story, Critical, Decisions, Gallery, Architecture, Files,
Documents, Raw trace) and the item's chat as a side panel that sends a fresh live snapshot with
every message. The work is three pure folds in `packages/shared/src/runs/` over the normalised trace
events (story, metrics with a price table, progress estimate) plus a time index that gives every
event a time; the server adds the run's *insight* (documents, decisions from `spec.md`, the gallery
list and its images, the estimate basis) and the chat snapshot; the web client folds the stream it
already receives and renders the dashboard, also for ended runs.

## Technical Context

**Language/Version**: TypeScript 6 (strict), Node.js 24.15+ (type stripping, no build of the server)
**Primary Dependencies**: Hono on node:http, zod 4, React 19, TanStack Query/Router, react-virtuoso,
radix-ui, lucide-react, Tailwind CSS 4, react-markdown - all already in `package-lock.json`; no new
dependency (research R9)
**Storage**: none new; the app's state folder gets `cache/times/<run>.json` (time anchors of a run,
research R4)
**Testing**: vitest (unit: shared folds, server insight/routes/snapshot), Playwright + axe (e2e with
the real loop and the fake claude, which gets a `replay` step)
**Target Platform**: Windows 11, Edge/Chrome, localhost 127.0.0.1
**Project Type**: web application (tools/backlog-app: shared / server / web workspaces)
**Performance Goals**: fold the 6 MB / 3 000-event trace of feature 414 in < 2 s in the browser
(SC-004); a new line in the story within 3 s (SC-003)
**Constraints**: read-only (FR-014), open-read-close file reads, images only from the run's list
(FR-008), CSP of the app (`img-src` gets `blob:` for images fetched with the bearer token), WCAG AA
**Scale/Scope**: runs of up to 50 000 events; ~15 new source files, 6 changed

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | No new dependency; `package-lock.json` unchanged; the product build (`build.cmd`) is not touched | PASS |
| II. Backward compatibility | The trace format (342), the loop, the backlog formats and the item conversation (371) are unchanged; `TraceEvent` gets one optional field; old runs replay | PASS |
| III. Incremental modernization | A view of an existing tool; the old transcript stays as a tab | PASS |
| IV. Windows commitment | Paths of traces and screenshots are Windows paths; checked with the repository and `%TEMP%` real paths | PASS |
| V. Plugin architecture | Not touched (no product code) | PASS (n/a) |
| VI. UI consistency | The app's tokens, primitives and both themes; axe check in both themes | PASS |
| `CLAUDE.md` standing rules | No UI strings of the product, no `.slt` refresh; backlog app rules of 344/371: every change through the tools - this feature changes nothing; new routes added to the gate tests; SPDX headers and doc comments | PASS |

Post-design re-check (after Phase 1): unchanged - PASS. The one security-relevant change is the
image route; its rules are in [contracts/http-api.md](contracts/http-api.md) and tested.

## Project Structure

### Documentation (this feature)

```text
specs/415-live-run-dashboard/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
├── contracts/
│   ├── http-api.md        # insight, image, document routes; CSP change
│   ├── story-rules.md     # how trace events become story / critical / decision entries
│   └── chat-snapshot.md   # the live snapshot given to the chat
└── checklists/requirements.md
```

### Source Code

```text
tools/backlog-app/packages/
├── shared/src/
│   ├── schemas/runs.ts            # + TraceEvent.info (optional), insight / story / metrics schemas
│   └── runs/
│       ├── trace-event.ts         # fills info: description, file, message id, model, usage,
│       │                          #   output characters, reported totals, limits
│       ├── pricing.ts             # NEW price table, priceOf()
│       ├── run-metrics.ts         # NEW RunMetrics fold
│       ├── run-story.ts           # NEW RunStory fold (entries, critical, decisions, images, files)
│       ├── run-progress.ts        # NEW estimateProgress()
│       └── time-index.ts          # NEW TimeIndex (anchors -> time of an offset)
├── shared/test/                   # NEW tests of the five modules (+ a trace fixture)
├── server/src/
│   ├── runs/service.ts            # live: time anchors, story + metrics fold, stamped events
│   ├── runs/insight.ts            # NEW documents, decisions, images, estimate basis
│   ├── api/runs.ts                # + /runs/:id/insight, /images/:n, /documents/:name
│   ├── chat/live-snapshot.ts      # NEW the snapshot text
│   ├── chat/service.ts            # snapshot prefixed while the item runs
│   ├── ai/prompts/chat.md         # one rule about the snapshot
│   └── gate/headers.ts            # img-src blob:
├── server/test/                   # NEW insight / snapshot tests; gate test for the new routes
└── web/src/
    ├── features/live/
    │   ├── live-page.tsx          # renders RunDashboard
    │   ├── run-dashboard.tsx      # NEW layout, tabs, chat column
    │   ├── use-run-insight.ts     # NEW incremental fold hook + insight query
    │   ├── progress-header.tsx    # NEW
    │   ├── now-panel.tsx          # NEW
    │   ├── metrics-strip.tsx      # NEW
    │   ├── story-view.tsx         # NEW (also Critical and Decisions lists)
    │   ├── gallery.tsx            # NEW grid + full-screen viewer with swipe
    │   ├── architecture-view.tsx  # NEW flow + file map (inline SVG) + plan diagrams
    │   ├── documents-view.tsx     # NEW files, commits, documents
    │   └── labels.tsx             # NEW label pill, icons per kind
    ├── features/chat/chat-panel.tsx   # NEW: the conversation as a component (ChatPage uses it)
    └── features/runs/run-page.tsx     # renders RunDashboard for an ended run
tools/backlog/fixtures/fake_claude.py  # + step "replay" (plays a recorded trace)
tools/backlog-app/e2e/us7-live-dashboard.spec.ts  # NEW
```

**Structure Decision**: the three existing workspaces; pure rules in `shared` (unit-tested, used
by the server for the chat snapshot and by the web client for the view), file access only in the
server, rendering only in the web client.

## Design

### Data flow

```text
trace.jsonl ──tailer──▶ server RunsService ──normalize──▶ TraceEvent(+info, at from TimeIndex)
                               │  fold: RunState, RunStory, RunMetrics (live run)
                               ├── GET /api/runs/:id/stream (SSE, existing) ─────────┐
                               ├── GET /api/runs/:id/insight (docs, decisions, images, estimate)
                               ├── GET /api/runs/:id/images/:n (bytes, only listed files)
                               └── chat send: + live snapshot (RunStory/RunMetrics digest)
browser:  useTraceStream ──▶ useRunInsight (incremental RunStory + RunMetrics fold)
          ──▶ RunDashboard: header (estimateProgress) · now · metrics · tabs · ChatPanel
```

### Key decisions (details in research.md)

- R1 rules, not a model, write the story; R2 one optional `info` object on `TraceEvent`; R3 tokens
  counted once per message id, output estimated from characters and calibrated by each reported
  total; R4 time index from anchors; R5 progress = phase weights + tasks + history median; R6
  images through the bearer token as blobs, served only from the run's list; R7 documents and
  decisions read on request, at most every 10 s; R8 the chat is the item conversation plus a
  snapshot; R9 no new dependency (own viewer, own SVG); R10 the fold runs in the browser,
  incrementally.

## Complexity Tracking

No constitution violation to justify.
