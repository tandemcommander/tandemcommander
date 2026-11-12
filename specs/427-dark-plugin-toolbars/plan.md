# Implementation Plan: Plug-in toolbars and chrome in the Dark theme

**Branch**: `427-dark-plugin-toolbars` | **Date**: 2026-11-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/427-dark-plugin-toolbars/spec.md`

## Summary

The core adapts its legacy toolbar glyphs for Dark (`ThemeAdjustBitmapForDarkMode`, 028/029,
pure math `ThemeDarkAdaptColor` in `src/common/themes_palette.h`); PictView and File Comparator
build their toolbars from legacy bitmaps without it, and File Comparator paints parts of its
chrome with the classic system brushes. The fix moves the bitmap walk of
`ThemeAdjustBitmapForDarkMode` into a header-only `src/common/themes_bitmap.h`
(`ThemeDarkAdaptBitmap`), which the core keeps calling and the two plug-ins call when
`IsDarkThemeActive()` (already in the plug-in interface) says Dark. File Comparator's chrome takes
the theme's brushes and colours (`GetThemeSysColor` / `GetThemeSysColorBrush`, identical to the
system ones in Default), its rebar gets the Dark background / text / colour scheme, and its combo
box and views get the core's control theming (`ThemeApplyToDialog` on the main window, already in
the interface). The checkbox labels do not reproduce (research R1): nothing in their drawing
changes; the probe guards them. After review 1/2: the plug-ins use `ThemeDarkAdaptBitmapLift`
(028 + a 3:1 lift of low-contrast saturated colours), and both windows follow a live theme switch
(PictView refills its image lists in place on `WM_USER_VIEWERCFGCHNG`; File Comparator
`RefreshThemeChrome` on `CC_COLORS`: `TB_REPLACEBITMAP`, rebar and band colours, control theming).

## Technical Context

**Language/Version**: C++20, MSVC v143; PowerShell 5.1 probes.
**Primary Dependencies**: Win32 GDI / comctl32 6 (rebar, toolbar), the plug-in interface (no change).
**Storage**: none (the probe backs up and restores the registry key).
**Testing**: `saltests` (a check of `ThemeDarkAdaptBitmap` on a GDI bitmap), the hidden-desktop
probe `specs/427-dark-plugin-toolbars/probe/dark427_probe.ps1` (before / after, Dark and Default).
**Target Platform**: Windows 11 x64.
**Project Type**: desktop application + plug-ins.
**Constraints**: plug-in ABI append-only and untouched (FR-005); Default theme pixel-identical
(FR-004); Classic icon set not restyled beyond the core's Dark behaviour (416).

## Constitution Check

- I Build reproducibility: no new dependency; a header in `src/common`.
- II Backward compatibility: no interface or registry change; Default theme unchanged.
- III Incremental modernization: the existing 028 transform reused, not a new icon set.
- IV Windows commitment: Win32 only.
- V Plugin architecture preservation: no ABI change; shared code header-only (CLAUDE.md rule).
- VI UI consistency: plug-in toolbars in Dark follow the core's legacy-glyph behaviour.

Gate: passes.

## Project Structure

### Documentation (this feature)

```text
specs/427-dark-plugin-toolbars/
├── spec.md, plan.md, research.md, quickstart.md, tasks.md, fix-log.md
└── probe/ (dark_measure.ps1 - the measurement on main; dark427_probe.ps1 - the feature probe;
            chk_experiment.ps1 - the standalone checkbox experiment; results and captures)
```

### Source Code

```text
src/common/themes_bitmap.h            # new: ThemeDarkAdaptBitmap (header-only, from themes.cpp)
src/themes.cpp                        # ThemeAdjustBitmapForDarkMode calls it
src/saltests/...                      # a check of ThemeDarkAdaptBitmap
src/plugins/pictview/pictview.cpp     # CViewerWindow::InitializeGraphics adapts the colour bitmap in Dark
src/plugins/filecomp/mainwnd.cpp      # toolbar bitmap adapted, rebar colours, ThemeApplyToDialog
src/plugins/filecomp/controls.cpp     # theme brushes / colours instead of the system ones
```

**Structure Decision**: one shared header; plug-in changes at the measured sites.

## Complexity Tracking

None.
