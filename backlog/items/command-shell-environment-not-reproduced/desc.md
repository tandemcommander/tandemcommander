---
title: A program started from the panel fails, from Explorer works (not reproduced)
type: bug
status: parked
severity: 4
area: panels-ui
source: leftover:073
who: both
created: 2026-08-31
updated: 2026-10-17
verified: -
effort: ?
feature: -
related: []
depends-on: []
reason: parked as not reproduced (decision of 2026-08-31, `specs/073-fix-cmdshell-env/spec.md` Clarifications); no product change until `evidence/capture.cmd` captures a live occurrence.
---

# A program started from the panel fails, from Explorer works (not reproduced)

## Problem

After the update to 0.1.7 a user's `npm run dev` failed ("Required model files not found") when started from a Command Shell opened with `Num /`, or from a `.bat` started by Enter in a panel, while the same file started from Explorer worked. The suspected cause was the environment Tandem Commander hands its child processes (`USERPROFILE`); later the same day the failure no longer reproduced.

## Evidence

`specs/073-fix-cmdshell-env/spec.md` (Background, Clarifications), `plan.md` (shelf design; reproduction evidence NOT MET), `research.md`, `evidence/capture.cmd` (one-click capture for the next occurrence). Migrated from specs/NEXT-WORK.md *Recorded, deliberately not on the list* (L2217, at 7993914c).

## Expected

(not stated in the source)

## Approach

Run `evidence/capture.cmd` while the failure is live; the shelf design in `plan.md` applies only once the capture names the cause.

## Notes

Severity 4 assumes the original report (a function failing, workaround: start from Explorer); unconfirmed.

## Log

- 2026-08-31 — parked as not reproduced (073 spec Clarifications)
- 2026-10-17 — migrated from specs/NEXT-WORK.md §C and 'Recorded, deliberately not on the list' (feature 242)
