---
title: SFTP: a recursive Change Attributes gives one mode to files and folders alike
type: decision
status: open
severity: 5
area: sftp
source: leftover:140
who: person
created: 2026-10-14
updated: 2026-10-17
verified: -
effort: -
feature: -
related: []
depends-on: []
reason: -
---

# SFTP: a recursive Change Attributes gives one mode to files and folders alike

## Problem

A recursive Change Attributes on an SFTP server gives one mode to files and directories alike: 644 on a tree makes its directories unusable (no execute bit). Changing it needs interface and texts (e.g. separate modes or an "X" rule for directories).

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L648-650 (left by feature 140, `specs/140-sftp-dead-session/`).

## Expected

(not stated in the source)

## Question

Should the SFTP Change Attributes dialog treat directories differently from files when applied recursively (needs new dialog controls and strings)?

## Options

- A - keep one mode for everything (state now); the user must avoid recursive changes that drop the execute bit.
- B - separate file and directory modes in the dialog.
- C - a rule like chmod's `X` (execute only for directories / already executable files).

## Recommendation

B or C - a recursive 644 that locks the user out of their own directories is a function that harms; C needs the fewest new controls. The source states no preference.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
