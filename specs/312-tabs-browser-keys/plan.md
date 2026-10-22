# Implementation Plan: Panel tabs - a Tabs settings page, opt-in browser-like shortcuts, Reopen Closed Tab

**Branch**: `312-tabs-browser-keys` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/312-tabs-browser-keys/spec.md`

## Summary

One pure table in `src/common/saltabs.*` (extended; saltests already compile it) gives, for every
key of the decision table and each mode, what the key means and whether the tab code dispatches
it; the same table gives the key text of every labelled command per mode and the rows of the list
on the new Tabs page. The panel's key handler and the command line's key handler ask it first
(guarded by *Show tabs in panels*). A per-panel list of closed tabs (the `CPanelTab` objects
themselves, detached, with the position they had; at most 10) backs a new *Reopen Closed Tab*
command. A new Configuration page *Tabs* (after Appearance) carries *Show tabs in panels* (moved)
and the new option; a remembered page index of an older configuration is mapped. *Tabs* joins the
toolbar context menu and Options > Show through a new toggle command. Labels and tooltips that
name a mode-dependent key are produced at the moment they are shown.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI, the house menu / dialog classes (`CMenuPopup`, `CCommonPropSheetPage`, `CTreePropDialog`)
**Storage**: one new REG_DWORD under `HKCU\Software\Tandem Commander\0.1\Configuration` (`Browser Tab Shortcuts`), written with the configuration; closed tabs in memory only
**Testing**: `saltests` (pure rules), a hidden-desktop GUI probe `specs/312-tabs-browser-keys/probe/tabs312_probe.ps1` (keys driven as in `specs/093-unicode-dialogs/probe/cmdline_probe.ps1`: AttachThreadInput + SetKeyboardState + sent WM_KEYDOWN)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `tandemcommander.exe`)
**Performance Goals**: none beyond the existing tab switch
**Constraints**: classic behaviour byte-for-byte with the option off (labels, keys); plug-in ABI untouched; no new UI string bundle (free slots of existing bundles, rule 084)
**Scale/Scope**: ~10 core files, 1 new dialog, ~9 new strings, 1 new help page + 4 edited

## Constitution Check

| Principle | Status |
|---|---|
| I Build reproducibility | PASS - no new dependency; the new dialog lives in `lang.rc` like every page |
| II Backward compatibility | PASS - the behaviour change is opt-in (default off); an older configuration reads as off and opens its remembered page; no `THIS_CONFIG_VERSION` bump |
| III Incremental modernization | PASS - additions next to 078's code; no refactor of adjacent code |
| IV Windows commitment | PASS |
| V Plugin architecture | PASS - plug-in interface untouched; Ctrl+Shift+G reserved for new assignments only, an existing assignment kept |
| VI UI consistency | PASS - `DIALOGEX`, `DS_SETFONT | DS_FIXEDSYS`, `FONT 8, "MS Shell Dlg"`, standard checkbox + `SysListView32` report view as in other pages |

Post-design re-check: unchanged (PASS).

## Project Structure

### Documentation (this feature)

```text
specs/312-tabs-browser-keys/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/tab-keys.md      # the key table per mode, labels, list rows
├── tasks.md
├── fix-log.md
└── probe/tabs312_probe.ps1
```

### Source Code (repository root)

```text
src/common/saltabs.h/.cpp     # + key table, key text, label key replacement, closed-list rules, page-index mapping
src/saltests/saltests.cpp     # + TestTabKeys312
src/paneltabs.h/.cpp          # + closed-tab list, ReopenClosedTab, mode labels (LoadStrTabKeys), tabs on/off helper
src/fileswn0.cpp              # panel key dispatch through the table
src/editwnd.cpp               # command-line key dispatch through the table
src/fileswn1.cpp, fileswn9.cpp# ClearHistory / ClearPluginFSFromHistory also over closed tabs
src/keyboard.cpp, plugins1.cpp# Ctrl+Shift+G reserved; an existing plug-in key kept at load
src/cfgdlg.h, dialogs4.cpp, dialogs5.cpp  # Configuration value, Tabs page, Appearance page without the checkbox, page order
src/mainwnd2.cpp              # save / load the value; map LastFocusedPage of an older configuration
src/mainwnd1.cpp, mainwnd3.cpp, menu4.cpp, tabwnd.cpp, toolbar4.cpp  # commands, menus, labels, tooltips
src/resource.rh2, texts.rh2, lang/texts.rc2, lang/lang.rc, lang/lang.rh  # ids, strings, dialog
help/src/...                  # configuration_tabs.htm (new), shortcuts_keyboard.htm, windows_tabstrip.htm, configuration_appea.htm, hhp/hhc/hhk
CHANGELOG.md                  # entry under the unreleased section
```

**Structure Decision**: core only; the pure rules extend the 078 module `saltabs.*` (already in the
`saltests` project), so no project file changes.

## Phases

- Phase 0: [research.md](research.md) - dispatch points, label points, page placement, plug-in key
  rule, closed-tab ownership, strings.
- Phase 1: [data-model.md](data-model.md), [contracts/tab-keys.md](contracts/tab-keys.md),
  [quickstart.md](quickstart.md).

## Complexity Tracking

None.
