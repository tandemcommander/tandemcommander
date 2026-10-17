---
title: GitHub housekeeping: real run of the Node 24 workflows, vulnerability reporting
type: person-step
status: open
severity: 3
area: build-release
source: leftover:091
who: person
created: 2026-10-01
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# GitHub housekeeping: real run of the Node 24 workflows, vulnerability reporting

## Problem

Feature 091 bumped all four GitHub workflows off the deprecated Node 20 actions with static verification only - a real run is owed. Feature 083 (privacy statement) left two repository settings to the maintainer: enabling GitHub private vulnerability reporting and the second contact line of PRIVACY.md.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'Release and catalogue housekeeping' ('a real run of the Node 24 workflows (091); GitHub private vulnerability reporting and the second PRIVACY.md contact line (083)') and §6 P4 (~line 2028) (at 7993914c). Records: specs/091-workflow-actions-node/fix-log.md; feature 083's records (specs/083-privacy-policy-winget/).

## Expected

Each workflow has run green once on GitHub; private vulnerability reporting is enabled and PRIVACY.md's second contact line states it (or the line is dropped by the maintainer's decision).

## Notes

PRIVACY.md is a public claim referenced by winget - change it in the same change as the setting. Never add a step to pr-comments-guard.yml that runs code from the checkout (decided 2026-10-02, opt-in allow-unsafe-pr-checkout).

## Steps

- [ ] Run each of the four workflows once on GitHub (a real run after the Node 24 bump of 091)
- [ ] Enable GitHub private vulnerability reporting on the repository
- [ ] Settle the second contact line of PRIVACY.md (083)

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
