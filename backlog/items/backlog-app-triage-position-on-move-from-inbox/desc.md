---
title: Backlog app triage: choose the position when moving an item out of the Inbox
type: improvement
status: open
severity: 3
area: tooling
source: manual
who: agent
created: 2026-11-07
updated: 2026-11-07
verified: 2026-11-07 db8da649
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Backlog app triage: choose the position when moving an item out of the Inbox

## Problem

When the maintainer triages the Inbox in the backlog app, an item moved to an ordered section (*Next*, *Decisions for the maintainer*, *Person steps*) cannot be given its position in the same step; it has to be moved again afterwards.

## Evidence

Maintainer request of 2026-11-07. The backlog tool already takes the position in one command (`bin/backlog.sh move <slug> --section next|decisions|person --position <p>`; `decide ... --then move:<Section>@N`), so the limit is in the app's triage interface, not in the tool.

## Expected

The triage of the backlog app lets the maintainer choose the target position (with a sensible default, e.g. the place `auto-triage` would pick by severity) when moving an item from the Inbox to *Next*, *Decisions for the maintainer* or *Person steps*, and applies the move with that position in one change.

## Notes

Not verified which triage controls of `tools/backlog-app/` exist today; the implementing run reads them first. Severity 3: a convenience of a maintainer tool, a workaround exists (move, then reorder).

## Log

- 2026-11-07 — created (source manual)
- 2026-11-07 — moved to Next position 3
- 2026-11-07 — verified at db8da649: triage-page.tsx at db8da649: n takes only the suggested place, d/p and the AI proposal place at the end; no position control
