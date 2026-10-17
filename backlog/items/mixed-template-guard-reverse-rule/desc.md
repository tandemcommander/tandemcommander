---
title: Mixed-template guard: no reverse rule, sinks found by variable names
type: tech-debt
status: open
severity: 2
area: tooling
source: leftover:127
who: agent
created: 2026-10-13
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Mixed-template guard: no reverse rule, sinks found by variable names

## Problem

The mixed-template guard of feature 127 has no reverse rule (a `LoadStr(` piece inside a `LoadStrU8` template, an A-API sink) and its sink patterns depend on the variable names `params` / `log`, so new mixed compositions under other names pass unnoticed.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L558-560 (point (3)). Feature 127 (`specs/127-mixed-template-texts/`, guard outputs `probe/guard_before.txt`, `guard_after.txt`).

## Expected

The guard reports a `LoadStr(` piece inside a `LoadStrU8` template and UTF-8 text reaching an A-API sink, independent of variable names; `TOTAL: 0` stays on the tree.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
