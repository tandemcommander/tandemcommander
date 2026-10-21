---
title: User Menu from Find results in folders of 260 or more bytes driven by a person
type: person-step
status: new
severity: 4
area: long-paths
source: leftover:280
who: person
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: [user-menu-find-route-person]
depends-on: []
reason: -
---

# User Menu from Find results in folders of 260 or more bytes driven by a person

## Problem

Feature 280 made the Find window's User Menu route hand each result's folder and name whole
(`GetNextItemFromFind`, it cut both at 259 bytes) and refuse an item that does not fit with
"too long name" before anything runs; the names to compare taken from Find results refuse
likewise. The Find window's User Menu is a popup menu: not driven on the hidden desktop - the
route was checked by reading only (two reviews).

## Evidence

`specs/280-user-menu-long-paths/` - `fix-log.md` (section *Review*: "not driven: the Find
route"), `quickstart.md` step 5; `src/finddlg1.cpp` `GetNextItemFromFind` and the Find window's
User Menu handler (compare names) at the merge of feature 280. The panel routes are covered by
`probe/um280_probe.ps1` (30 / 0).

## Expected

The Find route behaves as the panel routes do in the probe.

## Steps

- [ ] Create a folder whose full path has 260 or more bytes (e.g. a folder named with 90 CJK
  letters under `%TEMP%`, entered from its parent) holding `a.txt`, and a short folder holding
  `b.txt`. Find Files over both; select only the result `a.txt` from the long folder; run a User
  Menu item such as `cmd.exe` with arguments `/k echo $(FullName)` - expected: "Cannot finish
  operation because of too long name.", no command window opens.
- [ ] Select both results (`b.txt` from the short folder and `a.txt` from the long one), run the
  same item without "Execute through shell" - expected: the same box, and NO command window for
  `b.txt` either (nothing runs before the refusal).
- [ ] The same with "Execute through shell" on - expected: the same box, nothing runs.
- [ ] Select only `b.txt` and run the item - expected: it runs with the whole name (the control).
- [ ] Select two file results, one of them in the long folder, and run an item that uses
  `$(FileToCompareLeft)` and `$(FileToCompareRight)` - expected: "too long name", no compare dialog.

## Log

- 2026-10-21 — created (source leftover:280)
