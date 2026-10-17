---
title: 106's packself probe row A-zip-noask-refused is stale since 119
type: tech-debt
status: open
severity: 1
area: tooling
source: probe:165
who: agent
created: 2026-10-14
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# 106's packself probe row A-zip-noask-refused is stale since 119

## Problem

`specs/106-zip-overwrite-source/probe/packself_probe.ps1` row A-zip-noask-refused expects the "already exists" question before the refusal; since 119 the pack is refused before the question, so the row fails (69 / 1) on a correct build. 119's `packleft_probe.ps1` carries the row with the new expectation; until the stale row is fixed, Pack regressions must use packleft.

## Evidence

Migrated from specs/NEXT-WORK.md §A item 18 (L389) (at 7993914c). specs/165-zip-entry-count/fix-log.md ~line 72 ("106's packself 69 / 1: A-zip-noask-refused expects ..."); specs/119-packing-leftovers/probe/packleft_probe.ps1.

## Expected

packself_probe passes on the current build (the row expects the refusal without the question, or is removed with a pointer to packleft).

## Notes

Not handled by 168 (it fixed 088's and 093's rows only).

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
