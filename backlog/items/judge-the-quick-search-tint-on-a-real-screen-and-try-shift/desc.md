---
title: Judge the quick-search tint on a real screen and try Shift and Alt keys
type: person-step
status: new
severity: 4
area: panels-ui
source: leftover:244
who: person
created: 2026-10-18
updated: 2026-10-18
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Judge the quick-search tint on a real screen and try Shift and Alt keys

## Problem

Feature 244 tints a panel while quick search filters it and shows the search text in its directory line. Whether the tint is light but recognisable can only be judged on a real screen. The hidden desktop of the probes has no real key state, so Shift+arrows and Alt+letter during a search were not driven.

## Evidence

- `specs/244-quick-search-substring-filter/probe/captures_contact_sheet.png` shows idle and searching panels in 5 view modes x 4 colour schemes + Dark (`qs244_capture.ps1`).
- `specs/244-quick-search-substring-filter/closing-report.md`, *Not driven / owed to a person*.
- Spec SC-006, FR-012.

## Expected

The maintainer confirms or corrects the colours (the rule is `SalQFTint` in `src/common/salquickfilter.h`), and the keys behave as listed below.


## Steps

- [ ] In each scheme (Configuration > Colors: Salamander, Explorer, Norton Commander, Navigator) and in the Dark theme, type a few letters in a panel: the panel is lightly but recognisably tinted, the text, the cursor and selected items are readable, and the directory line shows `Search: <text> (<n> of <total>)`.
- [ ] Shift+Down during a search selects the focused match and moves to the next one; Esc shows all items and the selected ones stay selected.
- [ ] With Configuration > Panels > *Redirect typing from panel to Command line* checked, Alt+c, Alt+h start a filtered search (plain typing goes to the command line).
- [ ] Configuration > Panels > *Quick search finds text anywhere in names and shows only the matches* cleared: typing behaves as in 0.1.10 (only names starting with the text, nothing hidden, no tint).

## Log

- 2026-10-18 — created (source leftover:244)
