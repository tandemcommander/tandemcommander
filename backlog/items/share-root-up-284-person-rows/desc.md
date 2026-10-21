---
title: Share root way up (284) by hand: drop onto .., a real server, Esc in the wait
type: person-step
status: open
severity: 2
area: panels-ui
source: leftover:284
who: person
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: [real-file-server-person-rows, drag-drop-paste-routes-194-228-230-240-by-hand]
depends-on: []
reason: -
---

# Share root way up (284) by hand: drop onto .., a real server, Esc in the wait

## Problem

Feature 284 made the way up from a share's root (`..`, Backspace, *Go to root*, *Open in other panel*) offer the server's shares without a Network plug-in. Three of its rows need a real mouse, a real Esc key or a real file server, which the hidden-desktop probe cannot give.

## Evidence

`specs/284-share-root-parent/fix-log.md` section *Not driven (owed to a person)*; probe `specs/284-share-root-parent/probe/shareroot_probe.ps1` (22 PASS, all against `\\localhost` with the share-list seam of 125). The drop guard is `GetCurrentDir` in `src/shellsup.cpp` (feature 284); the wait window is `CFilesWindow::PickServerShare` (`src/fileswnb.cpp`, feature 125).

## Expected

Dropping onto the `..` of a share's root is refused (stop cursor); Backspace in a real server's share offers that server's shares; Esc in the wait window gives up without a message.

## Steps

- [ ] Release or Debug build without the Network plug-in. Open `\\localhost\C$` (or any share's root) in the left panel, drag a file from the right panel onto the `..` entry: the cursor is the stop cursor and dropping does nothing (no copy dialog, no error). Dropping onto a folder of the same panel still works.
- [ ] In `\\<a real file server>\<share>` press Backspace: the list of that server's shares appears under the directory line; choosing one opens it; *Go to root* (Shift+Backspace) does the same.
- [ ] A server that answers slowly (or an address that does not answer, e.g. `\\192.0.2.1\x` reached from history): Backspace in its share's root shows the "Checking path" wait window after a moment; Esc closes it and the panel stays where it was, no message.

## Log

- 2026-10-21 — created (source leftover:284)
- 2026-10-21 — moved to Person steps
