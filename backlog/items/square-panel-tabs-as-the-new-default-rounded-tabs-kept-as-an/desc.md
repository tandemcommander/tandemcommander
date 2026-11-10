---
title: Square panel tabs as the new default; rounded tabs kept as an Appearance option
type: improvement
status: in-progress
severity: 3
area: panels-ui
source: manual
who: agent
created: 2026-11-10
updated: 2026-11-10
verified: 2026-11-10 75efd1ac
effort: M
feature: 423
related: []
depends-on: []
reason: -
---

# Square panel tabs as the new default; rounded tabs kept as an Appearance option

## Problem

The panel tab strip (feature 404) draws the active tab with rounded top
corners and rounded outward "feet" where it joins the directory line, and
the hover highlight as a rounded pill. The maintainer wants square tabs - a
plain rectangle with no rounding at the top or the bottom (mockup
`evidence/flat_tabs.png`: the active *OneDrive* tab and the *Downloads* tab
are plain rectangles that run straight into the directory line) - as the
new default, and the current rounded look kept as a choice the user can
switch to. There is no setting for the tab look today.

## Evidence

- `src/tabwnd.cpp` at 3723fe2b, `CTabWindow::PaintTabBack` (~918-961): the
  active tab is one nanosvg path with four arcs (left foot, top-left corner,
  top-right corner, right foot) of radius `TABSTRIP_RADIUS` (6.0 at 100 %,
  line 38), filled with `TabPaint.CapBk` by `AAShape`; the hover pill is a
  second path with radius `5 * sc`. `TABSTRIP_LEFT` (8, line 36) reserves
  room for the left foot (`CTabWindow::Layout`, `TabsLeft`, ~214).
- The setting to sit next to: *Options > Configuration > Appearance*, group
  *Icon style* (feature 416) - `src/lang/lang.rc` ~1302-1306 at 3723fe2b
  (`IDC_ICONSET_GROUP` at y 189, height 40, radios `IDC_ICONSET_FLUENT` /
  `IDC_ICONSET_CLASSIC` with owner-drawn previews), data transfer in
  `CCfgPageAppearance` (`src/dialogs5.cpp` ~2980-2984), stored as
  `Toolbar Icon Set` (`CONFIG_TOOLBARICONSET_REG`, `src/mainwnd2.cpp` ~329-344,
  write ~2090, read ~3734 and `src/salamdr1.cpp` ~4426), default in
  `src/dialogs4.cpp` ~282, change detection in `src/mainwnd3.cpp` ~8236 /
  ~8306.
- Mockup from the maintainer: `evidence/flat_tabs.png` (2026-11-10).
- Feature history: `404-panel-tabs-rounded-look` (strip metrics, nanosvg
  shapes, probe traps), `416-fluent-icon-set` (the icon style option),
  `418` (top rebar same layout in both themes).

## Expected

- *Options > Configuration > Appearance* has, below the *Icon style* group, a
  second group (e.g. *Tab style*) with two radio buttons: **Square** (flat;
  the default, also for an upgraded configuration that never stored the
  value) and **Rounded** (the current look of feature 404).
- Square: the active tab is a filled rectangle from the tab's top to the
  bottom of the strip, joining the directory line without feet or arcs; the
  hover highlight is a rectangle too (the mockup shows no hover - a choice
  recorded in the fix-log); separators, icons, title, X and + stay as they
  are. Rounded: pixel-identical to today.
- The choice is stored in the configuration (own value under the
  configuration root, written with the configuration), read at start, and
  applied at once on OK without a restart, in both the Light and the Dark
  theme and at every DPI.
- A hidden-desktop probe checks the painted pixels of both styles (corners of
  the active tab: fill colour in Square, background in Rounded), the default
  of a fresh and of an upgraded configuration, and the round trip of the
  setting.

## Approach

A style flag consulted in `PaintTabBack`: Square fills the tab rectangle
(`TabFillSolid` or a plain rectangle path, no anti-aliasing needed) and the
hover rectangle; Rounded keeps the arcs. Decide whether `TABSTRIP_LEFT`
keeps its foot room in Square (keeping it avoids moving the tabs when the
style changes). The pure part (stored value -> style, default) goes into a
header under `src/common/` with `saltests` checks, like
`SalIconSetFromStored`.

## Notes

- The Appearance page is 231 dialog units tall and the *Icon style* group
  already ends at y 229, so a new group does not fit as it is: the page (or
  the configuration dialog) must grow or the groups be rearranged - check all
  enabled languages for clipped labels.
- New UI strings: the two-stage `.slt` refresh (`translate.merge`,
  `--templates`) is part of the work (CLAUDE.md, rule 084); pin de/fr/nl/es
  if DeepL drifts.
- A separate *Tabs* page exists (`IDD_CFGPAGE_TABS`), but the maintainer
  asked explicitly for the Appearance page under the icon style.
- Changelog entry under the `unreleased` heading.

## Log

- 2026-11-10 — created (source manual)
- 2026-11-10 — moved to Next position 1
- 2026-11-10 — verified at 75efd1ac: still present at 75efd1ac: tabs413_probe THEME capture shows the rounded active tab with feet, no tab-style setting; Light inactive titles 545454 on DEDEDE = 5.63:1
- 2026-11-10 — run started, feature 423
