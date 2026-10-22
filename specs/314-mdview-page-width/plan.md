# Implementation Plan: Markdown Viewer - choose the page width in View, up to the full window

**Branch**: `314-mdview-page-width` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/314-mdview-page-width/spec.md`

## Summary

The MDView plug-in limits its text column to 46rem. Add four page-width levels (Normal 46rem -
the default and today's page, Wide 64rem, Wider 90rem, Full Window no limit) chosen from a new
View > Page Width radio submenu, applied by rebuilding the page exactly as a color-scheme change
does, stored as `PageWidth` (DWORD 0-3) in the plug-in's registry key. The level-to-CSS rule and
the reading of a stored value are pure and live in the generator (`htmlgen.*`), checked by the
generator harness; the menu, the per-window state and the configuration live in `viewer.cpp` /
`mdview.cpp`. Nothing in `src/common/webhost/` changes.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: md4c (vendored), the shared WebView2 host `src/common/webhost/` (unchanged)
**Storage**: plug-in registry key through `CSalamanderRegistryAbstract` (new value `PageWidth`)
**Testing**: `tests/mdview_htmlgen_test/build_and_run.cmd` (generator assertions); a
hidden-desktop probe `specs/314-mdview-page-width/probe/pw314_probe.ps1`; regression
`specs/081-mdview-shared-webhost/probe/mdview_probe.ps1 -Scenario smoke`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`mdview.spl` + `mdview.slg`)
**Performance Goals**: a width change costs one page rebuild, the same as a scheme change
**Constraints**: scripts stay off in the page (feature 021 lockdown); no shared-host change
(item note, `architecture/11-webview2-integration.md`); no plug-in interface change; UI strings
in free slots of an existing string bundle (rule 084)
**Scale/Scope**: 5 new strings, 4 menu commands, 1 configuration value

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency; the harness is the existing cl.exe recipe; PASS |
| II Backward compatibility | default level Normal = today's page; a missing/unknown stored value reads Normal; older configurations load unchanged; PASS |
| III Incremental modernization | only the generator's article tag/CSS, the View menu and two config functions change; PASS |
| IV Windows commitment | pure WinAPI menu, nothing new; PASS |
| V Plugin architecture | no change to `spl_*.h` or `LAST_VERSION_OF_SALAMANDER`; PASS |
| VI UI consistency | a radio submenu like Color Scheme, through the plug-in's existing dark-menu path; no dialog; PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/314-mdview-page-width/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/page-width.md   # levels, CSS, stored value, menu ids
├── fix-log.md
├── probe/pw314_probe.ps1, probe/result_*.txt
└── tasks.md
```

### Source Code (repository root)

```text
src/plugins/mdview/
├── htmlgen.h / htmlgen.cpp   # MdPageWidth levels, MdPageWidthFromStored, article class, CSS rules
├── viewer.h / viewer.cpp     # PageWidth member, Page Width submenu, checks, command dispatch
├── mdview.h / mdview.cpp     # g_pageWidth, CONFIG_PAGEWIDTH load/save, CM_VIEW_WIDTH_* ids
├── mdview.rh2                # IDS_MENU_VIEW_PAGEWIDTH + 4 level strings (free slots of string block 127)
├── lang/lang.rc2             # the English texts
└── IMPLEMENTATION_NOTES.md   # levels instead of the unwired toggle
tests/mdview_htmlgen_test/test_main.cpp   # new assertions
```

**Structure Decision**: the pure rule stays in the plug-in's generator (not `src/common/`): it is
mdview-only, and the generator already has its own harness that links it without the plug-in
runtime. `saltests` is unaffected (no `src/common/` change).

## Complexity Tracking

None.
