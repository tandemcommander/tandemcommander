---
title: Check Ctrl+X ghosting and User Menu compare names with case twins
type: person-step
status: new
severity: 3
area: panels-ui
source: leftover:261
who: person
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Check Ctrl+X ghosting and User Menu compare names with case twins

## Problem

Feature 261 changed two lookups that the hidden desktop cannot drive: Ctrl+X ghosting in the other
panel (needs the real clipboard, shared with the maintainer's desktop) and the User Menu's second
compare name (needs a configured User Menu item). Both use the rule `SalNamePickIndex` checked by
`saltests`; the GUI behaviour is unconfirmed.

## Evidence

`specs/261-case-twins-exact-match/fix-log.md`, *NOT DRIVEN (owed to a person)*;
`specs/261-case-twins-exact-match/quickstart.md` step 5. Code: `src/shellsup.cpp` (Ctrl+X,
`saCutToClipboard`), `src/mainwnd3.cpp` (User Menu compare names).

## Expected

Both steps below give the stated result on a build with feature 261.

## Steps

- [ ] Make a case-sensitive folder (`fsutil file setCaseSensitiveInfo <folder> enable`, an empty
      folder) and create `a.txt` and `A.txt` in it. Open it in both panels, focus `A.txt` in the
      left panel, press Ctrl+X → `A.txt` (not `a.txt`) is shown ghosted in both panels.
- [ ] Same folder in the right panel only; in the left panel an ordinary folder with `A.txt`.
      Create a User Menu item with the command `cmd /k echo $(FileToCompareActive) $(FileToCompareInactive)`
      (Arguments, or as the program's argument line), focus `A.txt` in the left panel, run the
      item → the second name is the right panel's `...\A.txt`, not `...\a.txt`.

## Log

- 2026-10-20 — created (source leftover:261)
