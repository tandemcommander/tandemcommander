---
title: A history entry with invalid text hides the entries saved after it
type: bug
status: open
severity: 2
area: encoding
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

# A history entry with invalid text hides the entries saved after it

## Problem

LoadHistory drops an entry that is not valid UTF-8 (feature 005) by leaving NULL in its slot and continuing; the readers of a history stop at the first NULL, so every entry saved after the invalid one is no longer offered.

## Evidence

src/salamdr2.cpp:2586 at 18e0bd3c (LoadHistory): history[i] = NULL for an invalid entry, the loop goes on with i+1. Found while writing the history group of feature 245; not reproduced.

## Expected

Valid entries after an invalid one are moved up (no gap), so they stay offered.

## Log

- 2026-10-18 — created (source measure:245)
- 2026-10-19 — moved to Next position 59
