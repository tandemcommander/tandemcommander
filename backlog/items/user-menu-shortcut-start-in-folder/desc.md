---
title: User Menu: a shortcut command may start in the item folder, not its own Start in
type: bug
status: open
severity: 3
area: panels-ui
source: manual
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: [user-menu-messages-and-folder-leftovers]
depends-on: []
reason: -
---

# User Menu: a shortcut command may start in the item folder, not its own Start in

## Problem

Since feature 234 a User Menu item run directly (not through a shell) always passes a folder to ShellExecuteEx: the Initial Directory, else the item's folder (before 234: the Initial Directory or none). When the command is a shortcut (`.lnk`) with its own "Start in" folder, the program it starts may now run in the panel's folder instead of the folder the shortcut names - a tool that reads its files relative to its own folder would not find them. Suspected, not measured.

## Evidence

At 50cf9e7d (by reading): `src/mainwnd4.cpp` `CMainWindow::UserMenu` direct route, `sei.lpDirectory = (initDir[0] != 0) ? initDir : (path[0] != 0 ? path : NULL); // feature 234: else the item's folder` (~1081). Recorded by the first review of 234 (`specs/234-user-menu-item-folder/fix-log.md`, *Review* 1: "a `.lnk` command's own "Start in" vs `lpDirectory`"). Split from `user-menu-messages-and-folder-leftovers`.

## Expected

Measured first: with a shortcut whose "Start in" is set, which folder the started program gets with and without `lpDirectory`. If `lpDirectory` overrides it, a shortcut command without an Initial Directory keeps its own "Start in" (e.g. no `lpDirectory` when the command resolves to a `.lnk` with a working directory), and a probe row shows it; other commands keep 234's behaviour.

## Notes

If ShellExecuteEx keeps the shortcut's own folder, the item is closed as not reproduced. A shortcut with an empty "Start in" should still get the item's folder (234).

## Log

- 2026-10-20 — created (source manual)
- 2026-10-20 — moved to Next position 55
