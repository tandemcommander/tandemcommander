---
title: Manual checks owed before the next release
type: person-step
status: open
severity: 5
area: build-release
source: manual
who: person
created: 2026-11-06
updated: 2026-11-06
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Manual checks owed before the next release

## Problem

Autonomous runs leave checks only a person can do: a real keyboard, mouse, clipboard or IME, another machine, admin rights, the look on a real screen. Until 2026-11-06 each such check became a `person-step` item of its own, and they piled up (97 of 99 *Person steps* items came from features' leftovers). From now on, every run appends its checks to this **one** checklist instead, and the maintainer works through it before a release.

## Evidence

The maintainer's rule of 2026-11-06 is recorded in:
- `/tandem-backlog-implement` `stop-rules.md` rule 9 (runs append lines here) and rule 11 (findings of severity 5 or less are fixed inside the feature);
- the exception in `/tandem-backlog` `SKILL.md` §0.3 (a run may only append lines, never change or remove them);
- `CLAUDE.md` *Working method*.

The *Person steps* items recorded before that day stay where they are.

## Expected

Before the release, every line below is ticked (`BL step <slug> <n> --done`). Or its failure has become an *Inbox* item named in the line's note. Then the maintainer closes this item. The first run after the release opens a new checklist.

## Steps

- [ ] Before the release: work through every unticked line below; each names the feature it comes from and the expected result

## Log

- 2026-11-06 — created (source manual)
- 2026-11-06 — body written: the release checklist runs append to (maintainer rule 2026-11-06)
- 2026-11-06 — moved to Person steps position 1
