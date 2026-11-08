---
title: Backlog app live run: one switchable view at a time, no page scrolling
type: improvement
status: open
severity: 3
area: tooling
source: manual
who: agent
created: 2026-11-08
updated: 2026-11-08
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Backlog app live run: one switchable view at a time, no page scrolling

## Problem

The backlog app's *Live run* page (feature 415) is good but overcrowded. The page also shows several overlapping scrollbars at once:
- the scrollbar of the whole page;
- the scrollbar of the chat column;
- the scrollbar of the story list or of the raw transcript;
- small scrollbars of the "now" message and of an opened story line.

Today the page stacks three main parts:
- the overview of the run (progress head, "what happens now", live figures) above the tabs;
- the tabbed part (Story, Critical, Decisions, Gallery, Architecture, Files, Documents, Raw trace);
- the chat with Claude about the run, as a fixed column on the right.

The maintainer (2026-11-08): "the page itself will not scroll at all and the individual parts then have their own scrollbars. Put all the parts together into switchable views - the overall overview of the run as well as the chat window, which thereby gets the full width of the page. There is too much information on the page now; switching between everything is enough for me."

## Evidence

At 87793bd8 (`tools/backlog-app/packages/web/src/`):
- `app/layout.tsx:352`: `<main className="... overflow-y-auto">` is the page's own scroll area for every page, the *Live run* page included.
- `features/live/run-dashboard.tsx`, `RunDashboard`:
  - `ProgressHeader`, `NowPanel` and `MetricsStrip` sit above the `Tabs`.
  - The chat is an `<aside>`: `min-[1280px]:sticky min-[1280px]:h-[calc(100vh-5rem)] min-[1280px]:w-[24rem]` at line 247, a fixed overlay `max-w-md` below 1280 px.
- `features/live/story-view.tsx:293`: the story list has a fixed height of `h-[68vh] min-h-72` (a virtualised `Virtuoso` list with its own scrollbar). Together with the head above it, this is taller than the window, so the page scrolls as well.
- `features/runs/trace-view.tsx:139`: the raw transcript is `h-[60vh] min-h-64` (its own scrollbar under the page's).
- `features/live/now-panel.tsx:88`: `max-h-48 overflow-y-auto`. `features/live/story-view.tsx:195`: `max-h-80 overflow-y-auto` (small scroll areas inside the views).
- `features/chat/chat-panel.tsx:197`: `bottom.current?.scrollIntoView({ block: "end" })` scrolls every scrollable ancestor, so each chat update also scrolls the page.
- The same `RunDashboard` is the page of an ended run (`features/runs/run-page.tsx`).

## Expected

- **The page never scrolls.** On the *Live run* page and the page of a run, the page fits the window below the top bar, and the frame (`main`) has nothing to scroll at any window size the app supports.
- **One row of switchable views.** All parts sit in one row of tabs:
  - **Overview**: progress head, what happens now, live figures;
  - the existing Story, Critical, Decisions, Gallery, Architecture, Files, Documents and Raw trace;
  - **Chat**, only while the item runs.
  Only the chosen view is shown below the tabs and fills the rest of the window.
- **One scrollbar per view.** Each view has at most one vertical scroll area of its own, filling the remaining height. No view stacks a fixed-height list under a scrolling page.
- **The chat uses the full width.** The conversation scrolls inside its own log and the composer stays at the bottom. A chat update never scrolls anything outside the conversation.
- **The run's state stays in sight.** A compact one-line summary (item, phase, percentage, elapsed / remaining) stays above the tabs, so a person on Story or Chat still sees where the run is.
- Nothing is lost. Everything the 415 dashboard shows stays reachable, with the same accessible names that the end-to-end tests and axe check, in both themes.

## Approach

- Make the page a column of `h-full min-h-0`: the compact summary, the tab list, then the chosen view as `flex-1 min-h-0`.
- Story, Raw trace and Chat get their height from that column, not from `vh` values. The list or log fills the view and is its only scrollbar. The other views get one `overflow-y-auto` box of their own.
- The chat keeps the tab mounted (its draft survives a tab switch). It scrolls only its own log (`scrollTop`), never with `scrollIntoView`.
- The chosen view is remembered in the address (`?view=`), so a reload or a link keeps it. Default: Overview.
- Optionally, a new Claude answer while another view is shown marks the Chat tab.

## Notes

- Related to feature 415 (`specs/415-live-run-dashboard/`) and to the chat of feature 371.
- Tests:
  - `e2e/us7-live-dashboard.spec.ts` must follow the new layout.
  - A new end-to-end check measures that neither the document nor `main` scrolls at 1920x1200, 1280x800 and a narrow window, and that each view has at most one vertical scroll area.
  - The new checks need a negative control on the build of `main`.

## Log

- 2026-11-08 — created (source manual)
- 2026-11-08 — moved to Next position 1: the maintainer asked to do it now; maintainer 2026-11-08
