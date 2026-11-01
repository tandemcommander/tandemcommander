---
title: Check by hand: switching back with a WSL folder in a panel no longer freezes
type: person-step
status: open
severity: 4
area: panels-ui
source: leftover:372
who: person
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Check by hand: switching back with a WSL folder in a panel no longer freezes

## Problem

Feature 372 removed the waits on the UI thread that a WSL folder in a panel caused at every
switch back to the program. Two parts of that could not be checked in the run: the busy cursor
(another process's cursor cannot be read on the hidden desktop the probes use) and the first
switch back after the WSL distribution has stopped (a ~2 s first answer; stopping the
maintainer's distribution is not a run's to do).

## Evidence

- `specs/372-wsl-activation-freeze/fix-log.md`, *Probe after the fix* (CURSOR rows NOT DRIVEN) and
  *Review* (review 1 SHOULD: the cold-distribution case is reasoned, not measured);
  `specs/372-wsl-activation-freeze/quickstart.md` step 4.

## Expected

On the user's own desktop: no busy cursor and no perceptible pause when switching back, with a
warm and with a stopped distribution; the panel still shows the folder's current content.

## Steps

- [ ] Build of the tree at or after feature 372 (`build.cmd`), start it with the left panel on
      `\\wsl.localhost\Ubuntu\home` (or another distribution's folder).
- [ ] Alt+Tab to another window and back about ten times: the pointer never turns into the busy
      circle, and arrow keys typed right after switching back move the cursor in the panel at
      once. (The ~150 ms clipboard check that every activation pays is the Inbox item
      `every-activation-of-the-program-blocks-it-150-ms-in-the-idle`; note whether it is
      noticeable.)
- [ ] While the program is in the background, create a file in that folder from a WSL shell
      (`touch ~/tc372-check.txt` when the panel shows the home folder); switch back: the file
      appears within about 2 s without pressing Ctrl+R. Delete it again.
- [ ] Run `wsl --shutdown` in a command prompt while the program is in the background, wait 10 s,
      switch back: the window answers at once (no freeze, no "ESC to cancel" window); the panel
      content is refreshed a few seconds later, when the distribution has started.

## Log

- 2026-11-01 — created (source leftover:372)
- 2026-11-01 — moved to Person steps position 30
