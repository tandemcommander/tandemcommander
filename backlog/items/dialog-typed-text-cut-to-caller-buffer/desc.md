---
title: Typed text cut to the caller's buffer: Make File List, user menu, viewers
type: bug
status: open
severity: 6
area: long-paths
source: review:214
who: agent
created: 2026-10-15
updated: 2026-10-20
verified: 2026-10-20 c7f07bc6
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Typed text cut to the caller's buffer: Make File List, user menu, viewers

## Problem

Left by the review of feature 214 (`CCopyMoveDialog::Transfer` cut typed text that did not fit the caller's buffer) - the same cut elsewhere, to fix one by one: Make File List's output file `dialogs.cpp` 1270 / 1950 and its line 1914 / 1931 (a cut name is written or appended to); the drive's "go to" path `dialogs5.cpp:1884`; the user menu `dialogs4.cpp:2215-2217` and viewers / editors `dialogs5.cpp` 2125-2127, 2507-2509 (a cut command runs another program); the hot path editor's `GetDlgItemText` fallback `dialogs4.cpp:2924-2926` (code page). Low risk: Edit New's default `dialogs3.cpp:600`, the browse-from-field cuts `salamdr3.cpp:4349`, `dialogs5.cpp:1923`, `dialogs2.cpp:1287`.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L675-684. Feature 214 (`specs/214-copy-dialog-text-fits/`, `cm_text_probe.ps1`; 214 measured F5 out of a ZIP unpacking into the typed folder's parent).

## Expected

Each listed field measures the whole text and refuses with `IDS_TOOLONGPATH` (as 214's `Validate`) instead of cutting; no cut name is written to and no cut command is run.

## Notes

Severity 6: a cut Make File List name writes or appends to another file, and a cut command runs another program; not measured per site.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-20 — verified at c7f07bc6: reproduced at c7f07bc6 by a hidden-desktop probe: Make File List wrote a cut file name and line, user menu / viewers / editors / drives stored cut text, hot path stored ?, Edit New default cut, drives browse started from a cut path
