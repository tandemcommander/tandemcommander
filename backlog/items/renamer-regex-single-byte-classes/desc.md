---
title: Renamer: regular expressions judge \b, \w, classes and '.' by single bytes
type: bug
status: open
severity: 4
area: other-plugins
source: review:210
who: agent
created: 2026-10-15
updated: 2026-10-20
verified: 2026-10-20 3ea24ab5
effort: L
feature: -
related: [renamer-long-new-name-limits]
depends-on: []
reason: -
---

# Renamer: regular expressions judge \b, \w, classes and '.' by single bytes

## Problem

The Renamer's regular-expression engine still judges `\b`, `\w`, `\d`, `\s`, POSIX classes, '.', bracket classes and a quantifier after a multi-byte letter by single bytes: a pattern that would split a UTF-8 letter is refused "(123)"; a `\xC5\xBD` escape matches neither case when case-insensitive (it matched the capital before 210); bracket ranges with non-ASCII bounds are meaningless over UTF-8; letters outside the BMP and combining marks break words; the Greek final sigma does not fold with sigma (a match missed, never a wrong letter). Also: the history dedupe and the preview's sort use the code-page `StrICmp` (nothing is renamed by them).

## Evidence

Migrated from specs/NEXT-WORK.md §A item 11 (L315) (at 7993914c). specs/210-renamer-utf8-search/fix-log.md ("Recorded (older, not of this fix)", ~line 74). At 7993914c: `src/plugins/renamer/regexp.cpp`; history dedupe `src/plugins/renamer/dialogs.cpp` ~259 (`SG->StrICmp`); preview sort `preview.cpp` ~409-433 (`RegSetStrICmp`).

## Expected

Classes, '.', `\b` and quantifiers work on whole UTF-8 letters; no pattern is refused for splitting a letter; the history and the preview sort compare by the file system's rule or by whole letters.

## Approach

Pure matching rules into a header with saltests checks (CLAUDE.md working method); 210's probe has the Renamer fixtures.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
- 2026-10-20 — verified at 3ea24ab5: probe at 3ea24ab5 (ACP 1250): 16/18 regex rows fail - 9 refused (123), a wrong letter replaced by a\b, quant/lookb/esc/sigma miss; preview sort already UTF-8 (RegSetStrICmp, 004); history StrICmp by reading
