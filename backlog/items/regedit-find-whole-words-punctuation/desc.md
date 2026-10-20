---
title: Registry Editor Find: Whole words ignores punctuation that the help names
type: bug
status: new
severity: 2
area: other-plugins
source: measure:257
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Registry Editor Find: Whole words ignores punctuation that the help names

## Problem

Registry Editor Find, **Whole words**: the help says a found substring "must be preceded and
followed by a space, tab, or punctuation character, or be at the start or end of the name", but
the search accepts only space characters (and the start / end) as boundaries. Searching `bar`
with Whole words does not find `foo,bar` or `(bar)`. Either the help or the search is wrong.

## Evidence

Measured while working on feature 257 (`specs/257-regedt-find-words-hex/spec.md`, clarification
4), by reading. Help: `src/plugins/regedt/help/hh/regedt/dlgboxes_search.htm`, *Whole words*.
Code at 3d2ffb53: `src/plugins/regedt/finddlg.cpp` `CFindThread::Test` - the text / binary
branches test `iswspace` / `isspace`; the regexp branch calls `SalRegFindWholeWordInLine`
(`src/common/salregfind.h`, `isspace`).

## Expected

The Whole words boundary and the help agree: punctuation counts as a boundary in every branch
(plain text, binary, regexp), or the help drops "punctuation" - and the probe of 257
(`find_words_hex_probe.ps1`) gets a row for `foo,bar`.

## Notes

Which side changes is a small product choice; the item's natural reading (the help is the
promise) is to accept punctuation. A help change alone would not need translations of UI
strings, but the help's own translations, if any, would follow.

## Log

- 2026-10-20 — created (source measure:257)
