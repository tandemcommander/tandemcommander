# Implementation Plan: Panel tabs - taller rounded look with icons and Chrome-like mouse handling

**Branch**: `404-panel-tabs-rounded-look` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/404-panel-tabs-rounded-look/spec.md` (backlog item
`panel-tabs-rounded-windows-11-look-with-icons-and-roomier`)

## Summary

Redraw the panel tab strip (`CTabWindow`, `src/tabwnd.cpp`) as variant F of the 2026-11-06 mockups
(the C# renderer `evidence/TabMock.cs`, variant 6, is the reference implementation of every metric
and colour), add a location icon to every tab, replace the insert-mark drag by a live, animated
reorder, close a tab on release over its X instead of on press, and add *Move to Other Panel* and
*New Tab as Other Panel* to the strip's context menu. Anti-aliased shapes are rasterized with the
vendored nanosvg into a reusable 32-bit DIB and alpha-blended onto the shared `ItemBitmap`; text
stays GDI. Pure rules (metrics, colour mixes, drag slots, menu enabling, location kind) go to
`src/common/saltabs.*` with `saltests` checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI (GDI, `AlphaBlend` from msimg32 already linked), vendored nanosvg /
nanosvgrast (`src/common/dep/nanosvg`)
**Storage**: none new (tab persistence unchanged; the icon kind is session-only)
**Testing**: `saltests` (pure rules), PowerShell GUI probe on the hidden desktop
(`specs/404-panel-tabs-rounded-look/probe/tabs404_probe.ps1`), `tabs312_probe` as regression
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand.vcxproj`)
**Performance Goals**: a strip repaint well under one 60-fps frame (16 ms) with 20 tabs; no file
system call while painting
**Constraints**: no GDI+ in the core; plug-in ABI untouched; no new persisted value
**Scale/Scope**: `tabwnd.cpp/.h`, `paneltabs.cpp/.h`, `mainwnd3.cpp` (command dispatch),
`resource.rh2`, `texts.rh2` + `lang/texts.rc2` (2 strings), `themes.*` (High Contrast accessor),
`saltabs.*`, `saltests.cpp`, translations (`salamand` module)

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I Build reproducibility | nanosvg is already vendored; no new dependency, no NuGet | PASS |
| II Backward compatibility | registry layout and tab persistence unchanged; existing commands and ids unchanged; new ids in a free range 2885-2888 | PASS |
| III Incremental modernization | one surface (the strip) modernized; panel and other code untouched | PASS |
| IV Windows commitment | WinAPI only, Windows 11 look | PASS |
| V Plugin architecture preservation | no `spl_*.h` change; plug-in icons read from the core's `PluginIcons` copy | PASS |
| VI UI consistency | the strip follows the theme engine (`ThemeSysColor`, caption colours, Dark, High Contrast) and the system font; the classic look is not kept as an option (spec Assumptions) | PASS |

## Design

1. **Metrics and colours** (`saltabs.h`, pure): `SalTabStripHeight(fontHeight, scalePercent)` and `SalTabStripWidths(avgChar,
   scalePercent, &min, &max)` give the height and the width limits (the other metrics are constants x scale);
   `SalTabMix(a, b, percent)` is the mockup's rounding mix; `SalTabStripColors(...)` derives
   strip background, dim text, hover background, separator colour from the system colours and the
   theme flags (Dark, High Contrast).
2. **Anti-aliased drawing** (`tabwnd.cpp`): `CTabStripPainter` owns one nanosvg rasterizer and a DIB
   section of the strip's size. `FillPath(dc, svgPathData, colour, bbox)` / `StrokePath(...)` builds
   a one-path SVG (white), rasterizes the bounding box into the DIB (coverage = alpha), turns the
   coverage into premultiplied BGRA of the wanted colour and `AlphaBlend`s the box onto
   `ItemBitmap`. Shapes: the active tab outline with feet, the hover pill, the close circle, the plus
   circle, the X and the + strokes (round caps).
3. **Paint order** (mockup `PaintNew`): fill strip background; hover pills of non-active tabs; the
   active tab outline; separators; for every tab its icon, title and close glyph; the plus glyph; the
   list button. While a drag is live the dragged tab is painted last at its drawn x.
4. **Icons**: `CPanelTab` gains session fields `IconKind` and `IconDriveType` (set by
   `CaptureActiveTab` from the panel's real type; for a never-shown restored tab derived once from
   the location text by `SalTabLocationKind` plus `GetDriveType` for a letter root only). The strip
   keeps a cache of HICONs: folder (`SimpleIconLists[ICONSIZE_16]`, `symbolsDirectory`), archive
   (`LoadArchiveIcon`), drive per (type, system drive) via `GetDriveIcon` (removable: the generic
   id, no shell call), plug-in FS per plug-in (`PluginIcons` at `ChDrvMenuFSItemIconIndex`, else
   `IDI_PLUGINFS`). The cache is dropped on colour / DPI / font change.
5. **Live drag**: per-tab drawn x offsets (`TabAnim[]`: current, from, target, start time); a window
   timer (16 ms) advances an ease-out over 150 ms and stops when every offset is at its slot; the
   dragged tab follows `cursor x - grab offset`, clamped to the visible run; the target slot comes
   from `SalTabDragSlot` (centre crossing); release: `MoveTab(from, to)` once, then the dragged tab
   glides from its drawn x to its slot; cancel (Esc via `GetAsyncKeyState` in the timer, capture
   loss, `WM_CANCELMODE`, right button): every tab glides back, order unchanged.
   `SPI_GETCLIENTAREAANIMATION` off -> offsets jump.
6. **Close on release**: `PressedClose` index; down on X sets it and captures; move updates
   `PressedCloseInside`; up over the same X closes; capture loss forgets it. A press on X never
   switches or arms a drag.
7. **Commands**: `CM_LEFT_MOVETABTOOTHER` 2885, `CM_RIGHT_MOVETABTOOTHER` 2886,
   `CM_LEFT_NEWTABASOTHER` 2887, `CM_RIGHT_NEWTABASOTHER` 2888 (free range). Context menu local ids
   7 (New Tab as Other Panel, after New Tab) and 8 (Move to Other Panel, after Duplicate Tab);
   `CFilesWindow::MoveTabToOtherPanel(index)` and `CFilesWindow::NewTabAsOtherPanel()` in
   `paneltabs.cpp`; enabling by `SalTabMenuCanMoveToOther` / `SalTabMenuCanNewAsOther`.
8. **Strings**: `IDS_MENU_TAB_MOVETOOTHER` 14192, `IDS_MENU_TAB_NEWASOTHER` 14193 (free slots of the
   bundle 14192-14207); `.slt` refresh of `salamand` for the enabled languages (stop-rules §2.13).

## Project Structure

### Documentation (this feature)

```text
specs/404-panel-tabs-rounded-look/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/tab-strip-f.md
├── fix-log.md, closing-report.md
└── probe/tabs404_probe.ps1 (+ result_*.txt, captured PNGs)
```

### Source Code

```text
src/tabwnd.cpp, src/tabwnd.h          strip painting, icons, mouse, menu
src/paneltabs.cpp, src/paneltabs.h    icon kind, Move to Other Panel, New Tab as Other Panel, commands
src/mainwnd3.cpp                      WM_COMMAND cases for the 4 new ids
src/resource.rh2                      CM_ ids 2885-2888
src/texts.rh2, src/lang/texts.rc2    2 strings
src/themes.cpp, src/themes.h          IsThemeHighContrast()
src/common/saltabs.cpp, saltabs.h     pure rules
src/saltests/saltests.cpp             checks
```

**Structure Decision**: the existing core layout; no new project.

## Complexity Tracking

No constitution violation.
