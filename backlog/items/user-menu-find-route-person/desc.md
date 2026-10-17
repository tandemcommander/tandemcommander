---
title: User Menu from the Find window driven by a person
type: person-step
status: open
severity: 2
area: panels-ui
source: leftover:234
who: person
created: 2026-10-16
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# User Menu from the Find window driven by a person

## Problem

Feature 234 gave the Find window's User Menu route the item's folder; the Find route was NOT DRIVEN (a popup menu), and 235's full-name `$(ListOfSelectedNames)` from several Find folders was done by reading.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L728-732. `specs/234-user-menu-item-folder/`, `specs/235-find-list-of-names-folders/`.

## Expected

A User Menu item run from Find results runs in each item's folder; `$(ListOfSelectedNames)` from several folders gives full names.

## Steps

- [ ] Find results in two folders, a User Menu item without an Initial Directory - it runs in the item's folder (234)
- [ ] `$(ListOfSelectedNames)` over results from several folders - full names, nothing run on other files (235)

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
