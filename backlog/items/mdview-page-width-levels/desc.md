---
title: Markdown Viewer: choose the page width in View, up to the full window
type: improvement
status: open
severity: 3
area: other-plugins
source: manual
who: agent
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Markdown Viewer: choose the page width in View, up to the full window

## Problem

The Markdown viewer (MDView plug-in) shows a document in a centred column of a fixed width
(46rem, about 736 px at the default font, 80-90 characters a line). A wider window only adds
empty margins; wide tables scroll inside the column. A user who wants to read a document with
wide tables, long code lines or diagrams across a wide window cannot widen the column; zoom does
not help (the width is in `rem`, so it scales with the text).

## Evidence

At f6c07c31, by reading:

- `src/plugins/mdview/htmlgen.cpp:610-611`: `.markdown-body{max-width:46rem;...}` and an unused
  `.markdown-body.full{max-width:none;}`; the article is emitted as
  `<article class="markdown-body">` at :698 and :756 - nothing ever adds `full`.
- `src/plugins/mdview/IMPLEMENTATION_NOTES.md:90-91` names a "full-width toggle" that was never
  wired up.
- View menu: `CViewerWindow::BuildMenu`, `src/plugins/mdview/viewer.cpp:457` (scheme submenu,
  Zoom In / Out / Reset, Load Remote Images); checks in `RefreshSchemeChecks` :498; commands
  `CM_VIEW_*` in `src/plugins/mdview/mdview.h:41-48`; dispatch ~:955; a scheme change rebuilds the
  page through `RebuildHtml` :537 / `Regenerate` :570.
- Configuration: `CONFIG_*` names `src/plugins/mdview/mdview.cpp:35-44`, `LoadConfiguration` :154,
  `SaveConfiguration` :180 (`ZoomPercent` is the model for a stored number).

## Expected

- **The current width stays the default**: a user who changes nothing sees exactly today's page.
- View gets a submenu **Page Width** with radio items, the current one checked, e.g.:
  *Normal* (46rem, default), *Wide* (about 64rem), *Wider* (about 90rem), *Full Window* (no limit,
  the padding stays). The exact levels and whether they get keys are decided in the spec.
- Choosing a level applies at once to the open document, keeps the reading position (the same
  heading or scroll fraction - measure what a scheme change does today), and is stored in the
  plug-in's configuration (a new value next to `ZoomPercent`; a missing or unknown value reads as
  *Normal*), so the next document opens with it.
- Tables, code blocks and images use the chosen width (`max-width:100%` of the column as today);
  in *Full Window* a wide table needs no horizontal scroll if the window is wide enough.
- New menu texts in the plug-in's language module for all enabled languages (two-stage `.slt`
  refresh); the manual's MDView page lists the submenu; `IMPLEMENTATION_NOTES.md` no longer
  names an unwired toggle.
- The `mdview_probe.ps1` checks of feature 081 still pass; a probe row per level measures the
  article's rendered width in a wide window.

## Notes

- Decided with the maintainer on 2026-10-22: the current width stays the default; several levels
  including the full window width, chosen from the View menu.
- Plug-in configuration only; no plug-in interface change, no `PRIVACY.md` change (nothing new is
  sent or stored outside the plug-in's existing registry key).
- Related record: feature 081 (`specs/081-mdview-shared-webhost/`), the shared WebView2 host - the
  change stays inside the plug-in's generated HTML and menu, not in `src/common/webhost/`.

## Log

- 2026-10-22 — created (source manual)
- 2026-10-22 — moved to Next position 3
