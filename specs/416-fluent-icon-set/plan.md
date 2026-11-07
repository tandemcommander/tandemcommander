# Implementation Plan: Fluent toolbar icon set by default, switchable to Classic in Appearance

**Branch**: `416-fluent-icon-set` | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/416-fluent-icon-set/spec.md`

## Summary

A second icon set ("Fluent 2", 95 + 95 SVGs from the maintainer's design study) becomes the default; the existing
set becomes "Classic" and stays byte-identical in look. One setting (`Configuration.ToolbarIconSet`, registry value
"Toolbar Icon Set" under the configuration root, missing/unknown = Fluent 2) selects the set. The SVG loader takes the
set's folder; Fluent 2 also replaces the shell icons of the 9 system-folder buttons, the imageres drive icons
(drive bar, Change Drive menu, panel drive icon, tabs, Drive Information), the `..` symbol and the drop-down chevron.
The Appearance page gets a "Toolbar icons" group with two radio buttons and owner-drawn preview strips built by the
same `CreateToolbarBitmaps` the toolbars use. OK applies the change through `ColorsChanged(TRUE, FALSE, TRUE)` (the
theme switch's pipeline). The dark-override fallback of feature 029 is made real (parse first, use only a parsed
image with shapes, never blank the cell). Pure rules live in `src/common/saliconset.h` with `saltests` checks; the
same tests rasterize every Fluent file with the vendored nanosvg at 16/20/24/32 px and check coverage and contrast.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143, pure WinAPI
**Primary Dependencies**: vendored nanosvg (`src/common/dep/nanosvg`, modified rasterizer: premultiplied output, SSE)
**Storage**: registry value "Toolbar Icon Set" (REG_DWORD) under `SALAMANDER_ROOT_REG` \ `SALAMANDER_CONFIG_REG`
**Testing**: `saltests` (pure rules + offline rasterization of the set), hidden-desktop GUI probe (PrintWindow captures)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand.vcxproj`)
**Performance Goals**: building the image lists stays within today's cost (~190 small SVGs parsed at start-up / theme switch; Classic reads ~64)
**Constraints**: Classic pixel-identical to 0.2.0; image-list mask keys (magenta, BTNFACE) never used as icon colours; paths UTF-8 and opened wide; a path that does not fit is refused, never cut
**Scale/Scope**: ~10 source files of the core, 1 dialog, 2 strings + 2 radio labels, 191 data files, 1 generator

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | SVGs are committed data; the generator is pinned (npm version + sha512) but not run by the build; no NuGet, no network in the build | PASS |
| II. Backward compatibility (baseline 0.1.0) | new registry value only; missing = Fluent 2 by the item's decision; Classic keeps today's look; no plug-in API change | PASS |
| III. Incremental modernization | the new set is added beside the old one; old code paths stay for Classic | PASS |
| IV. Windows commitment | WinAPI / GDI only | PASS |
| V. Plug-in architecture preservation | plug-in icons and `SetIconListForGUI` untouched; `CreateToolbarBitmaps` is not in the plug-in API | PASS |
| VI. UI consistency | one consistent default style; Classic available; dialog layout checked in 8 languages | PASS |

Post-design re-check: unchanged (PASS).

## Project Structure

### Documentation (this feature)

```text
specs/416-fluent-icon-set/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/icon-set-files.md   # the set folders and the override fallback (extends 029's contract)
├── fix-log.md, closing-report.md
└── probe/                        # iconset416_probe.ps1, captures, results
```

### Source Code (repository root)

```text
src/common/saliconset.h           # pure rules: set id, folders, path building, Fluent name tables, preview list, override choice
src/res/iconsets/fluent/*.svg     # Fluent 2 standard (95) + LICENSE-fluent.txt
src/res/iconsets/fluent/dark/*.svg# Fluent 2 hand-made dark variants (95)
src/res/down_fluent.svg           # Fluent chevron (RCDATA IDV_ARROW_DOWN_FLUENT)
src/svg.cpp / svg.h               # set-aware loader with real fallback; icon creation from a set SVG
src/toolbar4.cpp                  # set-aware names, shell icons only in Classic (or as fallback)
src/salamdr1.cpp                  # GetDriveIcon, `..` icon, chevron, early read of the setting
src/drivelst.cpp, src/tabwnd.cpp  # Documents / Network / removable via the set
src/gui.cpp                       # configuration-list toolbar names per set
src/cfgdlg.h, src/dialogs4.cpp, src/dialogs5.cpp, src/mainwnd2.cpp, src/mainwnd3.cpp, src/mainwnd.h, src/consts.h
src/lang/lang.rc, src/lang/lang.rh, src/lang/lang.rc2  # Appearance group, radio buttons, previews
src/resource.rh2, src/salamand.rc2                     # IDV_ARROW_DOWN_FLUENT
src/vcxproj/!populate_build_dir.cmd                    # deploy iconsets\fluent\ and \dark\
src/saltests/saltests.cpp                              # TestIconSet416
tools/brand/fluent-icons/                              # gen_fluent.py, README.md, check_iconset.py
doc/third_party.txt                                    # Fluent UI System Icons notice
```

**Structure Decision**: core-only change in the existing layout; data files beside the existing `src/res/toolbars/`.

## Design

1. **Setting**: `Configuration.ToolbarIconSet` (int), default `SAL_ICONSET_FLUENT` in `CConfiguration` ctor; read in
   the early start-up block (with Theme Mode, before `InitializeGraphics`) and in `LoadConfig`, written in `SaveConfig`;
   every read normalised by `SalIconSetFromStored`.
2. **Loader** (`svg.cpp`): `LoadSetSVGImage(name, set)` reads the dark variant (Dark theme only), parses it, keeps it
   only when it has shapes (`SalIconSetChooseSource`), else reads/parses the standard file; applies the existing dark
   adaptation to a standard file in Dark; returns NULL when nothing usable. `RenderSVGImage` returns BOOL, fills the
   cell only after a usable image exists (Classic with valid files = the same calls in the same order as today).
   `CreateSetSVGIcon(name, set, size)` rasterizes into a 32-bpp DIB, un-premultiplies, `CreateIconIndirect`.
3. **Toolbar image list**: `GetSVGIconsMainToolbar(set)` gives Classic the table as today, Fluent the table with
   `SalIconSetFluentButtonName` overrides (Shares fixed, Zoom none, Change Drive slots, the 9 system folders).
   `CreateToolbarBitmaps(..., iconSet)`: shell icons are appended for Classic as today; for Fluent a shell-icon button
   whose SVG rendered skips the shell icon (a missing file falls back to the shell icon).
4. **Other sites**: `GetDriveIcon` / tab removable / Documents / Network call `CreateSetSVGIcon` for Fluent with the
   Classic call as fallback; the `..` icon at the three sizes likewise; `SVGArrowDropDown` loads
   `IDV_ARROW_DOWN_FLUENT` with GRAYTEXT disabled colour in Fluent; `CToolbarHeader` uses the set's names.
5. **Appearance page**: group "Toolbar icons" at y 188-229 DLU (room below Thumbnails), radio "&Fluent 2" / "C&lassic",
   two `SS_OWNERDRAW` statics; `WM_INITDIALOG` builds both sets' colour+mask bitmaps with `CreateToolbarBitmaps`
   (active theme) and `WM_DRAWITEM` draws the 10 preview cells on BTNFACE; `Transfer` maps the radios.
6. **Apply**: `CCfgRefreshState` captures the set; `RefreshAfterConfiguration` calls `ColorsChanged(TRUE, FALSE, TRUE)`
   when it changed (also serves the settings import).
7. **Deploy & licence**: `!populate_build_dir.cmd` copies `iconsets\fluent\` (with `LICENSE-fluent.txt`) and `\dark\`;
   the installer's recursive rule ships them; `doc/third_party.txt` names the glyphs and `doc/license/license_mit.txt`.

## Complexity Tracking

No constitution violations.
