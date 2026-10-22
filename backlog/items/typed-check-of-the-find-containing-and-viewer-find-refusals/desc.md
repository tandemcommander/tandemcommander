---
title: Typed check of the Find Containing and viewer Find refusals (feature 311)
type: person-step
status: open
severity: 3
area: long-paths
source: leftover:311
who: person
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Typed check of the Find Containing and viewer Find refusals (feature 311)

## Problem

Feature 311 makes Find's Containing field and the viewer's Find field refuse a text whose UTF-8 form
does not fit 200 bytes ("The path specified is too long.") instead of cutting it. The hidden-desktop
probe sets the text by `WM_SETTEXT` and presses buttons by `BM_CLICK`; typing with a real keyboard
(and an IME for CJK) was not driven.

## Evidence

`specs/311-find-containing-cut/fix-log.md` (*Owed to a person*), `quickstart.md` (*By hand*); probe
`specs/311-find-containing-cut/probe/grep311_probe.ps1` (13 rows, 26 PASS / 0 FAIL).

## Expected

The typed text is refused exactly as the probe shows: the message, the field keeps the whole text,
nothing is found and nothing is stored.

## Steps

- [ ] Find (Alt+F7), check "Search file content", type 67 CJK letters (or 101 accented letters such as `é`) into Containing, press Enter: "The path specified is too long.", the field still holds all typed letters, the result list stays empty
- [ ] With the same text: Options > Add Current, Options > Manage, Options > Ignore - each shows the same message and nothing else; the field is unchanged
- [ ] Type 66 CJK letters + one ASCII letter (199 bytes) into Containing, Enter: the search runs, no message
- [ ] Open a text file in the internal viewer (Alt+F3), press F7 (Find), type 67 CJK letters, Enter: the same message, the dialog stays with the whole text

## Log

- 2026-10-22 — created (source leftover:311)
- 2026-10-22 — moved to Person steps position 33
