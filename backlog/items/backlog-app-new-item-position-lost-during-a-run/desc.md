---
title: Backlog app: a new item placed at Next #1 during a run twice landed at the end (not reproduced)
type: bug
status: new
severity: 3
area: tooling
source: measure:371
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: -
feature: -
related: []
depends-on: []
reason: -
---

# Backlog app: a new item placed at Next #1 during a run twice landed at the end (not reproduced)

## Problem

In two of eight runs of the e2e test us1-live-edit (feature 371) the item created through the New item form with 'Place it: Next, Position: 1' while a fake run was in progress landed at the end of Next (the request had no position); the other runs placed it at #1 and the unit tests of the same route always do. Whether the form lost the typed position (a re-render while the board changed under it) or the request did is not known.

## Evidence

specs/371-backlog-app-live-editing/fix-log.md (the e2e runs 3 and 4 of 2026-11-01); the test now logs the item's log lines on main when the placement fails.

## Expected

The position typed in the New item form reaches the request every time, also while the board changes under the form (a run in progress, the loop's events).

## Log

- 2026-11-01 — created (source measure:371)
