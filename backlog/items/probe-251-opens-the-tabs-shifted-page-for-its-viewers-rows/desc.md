---
title: Probe 251 opens the Tabs-shifted page for its Viewers rows (page index 19)
type: tech-debt
status: open
severity: 2
area: tooling
source: measure:389
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Probe 251 opens the Tabs-shifted page for its Viewers rows (page index 19)

## Problem

The regression probe of feature 251 (`specs/251-dialog-text-fits/probe/dlg251_probe.ps1`) opens
the Configuration dialog for its rows `vw-cmd` and `vw-ctl` by seeding `Last Focused Page` = 19.
Since feature 312 added the Tabs page, index 19 is the "Viewers and Editors" parent page ("Please
select a subentry from the list"), so both rows fail with `list 584 not found` and the program is
ended by the probe ("did not exit in 30 s") - 4 FAIL rows that are not a product defect. Later
features that run 251's probe as a regression see 38 / 4 instead of 42 / 0 and must re-check by
hand.

## Evidence

- Feature 389 run, build of branch `389-compare-icon-fits` (based on df4d92be):
  `specs/389-compare-icon-fits/probe/regress_251.txt` - Rows: PASS 38, FAIL 4; `vw-cmd ERROR FAIL
  list 584 not found`, `vw-ctl ERROR FAIL list 584 not found`, the stray window `[#32770
  'Configuration'] ... Viewers and Editors | Please select a subentry from the list`.
- The same probe with `'Last Focused Page' 20` (a scratchpad copy, only `vw-cmd,vw-ctl`):
  `specs/389-compare-icon-fits/probe/regress_251_viewers_page20.txt` - Rows: PASS 4, FAIL 0.
- `dlg251_probe.ps1` lines 261 and 268 (`$Cases['vw-cmd']`, `$Cases['vw-ctl']`) at df4d92be.
- Feature 312 commit 392d0036 "the Tabs page" changed `src/dialogs4.cpp` (the page tree).

## Expected

The probe reaches the Viewers page whatever the number of pages before it - e.g. it finds the page
by its tree item text or by the list control 584 after selecting the "Viewers" subentry - and runs
42 / 0 on the current build. Other probes that seed `Last Focused Page` with an index (291's
`$SystemPage` = 3 still works) are checked for the same drift.

## Notes

Not verified: which other probes seed a page index beyond the Tabs page.

## Log

- 2026-11-02 — created (source measure:389)
- 2026-11-02 — moved to Next position 136
