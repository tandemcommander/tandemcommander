---
title: The stored main window icon index is checked against the count, not the last index
type: bug
status: open
severity: 1
area: panels-ui
source: measure:245
who: agent
created: 2026-10-18
updated: 2026-10-19
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# The stored main window icon index is checked against the count, not the last index

## Problem

LoadConfig accepts a stored Main window icon index equal to MAINWINDOWICONS_COUNT (one past the last icon); the getter clamps it, so nothing visible happens today.

## Evidence

src/mainwnd2.cpp:3375 at 18e0bd3c: MainWindowIconIndex > MAINWINDOWICONS_COUNT; the getter in src/dialogs4.cpp clamps. specs/245-settings-import-salamander/analysis.md A11.4.

## Expected

The load check uses >= so an out-of-range index falls back to 0 at load.

## Log

- 2026-10-18 — created (source measure:245)
- 2026-10-19 — moved to Next
