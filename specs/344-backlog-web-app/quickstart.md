# Quickstart and validation: Backlog web app (344)

How to run the application and how to prove each user story and success criterion. Shapes and
rules: [contracts/](contracts/), [data-model.md](data-model.md). Results go into `fix-log.md`.

## Prerequisites

- Windows 11, Git for Windows (Git Bash), Python (the build's), Node.js >= 24.15 (or 26.x) with
  npm 11, Microsoft Edge (end-to-end tests), Claude Code CLI (stories 2, 5, 6 with a real run).
- Tests never use the real `backlog/`: the automated suites build a fixture repository in a
  temporary folder (a copy of `tools/backlog/fixtures/valid` committed into a fresh git
  repository) and drive the loop with `tools/backlog/fixtures/fake_claude.py`.

## Run

```bash
bin/start-backlog-app.sh --help          # usage, exit 0, works without Node
bin/start-backlog-app.sh                 # install if needed, build, start, open the browser
bin/start-backlog-app.sh --dev           # live reload while working on the app
bin/start-backlog-app.sh --root <copy> --port 47400 --no-open   # a scratch repository
```

## Automated gates (all must pass before a slice is done)

```bash
cd tools/backlog-app
npm run check        # typecheck + lint (incl. documentation rules) + docs:check + unit/API tests
npm run test:e2e     # Playwright on Edge against a fixture repository, both themes, axe
cd ../..
python -m unittest tools/backlog/test_backlog.py tools/backlog/test_loop.py tools/backlog/test_traces.py
python tools/test_bin_help.py
```

## Scenarios

| # | Story / SC | Steps | Expected |
|---|---|---|---|
| Q1 | US1, SC-003 | Open the backlog view on a copy of the real repository; compare every section with `bin/backlog.sh list --json` | Same slugs, order and fields; counts equal |
| Q2 | US1, SC-005 | Filter `area:archives type:bug sev>=4`; search "code page"; copy the address into a new tab | Exactly the matching rows; snippet highlighted; the new tab shows the same view; results < 1 s |
| Q3 | US1 | Open an item, its *History* tab, a closed item in *Closed* | Rendered Markdown, log, relations both ways, commits; the closed item's last description and feature |
| Q4 | US2, SC-004 | Fixture repo: start the loop from the app with the fake claude scripted for a long run | A new console window titled `Backlog loop`; the live view shows phase, tasks, current tool and messages within 5 s of each trace write |
| Q5 | US2 | Pause, resume, stop from the app; then start a loop in a terminal (`bin/backlog-loop.sh start --root <copy>`) | `pause pending` -> `paused`; resume clears; the terminal loop is shown and controlled the same way |
| Q6 | US2, SC-011 | Close the app (Ctrl+C) during a run; reopen | The run continues untouched; the reopened app shows the current state within 5 s |
| Q7 | US2, FR-017 | Hard stop from the app (typed confirmation) | Loop exit 130 in its window, run phase `killed`, lock kept; the next start continues the run |
| Q8 | US3, SC-003 | Copy repo: drag a row in Next, Alt+Down another, triage 3 Inbox items, block/unblock, park, reject with a reason | Files equal the result of the same `bin/backlog.sh` commands on a second copy; `check` TOTAL 0; reorders added no item log lines |
| Q9 | US3 | While the loop runs unpaused / a run holds the lock / HEAD is not `main` | Every changing control disabled with the reason; reading works; during a run the board comes from `main` |
| Q10 | US3, FR-024 | Open an item, change its `desc.md` in a terminal, save in the app | `changed underneath`, the new state shown, the typed text kept |
| Q11 | FR-034 | Make 3 changes, open the tray, commit; make 1 change, start the loop | One commit `backlog(app): ...` touching only `backlog/`; before the start the pending change is committed (asked once) and the loop does not wait on a dirty tree |
| Q12 | FR-035 | Make 2 changes, undo both; make a change, edit the file in a terminal, undo | Files back to the start; the second undo is refused (file changed since) |
| Q13 | US4, SC-008 | New bug item with a 20,000-character problem text containing `` ` ``, `$(rm -rf x)`, quotes, `\\`, newlines, Czech letters | Stored byte-exact (`show --json` returns the same text); nothing executed; no command line carried the text (process listing during the call) |
| Q14 | US4 | Decide a decision item with option B -> move to Next @3; tick 2 person-step lines with notes | Log lines with date; the item in Next at 3; `- [x]` lines |
| Q15 | US5 | Ask "which encoding bugs are agent-doable and small?"; draft an item from a Czech sentence; cancel a running job | Answer links items; draft in English, nothing written before *Create*; cancelled job keeps its partial output |
| Q16 | US6 | Run one chosen item (fake claude); bulk-block 5 items; open the transcript of a past run | Single run with trace and verdict, backlog order unchanged; 5 per-item results; transcript with attempts, tool calls, cost |
| Q17 | SC-007 | Security suite (contracts/security.md *Tests*) and a manual check from another browser profile without the token | All refused |
| Q18 | SC-006 | 20 loop runs with the fake claude and the app open, polling at full rate | No loop wait caused by the app, no failed atomic replace (`loop.json`, `meta.json`, lock), no change to the lock or loop state by the app |
| Q19 | SC-009 | axe in both themes on every screen; journeys of stories 1-3 with the keyboard only (Playwright) | No AA violations; every journey completes |
| Q20 | SC-010 | `npm run lint` and `npm run docs:check` | Zero undocumented files, classes, functions, exported symbols |
| Q21 | SC-001 | Fresh clone: `bin/start-backlog-app.sh`; then again | First start < 2 min (install + build), later < 10 s |
| Q22 | SC-002 | Person step for the maintainer: a morning routine on the real repository (overnight runs, 10 Inbox items, reorder, restart the loop) | Done in the browser alone in < 10 min - recorded as a person step if not driven |
