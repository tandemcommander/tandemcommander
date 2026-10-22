---
title: Quick search keys skip canonical reordering of combining marks
type: bug
status: open
severity: 2
area: encoding
source: leftover:244
who: agent
created: 2026-10-18
updated: 2026-10-23
verified: 2026-10-23 4eb6cdb1
effort: S
feature: -
related: [quick-search-first-keystroke-over-100-000-non-ascii-names]
depends-on: []
reason: -
---

# Quick search keys skip canonical reordering of combining marks

## Problem

Quick search in the new mode compares keys: the canonical decomposition (NFD) of each character in lower case (`SalQFBuildKey`, feature 244). The decomposition is done per code point, so two or more combining marks after one base letter are not put into canonical order. Canonically equivalent texts that differ only in the order of their marks do not match. Example: "e" + U+0323 + U+0302 (the order canonical decomposition produces for U+1EC7) against U+00EA + U+0323 (which decomposes to "e" + U+0302 + U+0323 without reordering).

## Evidence

At 7536fcc2: `src/common/salquickfilter.h` `SalQFBuildKey` calls `SalQFDetail::CharKey` per decoded character; the second refute-first review of feature 244 (`specs/244-quick-search-substring-filter/fix-log.md`, round 2) found it by reading the code; not reproduced in a probe.

## Expected

Keys of canonically equivalent texts are equal: the combining marks following a base letter are sorted by their canonical combining class (or each base letter with its marks is normalised as one unit), with a `saltests` case for the example.

## Notes

Rare (stacked diacritics typed in a different order than stored); case and the common precomposed/decomposed pairs already match.

## Log

- 2026-10-18 — created (source leftover:244)
- 2026-10-19 — moved to Next position 62
- 2026-10-23 — verified at 4eb6cdb1: feature 313: the new mode drops the marks of U+0300-036F and the other Latin/Greek/Cyrillic mark blocks, so the example (e + U+0323 + U+0302 vs U+00EA + U+0323) now matches; still present for marks outside those blocks (Hebrew points, Arabic vowel signs, Indic signs)
