---
title: Dark theme: panel tabs look lower than in the default theme
type: bug
status: open
severity: 3
area: panels-ui
source: manual
who: agent
created: 2026-11-07
updated: 2026-11-07
verified: 2026-11-07 f574e83e
effort: M
feature: -
related: [manual-checks-owed-before-the-next-release]
depends-on: []
reason: -
---

# Dark theme: panel tabs look lower than in the default theme

## Problem

The maintainer (2026-11-07, screenshots `temp/tab_heights/light.png`, `dark.png`, `dark_vs_light_tab_height.png`,
gitignored): in the Dark theme the panel tabs look lower than in the default (light) theme - "the space above and
below the text of the tab title is smaller, and so the whole tab is smaller". It must be the same in both themes.

Feature 413 already met "the Dark tab strip looks lower" and found the strip, the directory line and the tab's rows
equal; it fixed the contrast of the inactive panel's active tab and recorded as a limit: "the dark rebar (69 vs 77 px,
bands without borders) is unchanged". The maintainer still sees the difference (on a build with 413: the Dark
inactive panel's active tab has 413's lifted fill 454545).

## Evidence

Measured on the maintainer's screenshots (1716 x 1132, 96 DPI, same window, Default vs Dark), column x = 1000 and
the right panel's active tab "tandemcommander":

| Rows | Default | Dark |
|---|---|---|
| title bar | 1-30 | 1-30 |
| rebar: menu / top toolbar / drive bar | 31-107 = 77 px: bands 23 + 24 + 22 and 4 etched lines of 2 px (160 / 255) at 31-32, 56-57, 82-83, **106-107** | 31-99 = 69 px: the same bands, no lines |
| panel tab strip | 108-136 = 29 px (strip 222 on face 240) | 100-128 = 29 px (strip 36 on face 45) |
| active tab fill | 111-136 (26 rows) | 103-128 (26 rows) |
| title text / icon | 119-127 / 117-129 (11 px below the strip top, 9 above its bottom) | 111-119 / 109-121 (11 / 9) |
| gap, directory-line border | 137-138 (240), 139 (160) | 129-130 (45), 131 (16) |

- The tab strip and the tabs are **pixel-for-pixel the same size**. The visible difference is above the strip: the
  Default theme frames it with the rebar's etched line (2 px, rows 106-107), so from the visible top edge to the
  title there are 13 px; in Dark the rebar has no line and the strip (36) hardly differs from the face (45), so the
  strip's top edge is the visible one: 11 px. Below the title both have 11 px to the directory line's border.
- The lines come from the rebar's style: `HTopRebar` is created with `WS_BORDER | RBS_BANDBORDERS`
  (`src/mainwnd3.cpp`, `CreateWindowEx(WS_EX_TOOLWINDOW, REBARCLASSNAME`), and `ThemeUpdateRebarStyle`
  (`src/themes.cpp`) removes both in the Dark theme.
- Not yet measured on the live build at other display scales (125-200 %) - the run measures that.

## Expected

- In the Dark theme the panel tabs look exactly as tall as in the default theme: the same space above and below the
  tab title, measured from the visible edges that frame the tab strip, at 100 % and the other common scales.
- The default theme's look is unchanged (pixel-identical).
- Evidence: a hidden-desktop probe measures the rows of the rebar bottom, the tab strip, the tab, its title and the
  directory line in both themes (before / after), and a negative control.

## Approach

Measure first on the live build (both themes, 100 % and if possible another scale) and find what the eye compares.
Likely fix: give the Dark theme the same 2-px divider between the rebar and the panels that the default theme's
rebar border draws (in the Dark palette's shadow / highlight colours, as `ThemeDrawEdge` does for etched edges), so
the strip is framed the same way; keep the Dark bands themselves borderless only if the measurement shows the band
lines are not what the eye compares. Do not change the tab strip's own size (it is already equal).

## Notes

- Maintainer's decision in the conversation (2026-11-07): the tabs must look the same in both themes - this
  overrides 413's limit "the dark rebar ... unchanged" for what the measurement shows is needed.
- Related: 413 (`specs/413-tab-drag-first-place/`), 404 (rounded tabs), 028 (dark theme, rebar without borders).

## Log

- 2026-11-07 — created (source manual)
- 2026-11-07 — moved to Next position 1
- 2026-11-07 — verified at f574e83e: still present at f574e83e: live build on the hidden desktop - strip 29 px and tab rows equal; Default frames the strip with the rebar etched border (77 px rebar), Dark has none (69 px)
