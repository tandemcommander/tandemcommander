---
title: Delete the review scratch folder rev399scratch_eB on drive E
type: person-step
status: new
severity: 1
area: tooling
source: leftover:399
who: person
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Delete the review scratch folder rev399scratch_eB on drive E

## Problem

The independent reviewer of feature 399 tested a symbolic link from C: to another volume and left
the scratch folder `E:\rev399scratch_eB` (one 4-byte file `y.zip`, a test fixture, nothing of the
user's) at the root of drive E. The run's sandbox refused to delete it (a protected path). The
reviewer's other scratch folder `%TEMP%\rev399` (probe copy, logs, a test program) may also be removed.

## Evidence

`specs/399-zip-symlink-archive/fix-log.md`, *Review*, review 1 (its clean-up paragraph); checked on
2026-11-02: `E:\rev399scratch_eB` holds only `y.zip`, 4 bytes.

## Expected

The folder is gone; nothing else changes.

## Steps

- [ ] Look into `E:\rev399scratch_eB`: it holds only `y.zip` (4 bytes) - then delete the folder.
- [ ] Optionally delete `%TEMP%\rev399` (the reviewer's probe copy and logs).

## Log

- 2026-11-02 — created (source leftover:399)
