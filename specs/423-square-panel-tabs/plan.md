# Implementation Plan: Square panel tabs as the new default; rounded tabs kept as an Appearance option

**Branch**: `423-square-panel-tabs` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/423-square-panel-tabs/spec.md`

## Summary

The panel tab strip (`CTabWindow`, feature 404) gets a second shape: **Square** (new default) paints
the active tab and the hover highlight as plain rectangles (no arcs, no feet); **Rounded** keeps the
404 paths. The choice is a new configuration value `Panel Tab Style` (REG_DWORD, 0 = Square, 1 =
Rounded; missing / wrong type / unknown = Square, kept as read), offered on *Configuration >
Appearance* in a *Tab style* group directly below *Icon style* and applied on OK (and after a
settings import) by repainting both strips. In the Light theme the inactive titles and the + glyph
are darkened (text mixed 20 % toward the strip instead of 38 %: 545454 -> 2C2C2C on DEDEDE, 5.63:1
-> 10.38:1). The pure parts (stored value -> style, the Light title mix) live in
`src/common/saltabs.*` with `saltests` checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: WinAPI, vendored nanosvg (the rounded shapes), GDI (`ExtTextOutW` fills for the square shapes)  
**Storage**: registry value `Panel Tab Style` under `SALAMANDER_ROOT_REG` + `Configuration` (written with the configuration, like `Toolbar Icon Set` of 416)  
**Testing**: `saltests` (pure rules), hidden-desktop probe `specs/423-square-panel-tabs/probe/tabs423_probe.ps1` (pixels), regression probes `tabs404_probe`, `tabs413_probe` run with Rounded set  
**Target Platform**: Windows 11+, x64  
**Project Type**: desktop application (pure WinAPI)  
**Performance Goals**: no measurable change (a rectangle fill is cheaper than the AA path)  
**Constraints**: the Configuration dialog's page area is the largest page (299 x 231 du, `CTreePropDialog` in `src/common/sheets.cpp`): the Appearance page must stay within 231 du or the whole dialog grows  
**Scale/Scope**: `src/tabwnd.cpp`, `src/common/saltabs.*`, `src/dialogs4.cpp` / `dialogs5.cpp`, `src/mainwnd2.cpp` / `mainwnd3.cpp`, `src/cfgdlg.h`, `src/mainwnd.h`, `src/lang/lang.rc` / `lang.rh`, `src/saltests/saltests.cpp`, translations of module `salamand`

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I. Build Reproducibility | no new dependency, no NuGet; `build.cmd` / `build.cmd full` | PASS |
| II. Backward Compatibility | a configuration without the value gives the new default (Square) - a visible change the maintainer asked for; nothing is removed: Rounded is one click away; an unknown stored value is kept (forward compatibility, as 416) | PASS (intended default change, recorded in CHANGELOG) |
| III. Incremental Modernization | one paint branch, one value, one page group | PASS |
| IV. Windows Platform Commitment | WinAPI only | PASS |
| V. Plugin Architecture Preservation | no plug-in interface touched | PASS |
| VI. UI Consistency | the group follows the *Icon style* group's form (group box + radio buttons); Light / Dark / High Contrast handled; translations refreshed (formal register) | PASS |

Post-design re-check: unchanged (PASS).

## Project Structure

### Documentation (this feature)

```text
specs/423-square-panel-tabs/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/tab-style.md      # the stored value, the painted shapes, the page group
├── fix-log.md                  # running log
└── probe/tabs423_probe.ps1     # hidden-desktop pixel probe (+ results, captures)
```

### Source Code (repository root)

```text
src/common/saltabs.h / .cpp     # SALTAB_STYLE_*, SalTabStyleFromStored, Light DimText mix
src/saltests/saltests.cpp       # TestTabStrip423 (+ the 404 DimText expectation updated)
src/tabwnd.cpp                  # PaintTabBack: square branch (active tab, hover)
src/cfgdlg.h, src/dialogs4.cpp  # Configuration.PanelTabStyle + default
src/mainwnd2.cpp, src/consts.h  # CONFIG_PANELTABSTYLE_REG, ReadPanelTabStyle, GetActiveTabStyle, save
src/mainwnd.h, src/mainwnd3.cpp # CCfgRefreshState: repaint both strips on a style change
src/dialogs5.cpp                # CCfgPageAppearance::Transfer: the two radio buttons
src/lang/lang.rc, lang.rh       # the Tab style group; Thumbnails beside Panel Font
translations/*/salamand.slt     # the two-stage refresh
```

**Structure Decision**: the existing core layout; the pure rules join the tab-strip rules of
`saltabs.*` (already compiled into `saltests`).

## Complexity Tracking

None.
