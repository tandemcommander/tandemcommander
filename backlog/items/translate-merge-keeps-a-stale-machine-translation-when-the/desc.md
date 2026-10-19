---
title: translate.merge keeps a stale machine translation when the English text changes
type: bug
status: open
severity: 3
area: translations
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

# translate.merge keeps a stale machine translation when the English text changes

## Problem

merge.py carries a machine-provenance row over by its id even when the English source of that id changed, so the shipped translation keeps the old meaning.

## Evidence

Feature 245: three reworded strings (ids 10321, 10521, 10526) kept their old German text after merge; removing the rows from the .slt made them gaps and they were translated again (specs/245-settings-import-salamander/fix-log.md, round 2).

## Expected

A machine row whose English changed since it was translated is treated as a gap (or flagged) without re-translating every machine row of the module.

## Log

- 2026-10-18 — created (source measure:245)
- 2026-10-19 — moved to Next position 44
