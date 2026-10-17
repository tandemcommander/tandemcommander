---
title: User Menu through a shell: a UNC panel folder runs the command in C:\Windows
type: bug
status: open
severity: 2
area: panels-ui
source: review:226
who: agent
created: 2026-10-15
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [user-menu-messages-and-folder-leftovers]
depends-on: []
reason: -
---

# User Menu through a shell: a UNC panel folder runs the command in C:\Windows

## Problem

A User Menu item run "through a shell" from a UNC panel folder: cmd refuses a UNC current folder and runs in C:\Windows; a UNC Initial Directory writes no `cd`. Affects a "through shell" item with no Initial Directory, a relative name and a UNC panel.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L722-727. Features 226 (`specs/226-user-menu-batch-encoding/`), 234 (a differing UNC item folder is refused).

## Expected

The batch file starts with `pushd` to the UNC folder and ends with `popd` (early ends jump to it with `goto`), or the item is refused with a message - never run in C:\Windows.

## Approach

The maintainer's note: a safe fix would be `pushd` at the start, `popd` at the end, early ends by `goto` to it.

## Notes

The maintainer stated severity 2-3; the lower value is used.

## Log

- 2026-10-16 — maintainer: stays in the backlog (severity about 2-3/10: a "through shell" item, no Initial Directory, a relative name, a UNC panel; a safe fix would be pushd at the start, popd at the end, early ends by goto to it)
- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
