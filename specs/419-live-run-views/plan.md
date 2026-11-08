# Implementation Plan: Backlog app live run: one switchable view at a time, no page scrolling

**Branch**: `419-live-run-views` | **Date**: 2026-11-08 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/419-live-run-views/spec.md`

## Summary

The run dashboard of the backlog app (feature 415) becomes a full-height column:
- the page title with one compact line of where the run is;
- one row of views: Overview, Story, Critical, Decisions, Gallery, Architecture, Files, Documents, Raw trace,
  and Chat (only for a live item run);
- the chosen view, which fills the rest of the window.

The frame's `main` keeps `overflow-y-auto` for every other page. These two pages fill it exactly (`h-full
min-h-0`), so it has nothing to scroll. Each view either:
- hands its height to the one list it has (the story and transcript lists, the chat log), or
- wraps its content in one `overflow-y-auto` box.

The inner scroll boxes go: the now panel's message, an opened story line, the chat's tool-use list. The chat
stops using `scrollIntoView`; it sets its own log's `scrollTop`. The chosen view lives in the address (`?view=`).
A mark on the Chat tab tells of an answer that came while another view was shown. Measured at cbf0cf1f with the
new end-to-end measurement `e2e/us8-live-layout.spec.ts`: `main` scrolled 57-982 px on every view, and 9 of 32
view/size cases were covered by the chat overlay.

## Technical Context

**Language/Version**: TypeScript 6.0 (ES modules), React 19.3, Node 24 for tests
**Primary Dependencies**: Vite 8, Tailwind CSS 4, Radix UI Tabs (via `radix-ui` 1.8), TanStack Router 1.170,
react-virtuoso 4.18 (story and transcript lists); no new dependency
**Storage**: none (the chosen view is in the address; the removed chat column state `backlog-app.live.chat` in
localStorage is simply no longer read)
**Testing**: Vitest 5 (the `web` project in jsdom: pure view rules), Playwright 1.64 in Edge (`us7` adjusted,
`us8-live-layout` new), axe in both themes; `npm run check` (typecheck, lint with doc comments, prettier, unit)
**Target Platform**: the maintainer's browser (Edge / Chrome) on Windows 11, localhost app
**Project Type**: web client of a localhost web application (`tools/backlog-app/packages/web`)
**Performance Goals**: a view switch shows the view at once (no refetch of the trace); the live story still
shows a written line within 3 s (415 SC-003)
**Constraints**: the page scrolls 0 px at 1920x1200, 1280x800, 1024x700 and 820x640; at most one vertical
scroll area per view; accessible names of 415 kept (the tests and axe read them)
**Scale/Scope**: about 8 files of `packages/web/src` changed, one small pure module and its unit test, two
end-to-end specs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | the web client is built by `npm run build` from locked dependencies; no new dependency | pass |
| II. Backward compatibility | the product (Tandem Commander) is untouched; in the app, every part of the 415 dashboard stays reachable with its names (FR-012); old links `/live` and `/runs/<id>` without `?view=` open Overview | pass |
| III. Incremental modernization | one page's layout; small, revertible commits | pass |
| IV. Windows commitment | applies to the product; the app is a development tool (feature 344) | n/a |
| V. Plugin architecture | untouched | n/a |
| VI. UI consistency | the product's dialogs are untouched; in the app the same tab component, tokens and both themes | pass |
| Workflow | English commits referencing 419, one concern | pass |

Post-design re-check: unchanged (no new storage, network or dependency; nothing outside `tools/backlog-app`).

## Project Structure

### Documentation (this feature)

```text
specs/419-live-run-views/
├── spec.md              # the specification
├── plan.md              # this file
├── research.md          # decisions R1-R8
├── data-model.md        # the view state
├── quickstart.md        # how to validate
├── contracts/
│   └── run-views-ui.md  # the views, their names and their scroll areas (what the tests read)
├── checklists/requirements.md
├── tasks.md             # /speckit-tasks
├── fix-log.md           # the running record
└── probe/               # measurements (JSON) before / after, screenshots
```

### Source Code (repository root)

```text
tools/backlog-app/
├── packages/web/src/
│   ├── app/router.tsx                    # /live and /runs/$id read ?view= (optional)
│   ├── features/live/run-views.ts        # NEW pure rules: the views, the view from the address, the chat mark
│   ├── features/live/run-dashboard.tsx   # one column: summary line, tab row, the chosen view; Overview and Chat tabs
│   ├── features/live/live-page.tsx       # full height
│   ├── features/live/now-panel.tsx       # the latest message without its own scroll area
│   ├── features/live/story-view.tsx      # list fills the view; an opened line without its own scroll area
│   ├── features/runs/trace-view.tsx      # list fills the view
│   ├── features/runs/run-page.tsx        # full height for a run with a trace
│   └── features/chat/chat-panel.tsx      # scrolls its own log only; tool-use list without own scroll; reports answers
├── packages/web/test/run-views.test.ts   # NEW unit test of the pure rules
├── e2e/us7-live-dashboard.spec.ts        # follows the new views (Overview, Chat tab)
├── e2e/us8-live-layout.spec.ts           # NEW measurement: no page scroll, one scroll area per view, chat
└── README.md                             # the Live run paragraph
```

**Structure Decision**: only the web package changes; the server, `shared` and the chat service stay as they
are. The pure rules go to `features/live/run-views.ts` (no React), tested in jsdom by the existing `web` Vitest
project, which gets its first test file.

## Complexity Tracking

No constitution violation; nothing to justify.
