# Tasks: Backlog app live run: one switchable view at a time, no page scrolling

**Input**: Design documents from `specs/419-live-run-views/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/run-views-ui.md, quickstart.md

**Tests**: requested by the item (*Notes*: the `us7` end-to-end test follows the layout; a new layout
measurement with a negative control) and by the project's working method (pure rules with unit checks).

Paths are relative to `tools/backlog-app/` unless they start with `specs/`.

## Phase 1: Setup

- [ ] T001 Start `specs/419-live-run-views/fix-log.md` with the measurement at cbf0cf1f (`probe/layout_before.json`, the summary table, how it was run)

## Phase 2: Foundational (blocking)

- [ ] T002 Write the pure rules in `packages/web/src/features/live/run-views.ts`: `RUN_VIEWS`, `availableViews(live, hasItem)`, `viewFromAddress(value, available)`, `chatSignature(turns)`, `chatMark(seen, current, shown)` (data-model.md)
- [ ] T003 [P] Unit test of T002 in `packages/web/test/run-views.test.ts` (unknown / empty / unavailable view gives overview; chat only for a live item run; signature changes on a new turn, a state change and a first answer; the mark only when not shown, not on the first report); check it fails against a deliberately wrong rule (negative control) and record it in the fix-log
- [ ] T004 Accept the optional `view` search parameter on `/live` and `/runs/$id` in `packages/web/src/app/router.tsx`

## Phase 3: User Story 1 - the page never scrolls; one scrollbar per view (P1)

**Goal**: the run pages fill `main` exactly; each view has one vertical scroll area.
**Independent test**: `e2e/us8-live-layout.spec.ts` - the document and `main` scroll 0 px, at most one scroller per view, none nested, at 4 sizes.

- [ ] T005 [US1] Make the run pages full height: root `flex min-h-0 flex-1 flex-col overflow-hidden` in `packages/web/src/features/live/live-page.tsx` and in `packages/web/src/features/runs/run-page.tsx` (a run with a trace; a run without one keeps its normal page)
- [ ] T006 [US1] Make the story list fill its view (`min-h-0 flex-1` box, Virtuoso `height: 100%`) and drop the opened line's own scroll box in `packages/web/src/features/live/story-view.tsx`
- [ ] T007 [P] [US1] Make the transcript list fill its view in `packages/web/src/features/runs/trace-view.tsx`
- [ ] T008 [P] [US1] Drop the latest message's own scroll box in `packages/web/src/features/live/now-panel.tsx`
- [ ] T009 [US1] Extend `e2e/us8-live-layout.spec.ts`: the 10 views of the new row, nested scrollers counted as a failure, the screenshots of every view at 1920x1200 and 820x640 when `BACKLOG_APP_E2E_SHOTS` is set

## Phase 4: User Story 2 - every part is a view, the chat at full width (P1)

**Goal**: Overview and Chat are views of the same row; the chat column is gone.
**Independent test**: `us7` reaches the chat through the Chat tab; `us8` sends a ready question with the page at rest.

- [ ] T010 [US2] Rebuild `packages/web/src/features/live/run-dashboard.tsx` as one column: title row slot, tab row (Overview first, Chat last when available), every `TabsContent` `min-h-0 flex-1`, the scrolling box of the non-list views, Chat `forceMount`, hidden while inactive, its panel named *Chat about the run*; remove the `<aside>`, the open / close buttons, `initialChat` and `CHAT_KEY`; the chosen view from and to the address (`replace: true`)
- [ ] T011 [US2] `packages/web/src/features/chat/chat-panel.tsx`: scroll only its own log (`scrollTop`, near-bottom rule while an answer streams, at the end when shown again), no own scroll box for the tool-use list, an optional `onSignature` callback and a `fill` layout (full width)
- [ ] T012 [US2] The mark on the Chat tab (`chatMark`, visually a dot, accessible text "new answer") in `packages/web/src/features/live/run-dashboard.tsx`
- [ ] T013 [US2] Follow the new layout in `e2e/us7-live-dashboard.spec.ts` (Overview first, the chat through the Chat tab and its panel *Chat about the run*, the ended run without a Chat tab, axe in both themes)

## Phase 5: User Story 3 - where the run is stays in sight; the view is kept (P2)

**Goal**: the compact line on every view; the view in the address.
**Independent test**: `us8` checks *Run in short* on Story and Chat; a reload on Documents opens Documents.

- [ ] T014 [US3] `RunSummaryLine` (section *Run in short*: title link, step, thin bar `aria-hidden`, percentage, elapsed, remaining / finished / stopped) in `packages/web/src/features/live/progress-header.tsx`, placed on the title row by `run-dashboard.tsx` (the pages pass their title)
- [ ] T015 [US3] Add to `e2e/us8-live-layout.spec.ts`: *Run in short* visible on Story and Chat with the item's title and a percentage; `?view=documents` survives a reload; `?view=nonsense` opens Overview; a draft typed in the chat survives a switch to Story and back (FR-008); an answer that arrives while Story is shown marks the Chat tab, and opening Chat clears the mark (FR-009)

## Phase 6: Polish & cross-cutting

- [ ] T016 Run `npm run check` (typecheck, lint, prettier, Vitest) and fix every finding
- [ ] T017 Run `npm run test:e2e` (the full suite, Edge) - all pass; record the numbers
- [ ] T018 Negative control: the new `us8` against the web client built from cbf0cf1f (a worktree under the scratchpad) fails; record which rows
- [ ] T019 [P] Update the *Live run* paragraph of `README.md` (one row of views, Overview and Chat, the page never scrolls, `?view=`)
- [ ] T020 Record after-measurements (`specs/419-live-run-views/probe/layout_after.json`, screenshots) and the results in `specs/419-live-run-views/fix-log.md`

## Dependencies & Execution Order

- T001 → T002 → T003, T004 (parallel) → US1 (T005-T009) → US2 (T010-T013; T010 before T012, T011 before T012) → US3 (T014-T015) → Polish (T016-T020).
- US2 and US3 both edit `run-dashboard.tsx`: run them one after another.

## Parallel examples

- T003 with T004 (different files).
- T007 with T008 (different files).

## Implementation Strategy

US1 alone already stops the page scrolling (MVP). US2 removes the covering chat and makes every part a view. US3
keeps the run's state in sight. All three are needed to close the item.
