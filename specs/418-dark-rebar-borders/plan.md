# Implementation Plan: Dark theme: panel tabs look lower than in the default theme

**Branch**: `418-dark-rebar-borders` | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/418-dark-rebar-borders/spec.md`

## Summary

The top rebar keeps `WS_BORDER | RBS_BANDBORDERS` in both themes (today `ThemeUpdateRebarStyle` removes them in
Dark), so the toolbar area - and the panel tab strip below it - has the same rows in Dark as in the default theme;
in Dark the rebar's colour scheme (`RB_SETCOLORSCHEME`) is the Dark palette's `COLOR_BTNSHADOW` /
`COLOR_BTNHIGHLIGHT`, so the etched border and band borders are drawn dark (measured in an experiment on the live
build: 77 px in both themes, lines 1A1A1A / 464646 exactly where the default theme has A0A0A0 / FFFFFF, no light
line left in the Dark rebar). The default theme passes `CLR_DEFAULT` (the system colours: unchanged). A theme
switch repaints the rebar's frame and bands.

## Technical Context

**Language/Version**: C++20, MSVC v143, pure WinAPI; comctl32 classic (unthemed) rebar
**Primary Dependencies**: `RB_SETCOLORSCHEME` / `RB_GETCOLORSCHEME` (comctl32 4.70+)
**Storage**: none
**Testing**: hidden-desktop probe (row measurement of the whole window, Classic-equality vs the build of main), saltests palette check
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core)
**Performance Goals**: n/a (one message on a theme change)
**Constraints**: the default theme pixel-identical; grips stay light-only (028); high contrast unchanged
**Scale/Scope**: 1 function (`ThemeUpdateRebarStyle`, `src/themes.cpp`), 3 comments, 1 saltests check, 1 probe

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | no new files or dependencies | PASS |
| II. Backward compatibility | the default theme unchanged; Dark gets the default theme's layout | PASS |
| III. Incremental modernization | one function, the existing styles kept | PASS |
| IV. Windows commitment | a documented rebar message | PASS |
| V. Plug-in architecture | not touched | PASS |
| VI. UI consistency | Dark and Default with the same structure - the point of the item | PASS |

## Project Structure

```text
specs/418-dark-rebar-borders/   plan.md, research.md, tasks.md, fix-log.md, closing-report.md, probe/
src/themes.cpp                  ThemeUpdateRebarStyle: styles in both themes, colour scheme by theme, repaint on a switch
src/themes.h, src/mainwnd1.cpp, src/mainwnd3.cpp   comments
src/saltests/saltests.cpp       the Dark etched pair: shadow darker and highlight lighter than the face
```

## Design

1. `ThemeUpdateRebarStyle(hRebar)`: `newStyle = style | WS_BORDER | RBS_BANDBORDERS` in both themes; scheme =
   Dark ? {`ThemeSysColor(COLOR_BTNHIGHLIGHT)`, `ThemeSysColor(COLOR_BTNSHADOW)`} : {`CLR_DEFAULT`, `CLR_DEFAULT`};
   set it when it differs from `RB_GETCOLORSCHEME`; a style change keeps today's `SWP_FRAMECHANGED` + invalidate,
   a scheme change alone `RedrawWindow(RDW_INVALIDATE | RDW_ERASE | RDW_FRAME)`.
2. Callers unchanged: the start-up theming (`mainwnd3.cpp`, after the rebar is created) and `OnColorsChanged`
   (`mainwnd1.cpp`, every theme switch / colour change); `RB_SETBKCOLOR` stays in `ColorsChanged`.
3. Tests: a saltests check of the Dark palette (shadow < face < highlight in luminance, so the etched line reads
   as in the default theme); the probe `rebar418_probe.ps1`.

## Complexity Tracking

No constitution violations.
