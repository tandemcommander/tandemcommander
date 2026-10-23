---
title: The 081 Markdown Viewer probe takes a window with an empty title for the viewer
type: tech-debt
status: open
severity: 1
area: tooling
source: review:314
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: [mdview-page-width-levels]
depends-on: []
reason: -
---

# The 081 Markdown Viewer probe takes a window with an empty title for the viewer

## Problem

Feature 081's `specs/081-mdview-shared-webhost/probe/mdview_probe.ps1` fails its first view of
every session on the hidden desktop: `smoke` passes 1 of 5 checks and `hostile` fails
`01-script-tag.md`, on the HEAD build exactly as on the feature 314 build. So the probe cannot
show that the Markdown Viewer still works after a change (the backlog item
`mdview-page-width-levels` asked for its checks to pass).

## Evidence

- Feature 314 fix-log, *Regression: feature 081 mdview_probe.ps1*:
  `specs/314-mdview-page-width/probe/result_regress081.txt` and `result_regress081_head.txt` -
  `[FAIL] smoke/open: 90 ms, title ''`, then zoom / source / scheme read empty titles;
  `[FAIL] hostile/01-script-tag.md: 3 viewer(s)`.
- `mdview_probe.ps1` `Open-File`: returns the first new window that `Get-AnyViewer` counts, after
  about 80 ms, and reads its title at once. The 314 probe (`pw314_probe.ps1`) reads the full
  viewer title on the hidden desktop in its first view, so the hidden desktop alone does not
  explain it (review of 314): most likely a race in `Open-File` / `Get-AnyViewer` (a window of
  the viewer class that is not yet titled, or another window of that class).

## Expected

- The probe waits for a titled Markdown Viewer window (or identifies the right one) and passes
  `-Scenario smoke` and `hostile` on the hidden desktop with the current build; a deliberately
  broken viewer still fails it (negative control).
- It backs up and restores the product's registry key itself (today the 314 wrapper
  `specs/314-mdview-page-width/probe/regress081.ps1` does it).

## Notes

- The cause is not verified; 081 recorded its 24 checks on a visible desktop.

## Log

- 2026-10-23 — created (source review:314)
- 2026-10-23 — moved to Inbox
- 2026-10-23 — moved to Next
