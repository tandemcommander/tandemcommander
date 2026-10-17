---
title: Disk Map closing with its menu or a shell confirmation open, with a real mouse
type: person-step
status: open
severity: 3
area: other-plugins
source: leftover:143
who: person
created: 2026-10-14
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [plugin-close-forced-unload-and-stray-box]
depends-on: []
reason: -
---

# Disk Map closing with its menu or a shell confirmation open, with a real mouse

## Problem

Feature 143 (a Disk Map window is never destroyed inside its menu, box or shell command) was driven by posted messages on the hidden desktop. The same routes with a real mouse on the visible desktop are owed to a person.

## Evidence

Migrated from specs/NEXT-WORK.md §A item 1 (L126) (at 7993914c). specs/143-diskmap-release-guard/quickstart.md, *Owed to a person*; the probe's result specs/143-diskmap-release-guard/probe/result.txt (PASS 34, FAIL 0; the control before 143 crashed in E1, E4, E5, E6, U1).

## Expected

No crash in either route; the program exits; with the confirmation answered the file is kept.

## Steps

- [ ] Open Disk Map, right-click a file in the map and leave the menu open, then close the program from the taskbar (the menu closes when the map loses activation - the crash needed the menu to stay, e.g. sign-out or an update in the background): no crash, the program exits
- [ ] Delete from the map's menu so that the real confirmation is open, then exit the program from its main window: answer the confirmation, then the core's "force" question Yes: no crash, the program exits

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
