# Tasks: Live run view - a human-readable dashboard

**Input**: `specs/415-live-run-dashboard/` (plan.md, spec.md, research.md, data-model.md, contracts/)
**Tests**: requested by the spec (SC-001 - SC-007): unit tests for every pure rule, gate tests for
the new routes, one end-to-end test.

Paths are relative to `tools/backlog-app/packages/` unless they start with `tools/` or `specs/`.

## Phase 1: Setup

- [X] T001 Record the plan's start in `specs/415-live-run-dashboard/fix-log.md` (work log) and keep it current

## Phase 2: Foundational (blocking)

- [X] T002 Add the optional `info` object (data-model) to `TraceEventSchema` in `shared/src/schemas/runs.ts`, plus the schemas `RunInsightSchema`, `StoryEntry` types and `RunMetricsSnapshot` types
- [X] T003 Fill `info` in `normalizeTraceLine` (`shared/src/runs/trace-event.ts`): description, filePath, subagentType, messageId, model, usage, outputChars (first event of an assistant line), costUsd + totals of a result, limits of a rate-limit event, taskStatus and toolUseId of task events
- [X] T004 [P] `shared/src/runs/time-index.ts`: `TimeIndex` (anchors, add with thinning, `timeAt`, serialise)
- [X] T005 [P] Tests `shared/test/trace-event-info.test.ts` and `shared/test/time-index.test.ts`
- [X] T006 Server: time anchors of the live run in `server/src/runs/service.ts` (start anchor, follow anchors every 2 s, saved to `cache/times/<id>.json` every 30 s and at the end, loaded at a restart), first-follow interpolation of `at`, stamped `at` in `events()` for live and ended runs (saved anchors, else meta attempts)
- [X] T007 Export the new modules from `shared/src/index.ts`

## Phase 3: User Story 1 - the story in words (P1) 🎯 MVP

**Goal**: the run told in sentences with labels, icons, outcomes; groups; subagents folded.
**Independent test**: `shared/test/run-story.test.ts` over a synthetic trace; the 414 trace fold.

- [X] T008 [US1] `shared/src/runs/run-story.ts`: `RunStory` fold per `contracts/story-rules.md` (phases via embedded `RunState`, tool rules, groups, agents with children and status, messages with decision detection, critical reasons, images and changed files collected, immutable entry updates, caps)
- [X] T009 [P] [US1] Tests `shared/test/run-story.test.ts`: every row of the rules table, groups, subagents, attempts, limits, unreadable lines, caps
- [X] T010 [P] [US1] `shared/test/fold-real-trace.ts`: a script folding a real trace (story + metrics), printing counts, untitled commands, price vs reported, time (quickstart Q2)
- [X] T011 [US1] `web/src/features/live/labels.tsx`: label pill (font, colour per label, rounded), icon per label/outcome
- [X] T012 [US1] `web/src/features/live/use-run-insight.ts`: incremental fold hook over the trace stream's events (rebuild on reset or trimmed list), insight query (only while asked, 10 s)
- [X] T013 [US1] `web/src/features/live/story-view.tsx`: phase sections with durations, entries (icon, time, label, bold title, outcome colour, expandable detail with Markdown, group children, agent children + status), "Show routine steps", follow the end while live
- [X] T014 [US1] `web/src/features/live/now-panel.tsx`: the current activity sentence, since when, latest message
- [X] T015 [US1] `web/src/features/live/run-dashboard.tsx`: layout (header, now, metrics, tabs: Story, Critical, Decisions, Gallery, Architecture, Files, Documents, Raw trace) and `web/src/features/live/live-page.tsx` using it; `web/src/features/runs/run-page.tsx` using it for an ended run

## Phase 4: User Story 2 - progress, time, cost (P1)

**Goal**: progress bar with ETA; live metrics with price.
**Independent test**: `run-metrics.test.ts`, `run-progress.test.ts`, `pricing.test.ts`.

- [X] T016 [P] [US2] `shared/src/runs/pricing.ts`: price table (research R3), `priceOf(model, usage)`
- [X] T017 [US2] `shared/src/runs/run-metrics.ts`: `RunMetrics` fold (per attempt reported totals + estimate since, dedupe by message id, calibration, context, counts, limits)
- [X] T018 [P] [US2] `shared/src/runs/run-progress.ts`: `estimateProgress()` (research R5)
- [X] T019 [P] [US2] Tests `shared/test/pricing.test.ts`, `shared/test/run-metrics.test.ts`, `shared/test/run-progress.test.ts`
- [X] T020 [US2] Server estimate basis (median of closed item runs) in `server/src/runs/insight.ts` (`estimateBasis`)
- [X] T021 [US2] `web/src/features/live/progress-header.tsx` (item, feature, branch, bar, percentage, elapsed, remaining, expected end, basis, phase steps in words, a ticking clock) and `web/src/features/live/metrics-strip.tsx` (tokens, price with basis, $/h, context, counts, limits)

## Phase 5: User Story 3 - critical and decisions (P2)

- [X] T022 [US3] `server/src/runs/insight.ts`: feature folder from the branch, decisions and assumptions parsed from `spec.md`, document list, diagrams of `plan.md`; route `GET /api/runs/:id/insight` and `GET /api/runs/:id/documents/:name` in `server/src/api/runs.ts`
- [X] T023 [P] [US3] Tests `server/test/insight.test.ts` (decisions parse, documents, refused names, missing folder)
- [X] T024 [US3] Critical and Decisions tabs in `web/src/features/live/story-view.tsx` (critical list newest first with reasons and a count on the tab; decisions from the spec and from the story)

## Phase 6: User Story 4 - chat about the running item (P2)

- [X] T025 [US4] `server/src/chat/live-snapshot.ts`: the snapshot text (`contracts/chat-snapshot.md`) from the live run's story, metrics and progress; `RunsService` keeps a `RunStory` and `RunMetrics` of the live run
- [X] T026 [US4] `server/src/chat/service.ts`: prefix the snapshot to every message of a live item; `server/src/ai/prompts/chat.md`: the snapshot rule
- [X] T027 [P] [US4] Tests `server/test/live-snapshot.test.ts` (size cap, content) and a chat test that the message to claude carries the block while the item runs
- [X] T028 [US4] `web/src/features/chat/chat-panel.tsx`: the conversation as a component (transcript, streaming, composer, stop, reset, ready questions); `web/src/features/chat/chat-page.tsx` uses it; the dashboard shows it as a right column (≥ 1280 px, hideable, remembered) or an overlay

## Phase 7: User Story 5 - gallery (P3)

- [X] T029 [US5] Images in `server/src/runs/insight.ts` (trace + feature folder, allowed places, sizes) and route `GET /api/runs/:id/images/:n` in `server/src/api/runs.ts`; CSP `img-src blob:` in `server/src/gate/headers.ts`
- [X] T030 [P] [US5] Tests in `server/test/insight.test.ts` (listed image served, other index refused, outside path refused, vanished file) and the new routes in `server/test/gate.test.ts`
- [X] T031 [US5] `web/src/features/live/gallery.tsx`: thumbnails (blob URLs with the token, revoked), full-screen viewer (swipe, arrows, Escape, strip, name, source)

## Phase 8: User Story 6 - architecture, files, documents (P3)

- [X] T032 [US6] `web/src/features/live/architecture-view.tsx`: flow diagram of the phases (inline SVG, states), file map by component (SVG), diagrams of `plan.md`
- [X] T033 [US6] `web/src/features/live/documents-view.tsx`: Files (changed files with counts, commits) and Documents (list + rendered Markdown)

## Phase 9: Polish & cross-cutting

- [X] T034 `tools/backlog/fixtures/fake_claude.py`: step `replay` (plays a trace fixture with a pace, holding the item, then `then`); fixture trace `tools/backlog-app/e2e/fixtures/live-run-trace.jsonl` + a screenshot PNG written into the fixture repository's feature folder
- [X] T035 `tools/backlog-app/e2e/us7-live-dashboard.spec.ts` (quickstart Q3; a line the replay writes late must appear in the story within 3 s of being written - SC-003) and the axe check of the dashboard in both themes
- [X] T036 Run `npm run check` and the e2e tests; fold the real 414 trace (quickstart Q2); record numbers in `fix-log.md`
- [X] T037 `tools/backlog-app/README.md`: the live dashboard paragraph; `specs/344-backlog-web-app` is not changed
- [ ] T038 Independent review (SKILL step 7), fixes, records (closing report, FEATURE-HISTORY, CHANGELOG)

## Dependencies

Phase 2 before all stories. US1 (T008-T015) is the MVP and hosts the dashboard; US2 needs T015's
layout; US3/US5 need the insight route (T022 before T029); US4 needs T025 from the live fold. Polish
last.

## Parallel examples

- T004/T005 alongside T003; T009/T010 alongside T011-T014; T016/T018/T019 together; T023 and T030
  while the web parts are written.

## Implementation strategy

MVP = Phase 2 + US1 (story on the dashboard). Then US2 (progress, metrics), US3, US4, US5, US6,
then the end-to-end test and the review. One feature, committed in steps.
