---
title: CLAUDE.md names a branch ai-main that does not exist
type: tech-debt
status: open
severity: 1
area: help-docs
source: measure:242
who: both
created: 2026-10-17
updated: 2026-10-17
verified: 2026-10-17 7993914c
effort: S
feature: -
related: []
depends-on: []
reason: -
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
