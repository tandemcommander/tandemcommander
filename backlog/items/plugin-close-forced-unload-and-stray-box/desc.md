---
title: Plug-in closing: forced Disk Map unload in a shell command, stray comparator box
type: bug
status: open
severity: 3
area: other-plugins
source: leftover:143
who: agent
created: 2026-10-14
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [diskmap-close-real-mouse-rows]
depends-on: []
reason: -
---

# Plug-in closing: forced Disk Map unload in a shell command, stray comparator box

## Problem

Two leftovers of the plug-in window closing work. (1) Disk Map (143): a forced unload (the core's "force?" answered Yes) while a shell command of the map is running (a command of its context menu, a shell confirmation) terminates the map's thread inside the shell (`KillAll(TRUE)`), as in every release; the Debug build then shows its leak reports (monitored handles, CRT). (2) File Comparator, hex view (147 review LOW-2): its `WM_DESTROY` pump (`PM_REMOVE`) can dispatch a pending `WM_USER_HANDLEFILEERROR` and show a stray error box while the window closes; no crash path, reachability low (posted messages come before paint; the window is hidden first). Next to it, a trap for later work: `CFileMapping::Destroy` does not reset `FileSize`, so a later paint would post "handle is invalid".

## Evidence

Migrated from specs/NEXT-WORK.md §A item 1 (L124) and item 3 (L151) (at 7993914c). Disk Map: specs/143-diskmap-release-guard/fix-log.md, *Work* (probe row E5: "the forced unload terminates the map's thread inside the shell (`KillAll(TRUE)`, every release) and the Debug build shows its leak reports"); probe in specs/143-diskmap-release-guard/probe/ (rows E4, E5). File Comparator: specs/147-plugin-close-boxes/fix-log.md, *Review*, LOW-2 (`filecomp` hex view `WM_DESTROY`, `CFileMapping::Destroy`).

## Expected

A forced unload during a Disk Map shell command does not terminate a thread inside the shell (it waits for the shell call to return, or is declined with a message); the comparator's hex view shows no error box once its close began; `CFileMapping::Destroy` resets `FileSize`.

## Approach

Measure first: 143's probe row E5 drives the forced unload. Terminating the thread is the core's "force" semantics (147's review calls the comparable LOW-3 exactly that), so keeping it is a valid outcome for part (1).

## Notes

Low: part (1) needs the user to force the unload, part (2) a narrow timing. If the forced termination is accepted as the force semantics, park or reject part (1) with that reason and keep part (2).

## Log

- 2026-10-14 — feature 143 done; the forced unload during a shell command recorded as left
- 2026-10-14 — feature 147 done; its review recorded the hex view's stray box (LOW-2)
- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
