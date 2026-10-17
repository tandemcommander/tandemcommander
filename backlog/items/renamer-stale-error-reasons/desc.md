---
title: Renamer: two error messages still append a stale system reason
type: bug
status: open
severity: 2
area: other-plugins
source: leftover:131
who: agent
created: 2026-10-13
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Renamer: two error messages still append a stale system reason

## Problem

Feature 131 fixed `FileError` appending a stale `GetLastError()` text to logical errors; two stale reasons remain at `rendlg.cpp:1344` and `rendlg3.cpp:301` (e.g. a `WriteFile` that writes fewer bytes without an error leaves a stale last error).

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L777. `specs/131-plugin-defect-batch/items/renamer.md` (row 22, "not sure"), `fix-log.md` section 6.

## Expected

Renamer messages at the two sites show a reason only when the failing call set one.

## Notes

Features 207-210 changed the Renamer since; line numbers may have moved - verify the two sites first.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
