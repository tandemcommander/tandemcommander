---
title: Backlog app: a morning in the browser on the real repository
type: person-step
status: open
severity: 4
area: tooling
source: leftover:344
who: person
created: 2026-10-30
updated: 2026-10-30
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Backlog app: a morning in the browser on the real repository

## Problem

Feature 344's backlog app was tested end to end only on fixture repositories, with the fake claude and the loop's console window hidden (`--new-window-hidden`, a test option). Two things need a person: the success criterion SC-002 (the maintainer steers a morning in the browser alone, in under 10 minutes, on the real backlog) and the loop's own visible console window started by the app (`loop.py start --new-window`), which no automated test showed on screen.

## Evidence

`specs/344-backlog-web-app/quickstart.md` Q22 (SC-002) and the fix-log section *Quickstart scenarios Q1-Q22 (T133)* (Q22 recorded as a person step); the hidden window option: `specs/344-backlog-web-app/contracts/loop-cli-additions.md`.

## Expected

Every step below done and ticked, with what was seen in the note.

## Steps

- [ ] With the loop not running, start `bin/start-backlog-app.sh` from the repository root: the browser opens the app signed in (first start installs and builds, at most 2 minutes; a second start within the session takes seconds and reuses the running app).
- [ ] Home page after a night of runs: the overnight runs, their outcomes and any stop for a person are shown; open one run and its transcript (attempts, tool calls, cost).
- [ ] Triage up to 10 Inbox items in the Triage view with the keyboard (accept, adjust, skip); then reorder two rows of Next by dragging and one with Alt+Up; every change appears in the tray (top bar).
- [ ] Commit the tray: one commit `backlog(app): ...` touching only `backlog/` (check with `git show --stat HEAD`); `bin/backlog.sh check` prints `TOTAL: 0`.
- [ ] Start the loop from the Loop page (Start the loop): a new visible console window titled `Backlog loop` opens; the Live page shows the item, its phase and the current tool within seconds.
- [ ] Pause from the app: the state shows *Pause pending*, then *Paused* after the item; Resume clears it. Close the app with Ctrl+C in its window: the loop window keeps running.
- [ ] The whole morning (steps 2 to 5) took under 10 minutes in the browser alone, without a terminal command except the start (SC-002); note the time.

## Log

- 2026-10-30 — created (source leftover:344)
- 2026-10-30 — steps written from quickstart Q22 and the hidden-window gap
- 2026-10-30 — relation removed (recorded by mistake)
- 2026-10-30 — moved to Person steps position 74
