---
title: Should the program come back after a reboot or sign-in (RESTART_NO_REBOOT)?
type: decision
status: open
severity: 1
area: plugin-api
source: leftover:080
who: person
created: 2026-09-20
updated: 2026-10-17
verified: 2026-10-17 7993914c
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Should the program come back after a reboot or sign-in (RESTART_NO_REBOOT)?

## Problem

Feature 080 registers the program for a restart after an installer's update (`RegisterApplicationRestart`) but excludes the restart after a reboot or sign-out with `RESTART_NO_REBOOT` (080 spec, *Assumptions*). Removing the flag is a one-word change and a product decision.

## Evidence

specs/080-restart-manager-upgrade/REMAINING-WORK.md section P4 (L96-101). At 7993914c: src/mainwnd3.cpp:619 `RegisterApplicationRestart(cmdLine, RESTART_NO_CRASH | RESTART_NO_HANG | RESTART_NO_REBOOT)`. Not in specs/NEXT-WORK.md at 7993914c.

## Expected

(not stated in the source)

## Notes

Verifying option B needs a real reboot and a sign-out with Windows' "restart apps after signing in" enabled - a person step.

## Question

Should Tandem Commander reappear after a reboot or at sign-in for users who enabled Windows' "restart apps after signing in", like other registered programs?

## Options

- A - keep `RESTART_NO_REBOOT` (today): the restart registration serves updates only; nothing reappears at sign-in.
- B - remove the flag: the program comes back after a reboot / sign-in when the user enabled the Windows option; costs: unrelated to updates, makes the program reappear at sign-in, can be verified only with a real reboot.

## Recommendation

A - the 080 spec's assumption; revisit only if users ask for it.

## Log

- 2026-09-20 — feature 080: excluded with RESTART_NO_REBOOT (spec Assumptions)
- 2026-10-17 — migrated from specs/*/REMAINING-WORK.md (feature 242)
