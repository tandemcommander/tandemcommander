---
title: Find window: the viewer next / previous file takes the first case-insensitive twin
type: bug
status: new
severity: 3
area: panels-ui
source: measure:261
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

# Find window: the viewer next / previous file takes the first case-insensitive twin

## Problem

A user views a file found by Find (the viewer opened from the Find window's result list) and steps
to the next / previous file. When the list holds two results that differ only in case (a.txt and
A.txt of a case-sensitive folder) and the list shifted (a new search result was added before the
viewed one), the viewer continues from the first result equal ignoring case - possibly the other
twin. Feature 261 fixed the same lookup for the panel (`fileswnb.cpp`); the Find window's copy was
not named by the item.

## Evidence

By reading at 0e151c5a (branch 261-case-twins-exact-match): `src/finddlg1.cpp`, the
WM_USER_ENUMFILENAMES handling (~990-1015): the name at the remembered index is accepted with
`SalNameEqualOrdinalCI(fileName, -1, FileNamesEnumData.LastFileName, -1)` and the search for a new
index breaks at the first `SalNameEqualOrdinalCI` match. The full name is built with
`lstrcpyn(fileName, f->Path, MAX_PATH); SalPathAppend(fileName, f->Name, MAX_PATH)` - a path over
MAX_PATH is cut (CLAUDE.md: a path is never cut). Panel fix and rule: feature 261
(`src/common/salnamerun.h` `SalNamePickIndex`, `specs/261-case-twins-exact-match/fix-log.md`).

## Expected

The Find window's next / previous file takes the byte-identical result, else the only result equal
ignoring case, never one of two (`SalNamePickIndex` over the full names); full names are built in a
heap / `SAL_MAX_PATH_UTF8` buffer, not cut at MAX_PATH. A probe in the style of
`specs/261-case-twins-exact-match/probe/twin261_probe.ps1` (VIEWNEXT / VIEWPREV) driven from Find.

## Notes

The MAX_PATH part may overlap `user-menu-long-paths` (which names `GetNextItemFromFind` in the same
file, not this handler).

## Log

- 2026-10-20 — created (source measure:261)
- 2026-10-20 — related item case-sensitive-twins-first-match done in feature 261
