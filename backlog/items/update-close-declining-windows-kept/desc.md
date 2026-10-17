---
title: Installer update close: some plug-in windows and every dialog still decline
type: improvement
status: rejected
severity: 2
area: plugin-api
source: leftover:118
who: agent
created: 2026-10-06
updated: 2026-10-17
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: features 118 and 121, 2026-10-06 (listed under NEXT-WORK §C Decided - not to do): a window that holds something the user would lose declines - the Batch Renamer always (masks, Undo), a Checksum Calculate window until every calculated type is saved; dialogs and message boxes always decline, including FTP's Logs / Welcome *Save* dialogs.
---

# Installer update close: some plug-in windows and every dialog still decline

## Problem

When an installer asks the running program to close for an update, the Batch Renamer window always declines; a Checksum Calculate window declines until every hash type it calculated is saved; dialogs and message boxes always decline - including the *Save* dialogs of FTP's Logs and Welcome Message windows (the windows themselves were declared by 121).

## Evidence

specs/NEXT-WORK.md item 4 note on 118 (L1155-1166 at 7993914c); `specs/118-plugin-update-close/research.md` R6, `quickstart.md` (GUI-verified 58 / 0); `specs/121-small-batch/fix-log.md` (rows R1 / L1). Migrated from specs/NEXT-WORK.md §C *Decided - not to do* (L484, at 7993914c).

## Expected

(not stated in the source)

## Log

- 2026-10-06 — feature 118 GUI-verified (58 / 0): Batch Renamer always declines, Checksum Calculate until saved; feature 121 declared RegEdit's Find and FTP's Logs / Welcome windows, their Save dialogs still decline
- 2026-10-17 — migrated from specs/NEXT-WORK.md §C and 'Recorded, deliberately not on the list' (feature 242)
