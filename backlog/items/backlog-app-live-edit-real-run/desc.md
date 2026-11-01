---
title: Backlog app: the first real run with a change made during it (feature 371)
type: person-step
status: open
severity: 4
area: tooling
source: leftover:371
who: person
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: -
feature: -
related: []
depends-on: []
reason: -
---

# Backlog app: the first real run with a change made during it (feature 371)

## Problem

Feature 371 was verified with the fake claude only (e2e branch-hang runs, the soak). The real implement skill's step 9 (bin/backlog-loop.sh returning, the backlog recipe after a moved main) has not yet run with the app changing main during a real run.

## Evidence

specs/371-backlog-app-live-editing/closing-report.md; e2e us1-live-edit.spec.ts; the skill's step 9 edited in .claude/skills/tandem-backlog-implement/SKILL.md.

## Expected

A real run ends closed after the maintainer added an item at Next #1 and reordered Next while it ran; main holds both; the loop's next run takes the new item.

## Steps

- [ ] start the loop from the app on the real repository, let a run reach its branch (the banner says 'A run is in progress')
- [ ] add an item placed at Next #1 and move another row; check `git log main -3` shows backlog(app) commits and the run's status is unchanged
- [ ] wait for the run's end; its trace shows `bin/backlog-loop.sh returning` then the merge recipe; main holds the close and the order
- [ ] the loop's next run takes the item that is first in Next

## Log

- 2026-11-01 — created (source leftover:371)
- 2026-11-01 — moved to Person steps position 85
