---
title: Closing for an update: four limitations accepted by feature 080
type: improvement
status: rejected
severity: 2
area: plugin-api
source: leftover:080
who: agent
created: 2026-09-20
updated: 2026-10-17
verified: -
effort: -
feature: -
related: []
depends-on: []
reason: Accepted as known limitations by feature 080 (REMAINING-WORK.md P3, 2026-09-20): each needs an extreme case (a plug-in `Release()` hanging for half a minute), is what a forced close asks for, concerns only the first update from 0.1.7, or is the single `WM_CLOSE` the Restart Manager itself sends. Re-open only with a new reason.
---

# Closing for an update: four limitations accepted by feature 080

## Problem

(1) An execute stage that outlives the requester's 30 s is not stopped: the installer reports failure while the program still closes, and nothing starts it again (measured closes take 1.2-1.4 s; a plug-in whose `Release()` hangs for half a minute would be needed). (2) A forced close (`/FORCECLOSEAPPLICATIONS`) of a program that declined ends in the Restart Manager killing it after 30 s - without saving the configuration (before 080 the same situation also showed a *forced shutdown* box). (3) The first update from 0.1.7 does not bring the program back: the restart registration lives in the old process and 0.1.7 never registered (moot for updates from 0.1.8 on). (4) One genuine `WM_CLOSE` within 35 s after an installer's instruction is ignored (the Restart Manager sends one of its own, which must not start the interactive exit); a second Alt+F4 works.

## Evidence

specs/080-restart-manager-upgrade/REMAINING-WORK.md section P3 *Known limitations, accepted* (L80-94); closing record specs/080-restart-manager-upgrade/closing-report.md. Not in specs/NEXT-WORK.md at 7993914c.

## Expected

(not stated in the source)

## Notes

Related decided entry: `update-close-declining-windows-kept` (NEXT-WORK section C "Update close", 118/121).

## Log

- 2026-09-20 — feature 080: the four limitations accepted (REMAINING-WORK P3)
- 2026-10-17 — migrated from specs/*/REMAINING-WORK.md (feature 242)
- 2026-10-17 — migration review N3: cross-reference to the final slug
