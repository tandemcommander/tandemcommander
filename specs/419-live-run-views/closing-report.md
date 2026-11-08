# Closing report - 419-live-run-views

Backlog item: backlog-app-live-run-switchable-views - Backlog app live run: one switchable view at a time, no page scrolling
Outcome: closed

## What changed

The backlog app's *Live run* page and the page of a run with a trace (`tools/backlog-app/packages/web`) are one
column that fills the window:

- the title with **the run in one line** (*Run in short*: item, step, a thin bar, percentage, elapsed and remaining),
  on every view;
- **one row of views**:
  - **Overview**: the progress head, what happens now, the live figures;
  - Story, Critical, Decisions, Gallery, Architecture, Files, Documents and Raw trace, as in 415;
  - **Chat**: only while an item's run is live, at the full width of the page. It stays mounted, so a draft or a
    streaming answer survives a view switch. Its tab shows a dot ("new answer") when an answer arrives while
    another view is shown;
- the chosen view below the row. The **page itself never scrolls**: each view scrolls in **one area of its own**
  (Story and Raw trace their list, Chat its conversation log, the other views as a whole).
- The chosen view is kept in the address (`/live?view=story`; replaced, not stacked in the history). An unknown
  view, or one the run does not have, shows Overview, and the address is corrected.
- The chat scrolls only its own log, never the page.
- The story's search, filters and opened lines survive a view switch.
- The live story follows its *real* end until the reader scrolls away. Opening a line keeps it in place, and
  "Latest" brings the list back.
- The chat column, its open / close buttons and the localStorage key `backlog-app.live.chat` are gone.
- Pure rules in `packages/web/src/features/live/run-views.ts`, with unit tests in
  `packages/web/test/run-views.test.ts`.
- README: the *Live run* paragraph.

## Measurements (before / after, commands)

The measurement is `npm run build`, then `npx playwright test e2e/us8-live-layout.spec.ts`. It runs the real loop
with the fake claude replaying the 415 trace, and measures every view at 1920x1200, 1280x800, 1024x700 and 820x640.

- **Before (cbf0cf1f, `probe/layout_before.json`):**
  - `main` scrolled on every view and size, by 57-982 px;
  - Story and Raw trace added a second scrollbar;
  - below 1280 px the chat overlay covered 9 of 32 view/size cases.
- **After (`probe/layout_after.json`), all 40 cases:**
  - the document, `main` and the page root scroll 0 px, and nothing is covered;
  - at most one vertical scroll area per view, none nested;
  - every view reaches the page's bottom, and the story list, the transcript and the chat composer fill their view
    (0-1 px);
  - after a chat answer no ancestor of the log moved, and no `scrollIntoView` was called in the chat.
- **Negative control:** the same spec against the client built from cbf0cf1f fails 47 times
  (`probe/result_negative_cbf0cf1f.txt`).
- **Mutation run after review 1** (`probe/result_mutation_review1.txt`): a 68vh story list, a 60vh transcript and a
  `scrollIntoView` chat each fail `us8`.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `npm run check` (typecheck, lint, prettier, Vitest): clean; Vitest 519 passed, 2 skipped (+8 new).
- `npm run test:e2e` / `npx playwright test`: 40 passed (7.6 and 7.9 min), the second run on `d5f12cdd`. After the
  review-2 fixes, `us8`, `us7` and `us4-chat` passed.
- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd`: `BUILD SUCCEEDED`. The product is unchanged, so no `saltests` run and no `.slt` refresh were needed.

## Reviews (findings and what was done)

- **Review 1** (MUST 0, SHOULD 1, NOTE 5), all fixed:
  - S1: `us8` did not prove the fill or the chat. It now measures the part that must fill and the page root, and
    counts `scrollIntoView` in the chat, with a recorded mutation run.
  - N2: an opened story line jumped. The cause: a press on a line counted as scrolling, and react-virtuoso took a
    function `followOutput` as "follow" and pulled the list to its end after every render.
  - N3: the story choices reset on a view switch.
  - N4: a new chat turn came into view late.
  - N5: content was cut off below the supported sizes.
  - N6: a wheel notch near the end could be overtaken.
- **Review 2** (MUST 0, SHOULD 0, NOTE 3):
  - N1: the dashboard is keyed by the run;
  - N2: an unknown view is corrected in the address;
  - N3: leftover worktrees of earlier features' reviews under `%TEMP%` (`rev325`-`rev341r3/neg`, `rev414r5`,
    `rev414r6`). They are not this feature's; the maintainer may prune them (`git worktree prune` after deleting
    the folders).

## Owed to a person (the lines added to the release checklist)

One line in `manual-checks-owed-before-the-next-release`: the *Live run* during a real loop run, on a real screen
with a real mouse, in both themes. It covers the row of views, a page that never scrolls, the story following and
the reader's scroll, the full-width chat with a real Claude answer and its mark, and a reload keeping the view.

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- The live story stopped following when a new line was taller than estimated. It now follows by the reader's input.
- The phase headings' margins were missing from the story's measured height, so a following story stood 60 px short
  of its end. The gap is now padding.
- The DECISION pill inside a decision box had 4.50:1 contrast. The tints are lowered, giving 4.96:1.
- The chat's `scrollIntoView` scrolled every ancestor, including the page (latent at 1920). The log now sets its own
  `scrollTop`.

## New Inbox items (slug - title)

None.

## CHANGELOG

No entry: the backlog app is a development tool outside the product (features 344, 371, 414 and 415 added none
either).
