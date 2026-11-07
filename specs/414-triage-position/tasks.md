# Tasks: Backlog app triage - choose the position when moving an item out of the Inbox

**Input**: Design documents from `specs/414-triage-position/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/triage-place-chooser.md, quickstart.md

**Tests**: requested by the spec (SC-002 unit cases, SC-003 end-to-end test).

All paths below are relative to `tools/backlog-app/` unless they start with `specs/`.

## Phase 1: Setup

- [ ] T001 Confirm the app's toolchain works before the change: `npm run check` in `tools/backlog-app/` passes at the branch start; record the counts in `specs/414-triage-position/fix-log.md`

## Phase 2: Foundational (the pure rules)

- [ ] T002 Add `TRIAGE_TARGETS`, `positionBySeverity(severity, rows)` and `readTriagePosition(text, count)` to `packages/shared/src/query/triage.ts`; make `suggestPlacement` use `positionBySeverity` (same results)
- [ ] T003 Add unit checks to `packages/shared/test/triage.test.ts`: `positionBySeverity` (mixed severities, empty, all less severe, all more severe, equal to the suggestion's position), `readTriagePosition` (text, 0, negative, decimal, spaces, 1, count + 1 = not last-hint, count + 2 = `last: true`)

**Checkpoint**: `npx vitest run --project shared` passes.

## Phase 3: User Story 1 - place at a chosen position in one step (P1) 🎯 MVP

**Goal**: section choice + position field + Place on the triage page, one move with the position.

**Independent Test**: e2e - the fixture's Inbox item placed into a non-suggested section at a typed position ends there; Inbox empty; one move.

- [ ] T004 [US1] Create `packages/web/src/features/triage/place-chooser.tsx`: `PlaceChooser` with the section select (`Target section`), the position field (`Position in the target section`, Enter = place, Escape = blur), the hint, the `Place` button; disabled with the gate's reason / while pending / on a refusing hint; exposes a focus handle for key `m`
- [ ] T005 [US1] Use the chooser in `packages/web/src/features/triage/triage-page.tsx`: keyed by the current slug, rows of each target from the board, `onPlace` = the existing `place(section, position)`; add the `m` shortcut ("Choose the place") and its hint text; the existing actions unchanged
- [ ] T006 [US1] Add the e2e test *Q8/triage: the chooser places at a typed position* to `e2e/us3-order.spec.ts` (fixture of that file: *Next* = disk-map 8, ftp 3, alpha 3, beta 3, gamma 3; the Inbox item has severity 2): type 2 into the field for *Next* and press Enter -> the tool lists *Next* as disk-map, the item, ftp, alpha, beta, gamma; the Inbox is empty; the item's log got exactly one move line

**Checkpoint**: the new and the old *Q8/triage* tests pass.

## Phase 4: User Story 2 - a sensible default (P2)

**Goal**: the field shows the severity default of the chosen section and follows a section change.

**Independent Test**: unit checks of T003; e2e - switching the section refills the field with that section's default.

- [ ] T007 [US2] In `place-chooser.tsx` the field follows the default until edited, and a section change resets it to the new default (data-model *Edited flag*)
- [ ] T008 [US2] Extend the e2e test of T006: before typing, the field shows `6` for *Next* (below the five items of severity >= 2); switching to *Person steps* shows `2` (below its one item of severity 5); switching back shows `6`. Add a second e2e test for the keyboard (FR-008): `m` focuses the field, typing `0` shows the refusing hint and does not change the item's severity, Escape leaves the field and nothing was moved

## Phase 5: Polish

- [ ] T009 Run `npm run check` (typecheck, lint with doc comments, Prettier, unit tests) and fix every finding
- [ ] T010 Run `npm run build` and `npx playwright test e2e/us3-order.spec.ts e2e/a11y.spec.ts`; record the results in `specs/414-triage-position/fix-log.md`
- [ ] T011 Negative control: with the chooser's position not sent, the new e2e test fails; record it in `specs/414-triage-position/fix-log.md`, then restore
- [ ] T012 Document the chooser and key `m` where the app documents the triage keys (`README.md` of the app and the file comment of `triage-page.tsx`)
- [ ] T013 `python tools/check_encoding.py --strict` from the repository root -> `TOTAL: 0 finding(s)`

## Dependencies & Execution Order

- T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008 -> T009 - T013.
- US2 builds on the chooser of US1 (same component); [P] only for T012 against T010/T011.

## Implementation Strategy

MVP = Phases 1-3 (the chooser places at a typed position). Phase 4 makes the default follow the
section; Phase 5 closes the checks.
