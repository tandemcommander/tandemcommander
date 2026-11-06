---
title: CLAUDE.md names a branch ai-main that does not exist
type: tech-debt
status: parked
severity: 1
area: help-docs
source: measure:242
who: both
created: 2026-10-17
updated: 2026-11-06
verified: 2026-10-17 7993914c
effort: S
feature: -
related: []
depends-on: []
reason: minor finding (severity 1) parked in the one-time cleanup of Next; reopen when it bothers a user or the area is worked on; maintainer 2026-11-06
---

# CLAUDE.md names a branch ai-main that does not exist

## Problem

`CLAUDE.md` (Build, last bullet) says `main` = stable, `ai-main` = AI-assisted development. No branch `ai-main` exists locally; features are branched from `main` and fast-forwarded into it (and autonomous runs of feature 242 work the same way).

## Evidence

`git branch --list ai-main` empty on 2026-10-17 at 7993914c (feature 242, fix-log *Measurements*).

## Expected

`CLAUDE.md` and `architecture/12-project-reference.md` describe the branches as they are used, after the maintainer says whether `ai-main` exists on origin or should.

## Approach

Ask the maintainer (or check `git ls-remote origin`), then correct the line.

## Log

- 2026-10-17 — migrated from the consolidation of the migration parts (feature 242)
- 2026-11-06 — moved to Parked: minor finding (severity 1) parked in the one-time cleanup of Next; reopen when it bothers a user or the area is worked on; maintainer 2026-11-06
