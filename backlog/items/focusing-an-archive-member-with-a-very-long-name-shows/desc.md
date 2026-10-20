---
title: Focusing an archive member with a very long name shows "Expanded string is too large." twice
type: bug
status: open
severity: 4
area: panels-ui
source: measure:260
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Focusing an archive member with a very long name shows "Expanded string is too large." twice

## Problem

When the cursor in a panel lands on an archive member with a very long name (200 CJK letters + ".txt", 604 bytes of UTF-8 - a valid Windows name), an error box "Expanded string is too large." appears twice. The panel's information line cannot show the item; the user has to dismiss two boxes for one key press.

## Evidence

At aec864cf: probe `specs/260-archive-cache-long-names/probe/cache260_probe.ps1` row ARCCAP (`probe/result_after.txt`: "after: [#32770 'Error'] ... Expanded string is too large. ... Expanded string is too large."), reproduced by review 1 and review 2 of feature 260. The text is IDS_EXP_SMALLBUFFER, raised by the information-line expansion in `src/salamdr2.cpp` (`ExpandInfoLineItems`, ~1107 / 1145 / 1167); `CFilesWindow::ItemFocused` (`src/fileswn2.cpp` ~1224) expands into `char buff[1000]`. Suspected cause, not confirmed. The feature-260 before-run's GZLONG row (a 259-byte name cut inside a letter, decoded as code-page text) shows the same box. Not checked for long disk names.

## Expected

Focusing an item with any name the panel lists shows no error box; the information line shows the name, shortened at a whole letter for display if it does not fit (a display text, not a name used for an operation).

## Log

- 2026-10-20 — created (source measure:260)
- 2026-10-20 — moved to Next position 14
