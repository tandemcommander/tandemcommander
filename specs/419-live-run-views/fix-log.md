# Fix log - 419-live-run-views

Backlog item `backlog-app-live-run-switchable-views`: the backlog app's *Live run* page is overcrowded, and its
scrollbars overlap. The maintainer's request (2026-11-08): the page never scrolls, every part becomes a
switchable view (the overview and the chat too), and the chat gets the full width.

## Measurement before (cbf0cf1f)

How it was run: a new Playwright spec, `tools/backlog-app/e2e/us8-live-layout.spec.ts`.
- The real loop is started from the app on a fixture repository. The fake claude replays the recorded 415 trace
  (`e2e/fixtures/live-run-trace.jsonl`, pace 0.2) and holds the item.
- After the trace's last line, every tab of *Views of the run* is clicked at 1920x1200, 1280x800, 1024x700 and
  820x640.
- In the page, every visible element whose `overflow-y` is `auto` / `scroll` and whose `scrollHeight` exceeds
  `clientHeight` is counted, together with how far the document and `main` scroll. The sidebar `nav` is left
  out.
- A tab whose click does not land within 3 s is recorded as covered.
- Last, a ready chat question is sent with `main` scrolled to the top, and its `scrollTop` is read after the
  answer.

```
npm run build; $env:BACKLOG_APP_E2E_MEASURE=...\layout_before.json; npx playwright test e2e/us8-live-layout.spec.ts
```

Result: `probe/layout_before.json`. The test fails, as it must.

| size | main scrolls by (px) | second scroll area | covered tabs |
|---|---|---|---|
| 1920x1200 | Story 319, Architecture 393, Raw trace 223, others 57 | Story list (512), transcript (782) | - |
| 1280x800 | 238-982 | Story list (799), transcript (1042) | - |
| 1024x700 | 347-716 on the reachable views | Story list (779) | Architecture, Files, Documents, Raw trace (the chat overlay) |
| 820x640 | 711-930 on the reachable views | Story list (820), transcript (1146) | Gallery, Architecture, Files, Documents |

- The document itself never scrolled: `html` / `body` / `#root` are `height: 100%` and `main` scrolls.
- At 1920x1200 a chat answer did not move `main`: the chat column is sticky there, so its `scrollIntoView`
  scrolled nothing else. The site (`chat-panel.tsx`) is a latent defect (FR-007) and is fixed anyway.
- First attempt of the measurement: the click on a tab covered by the chat overlay waited for the test's
  whole timeout. It now records "covered" after 3 s.

## Analyze

- First run:
  - I1, HIGH: research R8 and the UI contract named the Chat panel differently. Fixed: the panel carries
    *Chat about the run*.
  - I2, MEDIUM: two signatures of `chatSignature`. Fixed: one.
  - C1 / C2, MEDIUM: the surviving draft and the chat mark had no end-to-end test. T015 is extended.
- Second run: 0 CRITICAL, 0 HIGH.

## Implementation

All under `tools/backlog-app/`.

- `packages/web/src/features/live/run-views.ts` (new): the pure rules.
  - `RUN_VIEWS`, `availableViews` (Chat only for a live item run), `viewFromAddress` (an empty, unknown or
    unavailable value gives `overview`).
  - `chatSignature` (turns, the last state, answered yes / no), `chatMark`.
  - Unit test `packages/web/test/run-views.test.ts`: 8 tests, the first file of the `web` Vitest project.
  - Negative control: with the chat offered to every run and a mark without the "first report" and "shown"
    guards, 4 of the 8 fail. Restored, 8/8 pass.
- `app/router.tsx`: `/live` and `/runs/$id` take an optional `view` search parameter. Links without it stay
  valid.
- `features/live/run-dashboard.tsx`: one column.
  - The title row holds the heading and `RunSummaryLine` (*Run in short*).
  - The tab row reads Overview … Raw trace, then Chat for a live item run.
  - Every view is `min-h-0 flex-1`. Story, Raw trace and Chat hand their height down to their list or log.
    The other views scroll as a whole.
  - Chat is `forceMount` and hidden while inactive (its draft and a streaming answer survive), inside
    `section` *Chat about the run*. The tab shows a dot with "new answer" by `chatMark`.
  - Removed: the `<aside>`, its open / close buttons, `initialChat` and the localStorage key
    `backlog-app.live.chat`.
- `features/live/progress-header.tsx`: `RunSummaryLine` (title link, step, a thin bar `aria-hidden`, percentage,
  elapsed, remaining / finished / stopped).
- `features/live/live-page.tsx`, `features/runs/run-page.tsx`: the root is `flex min-h-0 flex-1 flex-col
  overflow-hidden`, and the view goes to the address with `replace: true`. A run without a trace keeps its
  normal page.
- `features/live/story-view.tsx`, `features/runs/trace-view.tsx`: the list box is `min-h-0 flex-1` instead of
  `h-[68vh]` / `h-[60vh]`. An opened story line no longer has its own `max-h-80` scroll box.
- `features/live/now-panel.tsx`: the latest message no longer has its own `max-h-48` scroll box.
- `features/chat/chat-panel.tsx`:
  - The log scrolls itself (`scrollTop`) and follows the end unless the reader scrolled up. It does so again
    when shown or resized (ResizeObserver).
  - No `scrollIntoView`; the tool-use list has no scroll box of its own.
  - New props `placeholder`, `shown`, `onSignature`; `compact` went with the column.
- `e2e/us7-live-dashboard.spec.ts`:
  - It follows the views: Overview first, Story before the story checks, the chat through its tab and region.
  - axe runs on Overview, Story and Chat in both themes.
  - The ended run has no Chat tab.
- `e2e/us8-live-layout.spec.ts`: the measurement above, extended by:
  - the 10 views of the row;
  - nested scroll areas;
  - the live story following its real end, staying where the reader scrolled it, and "Latest";
  - the chat at full width (> 90 % of `main`);
  - *Run in short* on Story and Chat;
  - the draft surviving a view switch;
  - the mark of a new answer (the fake chat claude in `slow` mode);
  - the view kept across a reload, and an unknown view giving Overview.

### The live story stopped following its end - three attempts

The first run of `us7` after the change failed SC-003: the story's last line did not appear within 3 s, and
*Latest* showed.

1. The container (`absolute inset-0` vs a flowing child at `height: 100%`): the same failure, so not the
   cause.
2. A diagnostic spec (deleted afterwards) sampled the scroller every 0.7-2 s during the replay. The list kept
   to its end only while it fitted. The first line past the bottom left it 116 px short: Virtuoso's
   `followOutput` scrolls to its *estimate* of the new line, and the "AGENT SAYS" boxes are taller. That is
   past the 80 px `atBottomThreshold`, so following stopped for good.
   - Fix: "follow" is decided by the reader, `stuck` until the reader scrolls away. After every
     `totalListHeightChanged` a stuck list scrolls to its end.
   - The first form of "the reader scrolled" (scrollTop went down) was fooled by Virtuoso moving its own
     position while it measured: 123 -> 103, unstuck.
   - Now only a scroll within 1 s of the reader's own input (wheel, touchmove, keydown, pointerdown on the
     scroller) unsticks.
3. Even so, the list stopped exactly 60 px short of its end. Each phase heading's root had `mt-3`, a margin
   that collapses out of Virtuoso's row wrapper and is missing from the measured height: 5 headings x 12 px =
   60 px. The gap is now padding of a wrapper.
   - After the fix the diagnostic ends with `top 537 = 1500 - 963` (gap 0).
   - `us8` now requires the real end (<= 2 px) while lines arrive and after the last one. The 80 px
     tolerance had hidden the 60 px.

Whether 415 already lost the follow at times is not established. Its fixed 68vh list passed `us7`, and the 60 px
of margins existed there too.

## Findings fixed on the way (severity <= 5, stop-rules rule 11)

| Finding | Severity | Before | After / test |
|---|---|---|---|
| The live story's measured height missed the margins of its phase headings (12 px each), so a following story never reached its real end | 3 | the list stood 60 px short of its end after the whole replay | padding instead of a margin; `us8` "the story at its real end" <= 2 px (fails on cbf0cf1f) |
| The story stopped following when a new line was taller than estimated | 3 | following lost at the first overflow (116 px short, *Latest* shown) | the reader-input rule; `us7` SC-003 and `us8` follow checks pass |
| The DECISION pill inside a decision box of the story had 4.50:1 contrast (light theme; axe `color-contrast` on Story once the list shows its end) | 2 | `bg-warn/14` on `bg-warn/8`: 4.50 (computed, `contrast.py`) | pill `bg-warn/10`, box `bg-warn/5`: 4.96 inside the box, 5.30 elsewhere; `us7` axe passes on Story in both themes |
| The chat's `scrollIntoView` scrolled every scrollable ancestor (the page included) | 2 | latent: at 1920 the sticky column hid it | the log sets its own `scrollTop`; `us8` "after a chat answer" main 0 px |

## Verification (after)

- `npm run check` (typecheck, lint with doc comments, prettier, Vitest): clean; Vitest 519 passed, 2 skipped
  (8 new in `packages/web/test/run-views.test.ts`).
- `us8-live-layout` on the new client: pass. `probe/layout_after.json` covers 40 view/size cases plus "after a chat
  answer":
  - the document and `main` scroll 0 px in every case;
  - nothing is covered;
  - at most one scroll area per view, none nested: Story and Raw trace their list; Overview, Decisions,
    Architecture and Documents their box when the content is taller (e.g. Overview 455 px at 820x640); the
    other views and Chat none at this content.
  - The follow branch ran: "the reader's scroll up was checked while lines arrived".
  - Screenshots: `probe/shots/` (every view at 1920x1200 and 820x640, the chat answered, the mark on the Chat
    tab).
- Negative control (T018): the same spec against the web client built from cbf0cf1f fails with 47 soft
  failures (`probe/result_negative_cbf0cf1f.txt`, `probe/layout_negative_cbf0cf1f.json`):
  - all 32 reachable or covered view/size rows (the page scrolls, or the tab is covered);
  - the 10 views of the row, a Chat view, the run in one line, the chat width (0 of 1704 px), the mark;
  - the view in the address, a reload, an unknown view;
  - the story's real end, while growing and at the end.
  - It ran in a worktree in the scratchpad with linked `node_modules`, which was removed afterwards.
- Full end-to-end suite `npm run test:e2e`: 40 passed (7.6 min), including `us4-chat`, `us7-live-dashboard` (axe on
  Overview, Story and Chat in both themes) and `us8-live-layout`.
- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`. `.\build.cmd`: `BUILD SUCCEEDED` (the product is
  unchanged). No product UI strings changed: no `.slt` refresh, no `saltests` run.

## Review

### Review 1 (independent agent, refute-first): MUST 0, SHOULD 1, NOTE 5

The reviewer re-ran `us8` on the branch (pass, 41 cases at 0 px), checked with a spec of its own that nothing is
cut off at 1920x1200, 820x640 and 1280x560 with the gate banner, and checked the chat position across a view
switch, the history (Back goes to `/runs`), the arrow keys of the tab row and the links without `?view=`. No way
to lose data was found.

| # | Finding | What was done |
|---|---|---|
| S1 | `us8` did not prove FR-004 or FR-007. The reviewer put the story list back to `h-[68vh]` and the chat back to `scrollIntoView`, and `us8` still passed. `measure` only counted `overflow-y: auto` elements, and nothing measured content cut off by the page root or the root's position | `us8` now also measures, per view: <br>- `rootOver` (the page root's own overflow, must be 0); <br>- `panelGap` (the view reaches the page's bottom, <= 2 px); <br>- `fillGap` for Story, Raw trace and Chat: the story log, the transcript's scroll area and the chat's composer must reach the view's bottom (<= 2 px; measured 0-1). <br>After the chat answer, the `scrollTop` of every ancestor of the conversation log is summed, and an init script counts `scrollIntoView` calls inside the chat, which must be 0 (with nothing left that can scroll, a page measure alone cannot see that request). <br>The page root became `overflow-y-auto` instead of `overflow-hidden`: below the supported sizes it scrolls rather than cuts the views off (NOTE 5), and at the supported sizes any overflow now shows in the scroll-area count and in `rootOver`. <br>The first form of `fillGap` (the lowest of all elements outside a scroll area) still let the 68vh story pass, because the story's wrapper stretches anyway; it now measures the part that must fill. <br>Mutation run (`probe/result_mutation_review1.txt`): story list `h-[68vh]`, transcript `h-[60vh]` and the chat back to `scrollIntoView`: `us8` fails on all three (the chat spy; Story at 1920x1200; Raw trace at 1920x1200 and 1280x800). Sources restored from git, client rebuilt |
| N2 | Opening a line of the following live story made the list jump (the opened line moved up 110 px) | Found with a temporary `[419dbg]` log (removed). <br>1. `toggle` set `stuck = false`, but a scroll right after (the list adjusting) was taken for the reader's move, because the click's `pointerdown` counted as scrolling input. A `pointerdown` now counts only on the scroll area itself (its scroll bar), and sticking again needs the reader's own move down to the end. <br>2. Still 110 px: react-virtuoso treats any *function* `followOutput` as "follow" and, after every new prop (every render: the arrow function was new), pulls a growing list to its end for 100 ms ("scrolling to bottom due to increased size" in its source). `followOutput` is now the value `follow && stuck ? "auto" : false`. <br>`us8` row "an opened line stays where it was" (<= 2 px) and "Latest after opening a line" |
| N3 | The story's search, filters and opened lines reset on every view switch | Kept by the dashboard (`StoryFilters`, `STORY_FILTERS`, a controlled `StoryView`); `us8` row "the story's search after a view switch". The scroll position of an ended run's story is not kept (a live story returns to its end): accepted |
| N4 | A new chat turn sent while scrolled up came into view only at the next text change (`following = true` in a `useEffect` after the scrolling `useLayoutEffect`) | Merged into the same layout effect (a ref of the turns seen) |
| N5 | Below the supported sizes (820x480) the chat composer was cut off by the root's `overflow-hidden` | The root is `overflow-y-auto` (see S1) |
| N6 | A single wheel notch up within 80 px of the end could be overtaken by the catch-up | A reader's move up unsticks even within the slack, and the catch-up waits 400 ms after the reader's input |

After the fixes:
- `npm run check`: clean, Vitest 519 passed;
- `us8` and `us7`: pass;
- mutation run: fails as above.

### Review 2 (independent agent, refute-first): MUST 0, SHOULD 0, NOTE 3

The reviewer built `d5f12cdd` in a worktree of its own.
- **Its runs:** `npm run check`, `us8` (54 s), `us7` and `us4-chat` all pass.
- **Its negative control:** with the story's function `followOutput` put back, `us8` fails on "an opened line
  stays where it was".
- **Its own specs on a slow live run** (deleted afterwards). The story stays at its real end (gap 0) through:
  - the filters on and off, a search typed and cleared;
  - a switch to Overview and back;
  - "Latest";
  - a wheel move up and back down.
- **Opening a line with Enter** keeps it in place (0 px over 3.2 s).
- **The chat:**
  - its position survives a view switch and a resize;
  - a streaming answer does not pull a reader scrolled up;
  - in the conversation's own window it opens at its end and the document scrolls 0 px.
- **An ended run:** Story and Raw trace open at the top, an opened line moves 0 px (98 px on `main`), there is no
  Latest and no Chat, and `?view=chat` shows Overview.

| # | Finding | What was done |
|---|---|---|
| N1 | `/live` did not remount the dashboard per run: with no "no run" page between two items, the next item's conversation would be compared with the previous one (a false chat mark), and the story choices and a chat draft would carry over (the draft already in 415) | `key={run.id}` on `RunDashboard` (live page and run page) |
| N2 | `/runs/<ended>?view=chat` shows Overview but keeps `?view=chat` in the address | The dashboard corrects an address naming a view the run does not have (replace); `us8` row "the corrected address" (`?view=nonsense` -> `?view=overview`) |
| N3 | Leftover worktrees of earlier reviews (`rev325`-`rev341r3/neg`, `rev414r5`, `rev414r6` under `%TEMP%`) | Not from this feature; left for the maintainer (named in the closing report) |

After the fixes, `us8`, `us7` and `us4-chat` pass (2.2 min). The full suite had passed 40/40 (7.9 min) on `d5f12cdd`,
before these two small changes.
