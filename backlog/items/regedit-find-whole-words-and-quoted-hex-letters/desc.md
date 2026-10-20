---
title: Registry Editor Find: whole-word regexp, empty regexp, letters in quoted hex
type: bug
status: in-progress
severity: 4
area: other-plugins
source: review:190
who: agent
created: 2026-10-15
updated: 2026-10-20
verified: 2026-10-20 2437c4dd
effort: S
feature: 257
related: []
depends-on: []
reason: -
---

# Registry Editor Find: whole-word regexp, empty regexp, letters in quoted hex

## Problem

Registry Editor Find, left of the list found by the review of 190 (items 1-5 done by 191 / 192): (6) Regexp with Whole words tests `text[pos - 1]` / `text[pos + matchLen]` with `pos` counted from the line, not the buffer - wrong on the second and later lines of a list (NIT); an empty regexp goes to `Set("")` instead of "everything" (NIT). (7) (found by 191's review, older) a letter that needs 2 bytes in the code page inside `'...'` of a hex pattern becomes a 0x00 byte (`ConvertHexToString`) - with a UTF-8 code page every non-ASCII letter: the search looks for other bytes than typed.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L570-591 (items 6 and 7). `utils.cpp` `ConvertHexToString` (~346), `finddlg.cpp`; features 190, 191, 192 (`specs/190-regedt-find-number/`, `specs/191-regedt-find-input/`, `specs/192-regedt-find-numbers/`).

## Expected

Whole-word regexp matches are judged by the buffer position on every line; an empty regexp finds everything; a quoted letter in a hex pattern is converted to its code-page bytes (or UTF-8 as documented) - the search looks for what was typed.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-20 — verified at 2437c4dd: probe 257 at 2437c4dd: whole-word regexp on line 2 wrong both ways, empty regexp + whole words finds nothing; hex 2-byte letter by code reading (ACP 1250 here)
- 2026-10-20 — run started, feature 257
