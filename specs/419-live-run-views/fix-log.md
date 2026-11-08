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

(see below as tasks are done)
