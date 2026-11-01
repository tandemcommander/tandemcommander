# Quickstart - verifying 371

All checks run against throw-away fixture repositories (the harness of 344) or a copy of the real
repository; never against `E:\Projects\tandemcommander\backlog` with write actions.

## Prerequisites

```sh
cd tools/backlog-app && npm ci          # Node 24.15+, npm 11+
python -X utf8 tools/backlog/test_backlog.py   # from the repository root
python -X utf8 tools/backlog/test_loop.py
```

## Automated

```sh
cd tools/backlog-app
npm run check                           # typecheck, lint, format, unit + API tests (dates fixed: Q9)
npm run test:e2e                        # Playwright in Edge: us1-live-edit, us3-order, us4-chat + the 344 suites
BACKLOG_APP_SOAK=1 npx vitest run packages/server/test/write-race.test.ts   # SC-002, SC-007 (minutes)
```

Expected: every test passes; the soak prints "200 changes, 0 lost, 0 runs on a dirty tree" and
"20 runs x 3 changes, 0 lost".

## By hand (Q1-Q8)

Start the app on a copy of the repository: `bin/start-backlog-app.sh --root <copy>` (the copy on
`main`, clean, with `git config user.*`).

| Q | Steps | Expected |
|---|---|---|
| Q1 | Loop page → Start (fake claude: `BACKLOG_APP_LOOP_TEST_ARGS` with `--claude-cmd` of `fake_claude.py` and a plan `[{"do":"branch-hang","seconds":120}]`); wait for "Running" | Home: *In progress* 1 with the item; *Next* without it; "Next up" names another item; the gate banner says changes land on `main` and are committed at once |
| Q2 | New item → place at *Next* #1 → Save | Within 10 s the board shows it at #1; `git -C <copy> log main -1` is `backlog(app): ...`; the run is untouched (its window, `status` running) |
| Q3 | Open the running item | Every control disabled: "a run works on this item"; the page says *In progress*, feature NNN, a link to the live run |
| Q4 | Close an item that names the running one in `related` | Refused: "would change the running item"; nothing changed |
| Q5 | Let the run end | The run's close is on `main` **and** the new item is at #1; `In progress` empty; the loop takes the new item next (or idles if it is not eligible) |
| Q6 | On an item at Next #20: type 3 in the position field; press "Move to the top" | #3, then #1 within 3 s; the table's position cell and row menu do the same |
| Q7 | Item page → "Chat about this item" | A new window, no sidebar, essentials visible at 1920 x 1080; send "what is this about?" → reply streams; reload → the exchange is there; "New conversation" → empty |
| Q8 | While the loop is waiting between runs (nothing eligible): block an item | Applied at once and committed; the loop never pauses; `bin/backlog-loop.sh status` shows no `waiting: the working tree is not clean` |

Negative controls: Q2 with the loop in its first minute (the fake's measurement phase on `main`):
the banner says "the run is on main" (read-only) and opens when the run moves to its branch; Q7
with claude renamed away: the page says the tool was not found and keeps the transcript.
