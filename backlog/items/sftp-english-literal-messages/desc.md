---
title: SFTP: questions and reasons are untranslated English literals
type: tech-debt
status: open
severity: 2
area: sftp
source: review:139
who: agent
created: 2026-10-14
updated: 2026-10-17
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# SFTP: questions and reasons are untranslated English literals

## Problem

The questions and reasons added by features 131 and 139 to the SFTP plug-in are English literals (no new strings were added), so Czech and other users see English sentences there.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L660 and L667-669. Features 131 (`specs/131-plugin-defect-batch/fix-log.md`, section 6), 139.

## Expected

The SFTP texts come from the language module and are translated in the eight shipped languages.

## Approach

New strings need the two-stage `.slt` refresh (`translate.merge --templates`, rule 084); use free slots in an existing bundle.

## Notes

L668-669 says "untranslated English literals stay" after 139 - possibly an accepted state rather than a task; the maintainer may park it.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
