# Research: 419-live-run-views

Measured at cbf0cf1f with `tools/backlog-app/e2e/us8-live-layout.spec.ts`. The real loop runs the fake claude,
which replays the recorded 415 trace. Every view is measured at 1920x1200, 1280x800, 1024x700 and 820x640:
- `main` scrolled on every reachable view, by 57-982 px;
- Story and Raw trace added their list's scrollbar inside it;
- below 1280 px the chat overlay covered 9 of 32 view/size cases.

## R1 - How the page stops scrolling

- **Decision**: the frame keeps `main` as `flex min-h-0 flex-col overflow-y-auto` (every other page scrolls
  there as before). The run pages' root is `flex min-h-0 flex-1 flex-col overflow-hidden`, so it is exactly as
  tall as `main` leaves after the banners (connection lost, closed gate), and nothing inside can make `main`
  taller.
- **Rationale**: the rule applies only to the two run pages. The banners keep their place, because `main` is
  already a flex column.
- **Alternatives**:
  - `overflow-hidden` on `main` for all pages: breaks every long page.
  - A route-dependent class on `main`: couples the frame to one page, for nothing gained.
  - Heights in `vh` (415): they ignore the top bar, the banners and the head, which is exactly what made the
    page scroll.

## R2 - Which views stay mounted

- **Decision**: Radix `Tabs` keeps unmounting inactive views (as in 415), **except Chat**: its `TabsContent`
  is `forceMount` and hidden while inactive (`data-[state=inactive]:hidden`). That way a draft, a running
  answer and its stream survive a view switch (FR-008).
- **Rationale**:
  - A virtualised list in a hidden (`display: none`) box measures zero and renders badly when shown again.
  - Unmounting the lists costs nothing: their data lives above them (`useRunView`, the trace stream).
  - Opening Story again starts it at its end while live, which is 415's behaviour (FR-014).
- **Alternatives**: `forceMount` for every view. Rejected: Virtuoso's zero-size problem, and live views would
  keep folding off-screen.

## R3 - One scroll area per view

- **Decision**:
  - Every `TabsContent` is `min-h-0 flex-1` inside the column.
  - **Story** and **Raw trace** keep their filter row on top. Their list box becomes `min-h-0 flex-1` instead
    of `h-[68vh]` / `h-[60vh]`, and Virtuoso gets `height: 100%`, so the list is the view's one scroll area.
  - **Chat** is `flex-col`: its log (`flex-1 overflow-y-auto`) is the one scroll area, and the composer sits
    below it.
  - **Overview, Critical, Decisions, Gallery, Architecture, Files, Documents** are wrapped in one
    `min-h-0 flex-1 overflow-y-auto` box.
  - The inner scroll boxes go:
    - the now panel's `max-h-48 overflow-y-auto`;
    - an opened story line's `max-h-80 overflow-y-auto` (Virtuoso measures items of any height);
    - the chat's tool-use list `max-h-40 overflow-y-auto`.
  - Horizontal scrolling (gallery strip, `pre` blocks, tables) is not counted. It is not what the
    maintainer saw.
- **Rationale**: FR-004 and FR-005, measured by `us8`.
- **Alternatives**: keeping inner caps with `overflow-hidden` and a "show more" button. Rejected: it hides
  text, and it adds controls.

## R4 - Chat scrolling

- **Decision**: `ChatPanel` keeps a ref to its log and sets `log.scrollTop = log.scrollHeight` when:
  - a turn is added;
  - the live text grows while the reader is near the bottom (within 80 px);
  - the log is shown again.
  No `scrollIntoView`.
- **Rationale**: `scrollIntoView` scrolls every scrollable ancestor, `main` included (FR-007). The near-bottom
  rule lets a reader scroll up while an answer streams.
- **Alternatives**: `scrollIntoView({ block: "nearest" })`, which still scrolls ancestors. CSS
  `overflow-anchor`, which does not start at the bottom on load.

## R5 - The chosen view in the address

- **Decision**:
  - `/live` and `/runs/$id` accept an optional search parameter `view`, so existing links without it stay
    valid.
  - A tab change navigates with `replace: true`: the address always names the view, and Back leaves the page
    instead of walking through the tabs.
  - `viewFromAddress(value, available)` (pure) returns Overview for an empty, unknown or unavailable value.
    For example, `chat` on an ended run gives Overview.
- **Rationale**: FR-011. The router already keeps `tab` for the item page the same way.
- **Alternatives**: localStorage, as the 415 chat column did. Rejected: per-browser, invisible, not linkable.

## R6 - The mark on the Chat tab

- **Decision**:
  - `ChatPanel` reports a signature of its conversation through an optional `onSignature` callback:
    `chatSignature(turns)` = the number of turns, the last turn's state and whether it has an
    answer.
  - The dashboard remembers the signature it last saw while Chat was shown. The first signature reported
    counts as seen, so an existing conversation never marks on load.
  - The tab shows a dot with the accessible text "new answer" when `chatMark(seen, current, chatShown)` is
    true, that is, when the signature differs and Chat is not shown.
- **Rationale**: FR-009, a pure rule with a unit test.
- **Alternatives**: counting unread turns, which is more state for the same information.

## R7 - The compact line

- **Decision**:
  - A `RunSummaryLine` (`section`, accessible name *Run in short*) on the title row, on every view:
    - the item's title as a link (slug when no title, "Auto-triage" for a triage run);
    - the step (`PHASE_TITLES`);
    - a thin bar (`aria-hidden`);
    - the percentage;
    - elapsed and "≈ remaining" (or "finished" / "stopped").
  - It reads the same `progressOf` estimate as the head, computed once in `RunDashboard`.
  - It wraps onto a second line in a narrow window instead of overflowing.
- **Rationale**: FR-010. The full head (*Run progress*, with the one progress bar the tests address by name)
  stays only on Overview, so the accessible names stay unique.
- **Alternatives**: a second `role="progressbar"`, which would duplicate the name the tests and screen readers
  use.

## R8 - What is removed

- **Decision**: the chat `<aside>` (*Chat about the run*), its open / close buttons, `initialChat` and the
  localStorage key `backlog-app.live.chat`.
  - The chat's accessible region becomes the Chat view: its tab panel carries the name *Chat about the run*
    (the name `us7` addresses), and the conversation log keeps *The conversation*.
  - `us7` addresses the chat through the Chat tab's panel, and the ended-run check becomes "no Chat tab".
- **Rationale**: FR-013. The overlay covered the tabs below 1280 px.
