---
title: The manual has no page for the Markdown Viewer
type: improvement
status: open
severity: 2
area: help-docs
source: measure:314
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# The manual has no page for the Markdown Viewer

## Problem

The manual (`help/src/hh/`) has no page for the Markdown Viewer plug-in: its menus (File, Edit,
View - Color Scheme, Page Width, zoom, Load Remote Images), keys (Ctrl+U, Ctrl+F, F3, F9, Esc),
the remote-image consent and the Configuration option *Keep the rendering engine ready* are not
described anywhere a user can look them up. The backlog item `mdview-page-width-levels` asked
that "the manual's MDView page lists the submenu" - there was no page to extend.

## Evidence

At 67d1e782: `grep -rli markdown help/src` lists only
`help/src/hh/salamand/configuration_gener.htm` (one sentence naming the viewer among viewer
windows) and `introduction_news.htm`. Feature 314 fix-log, *Measured at da0a455a*.

## Expected

- A manual page for the Markdown Viewer in the style of the other plug-in pages, linked from the
  plug-in list / table of contents: what it opens, the menus with their keys (View > Page Width:
  Normal, Wide, Wider, Full Window - feature 314), remote images only after consent, links
  (what opens, what is refused), the configuration option.
- The help build stays clean.

## Notes

- How the other plug-ins' pages are organised and linked was not checked here.

## Log

- 2026-10-23 — created (source measure:314)
- 2026-10-23 — moved to Inbox
- 2026-10-23 — moved to Next position 119
- 2026-10-23 — related item mdview-page-width-levels done in feature 314
