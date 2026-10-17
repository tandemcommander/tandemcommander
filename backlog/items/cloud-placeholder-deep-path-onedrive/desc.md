---
title: Delete of a cloud placeholder past 780 characters (OneDrive)
type: person-step
status: open
severity: 3
area: data-safety
source: leftover:219
who: person
created: 2026-10-15
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Delete of a cloud placeholder past 780 characters (OneDrive)

## Problem

Feature 219 drove 197's rows (directory symbolic links in deep folders, the Recycle Bin by masks with junctions); left: a cloud placeholder past 780 characters - owed to a person with OneDrive.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L798-801. Features 197, 219 (`specs/219-deep-link-delete-rows/`, `deeplink219_probe.ps1`).

## Expected

Deleting a deep folder holding a OneDrive placeholder (path past 780 characters) removes only what was selected; the cloud copy is not affected beyond OneDrive's own rules.

## Steps

- [ ] With OneDrive: a cloud placeholder in a folder past 780 characters - F8 on the deep folder, check what was removed locally and in the cloud

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
