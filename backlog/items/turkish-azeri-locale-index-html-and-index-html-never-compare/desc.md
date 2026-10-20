---
title: Turkish / Azeri locale: index.html and INDEX.HTML never compare as one name
type: bug
status: new
severity: 2
area: panels-ui
source: leftover:261
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: ?
feature: -
related: []
depends-on: []
reason: -
---

# Turkish / Azeri locale: index.html and INDEX.HTML never compare as one name

## Problem

With a Turkish or Azeri user locale the panel's name comparison treats `i` / `I` as different
letters (dotted / dotless i), so "index.html" and "INDEX.HTML" never compare as one name where the
core uses the locale comparison - e.g. Compare Directories marks such a pair in two ordinary
folders as two unpaired files, although the file system takes them for one name. Upstream
behaviour, left open by backlog item `case-sensitive-twins-first-match` (feature 261).

## Evidence

By reading at 0e151c5a (branch 261-case-twins-exact-match): `src/sort.cpp` `RegSetStrICmpEx` (the
locale / numeric-aware case-insensitive comparison) is the first key of `CmpNameExt` (the panel's
name sort) and of `CmpNameExtIgnCase` (Compare Directories' pairing); the file system's rule
`SalNameCompareOrdinalCI` (feature 092) is only the tie-break. Origin: specs/NEXT-WORK.md §D
(migrated into item `case-sensitive-twins-first-match`), review of feature 232.

## Expected

In a Turkish / Azeri locale, names equal by the file system's rule pair in Compare Directories (and
wherever the locale comparison decides "the same name"); the panel's sort order stays as the user
expects for that locale.

## Notes

Not measured (needs a Turkish locale on the test machine, or a seam). Changing the first key of the
panel sort changes the order of every panel; the fix probably belongs in the places that decide
equality, not in the sort. The item's origin said "possibly to park" - the maintainer may prefer
to park it.

## Log

- 2026-10-20 — created (source leftover:261)
