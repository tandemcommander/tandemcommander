---
title: Panel tabs: a drag cannot put a tab in the first place; dark strip looks lower
type: bug
status: open
severity: 5
area: panels-ui
source: manual
who: agent
created: 2026-11-07
updated: 2026-11-07
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Panel tabs: a drag cannot put a tab in the first place; dark strip looks lower

## Problem

Two defects of the variant F tab strip (feature 404), found by the maintainer while trying it:

1. **A tab cannot be dragged to the first (leftmost) place**, in the left and in the right panel alike. The dragged tab stops at the left end of the strip and lands in the second place. The only exception is the tab that already is first: it can be dragged away and back to the first place while the button is held.
2. **In the dark theme the tabs look lower than in the default theme.** The maintainer's rule: the tab height must be the same in both themes.

## Evidence

Code at `aca5c5d3`.

**Defect 1 - confirmed in the code.**

- `src/common/saltabs.cpp:496` `SalTabDragSlot`: moving left, `slot = cell + 1` (line 512) with `cell = floor(draggedLeft / tabWidth)`; slot 0 needs `draggedLeft < 0`.
- `src/tabwnd.cpp:546-549` `CTabWindow::UpdateDrag` clamps the dragged tab to the run (`left >= runLeft`), so `draggedLeft >= 0` and slot 0 is unreachable for every tab except tab 0 itself, which takes the moving-right branch (`slot = cell = 0`). This matches the report exactly. The right end works (`slot = cell`, the clamp gives `count - 1`).
- `src/saltests/saltests.cpp:2367-2368` test the slot only with `draggedLeft` -1 and -500, which the caller never passes.
- `specs/405-tab-switch-dialog-drag/fix-log.md:79-81` met it ("lands in slot 1 ... the 404 slot rule, not a defect") and changed the probe row instead.
- The same applies to the first visible tab of a scrolled strip (`FirstVisible > 0`).

**Defect 2 - not reproduced at 96 DPI.** Measured 2026-11-07 on the Release build (`build/tandemcommander/Release_x64`, 2026-11-07 04:18) on the hidden desktop with the maintainer's configuration (registry backed up and restored, export identical): a start in the default theme, a start in the dark theme, and a runtime switch default -> dark -> default (`CM_THEME_DARK` 2944 / `CM_THEME_DEFAULT` 2943).

- The tab strip window (id 958) is 29 px high and the directory line 23 px in every case; the active tab occupies rows 3-28 of the strip in both themes.
- `SalTabStripHeight` (`src/common/saltabs.cpp:482`), the panel layout (`src/fileswnb.cpp:89-113`) and `SetThemeMode` (`src/themes.cpp:1445`) do not depend on the theme.
- What does differ: the top rebar is 77 px in the default theme and 69 px in the dark one (the panels start 8 px higher); the dark active tab (45,45,45) on the strip background (36,36,36) has little contrast and merges with the 2-px top band of the directory line (45,45,45), while in the default theme a light band (240) and a grey line (160) separate them.

## Expected

1. A tab dragged to the left end of the strip takes the first place, in both panels and in a scrolled strip; the slot rule's tests drive the values the caller really passes.
2. The tab strip and its tabs have the same height in the default and the dark theme, and they look so - first measured on the build at the maintainer's DPI to find what is lower (see *Notes*).

## Approach

- Defect 1: the slot rule must give slot 0 when the dragged tab reaches the left end (e.g. moving left, tab j gives way once the left is at or below `j * width` minus half a tab, or the rule treats the clamped left end as slot 0); keep the centre-over-centre behaviour elsewhere; saltests rows with the clamped values; a probe row in `tabs404_probe` / `tabs405_probe` that drags a non-first tab to the left end.
- Defect 2: measure first (the rule of the project): ask for or reproduce the maintainer's view (DPI of the monitor, captures of both themes), compare the strip, the active tab and the rebar; fix what is really lower; if it is the dark active tab's contrast or the rebar height, record that in the fix-log and make the dark look match the default one.

## Notes

Defect 2 was not reproduced at 96 DPI (hidden desktop shares the session's system DPI); a monitor with other scaling was not tried. Captures of the measurement were made in the session scratchpad and are not kept in the repository.

Severity 5: a visible defect of a new feature in normal use (tab reordering cannot reach the first place), with a workaround (drag the first tab to the right instead); no data at risk.

## Log

- 2026-11-07 — created (source manual)
- 2026-11-07 — moved to Next position 2
