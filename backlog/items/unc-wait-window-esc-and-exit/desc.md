---
title: UNC "Checking path" wait window: real Esc / Close, then an immediate exit
type: person-step
status: open
severity: 3
area: panels-ui
source: leftover:125
who: person
created: 2026-10-13
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# UNC "Checking path" wait window: real Esc / Close, then an immediate exit

## Problem

Rows of feature 125 that read the real keyboard and mouse; written for the visible desktop and not driven (the workstation was locked during the second verification).

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L846-847, L857-861, L866-867. Commands in the *Second verification* section of `specs/125-unc-server-shares/fix-log.md`; `probe/unc_probe.ps1 -Only W2`; locked-desktop result `probe/unc_result_visible_desktop_locked.txt`.

## Expected

Esc and Close end the wait; the program ends at once without a hang (a Debug build may report a leak).

## Steps

- [ ] Esc in the "Checking path" wait window while a server is being read
- [ ] The Close button of the same wait window
- [ ] `unc_probe.ps1 -Only W2` unlocked, or by hand: Esc in the wait window on a server that does not answer (`\\10.255.255.1\`), then exit at once - the program ends without a hang

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
