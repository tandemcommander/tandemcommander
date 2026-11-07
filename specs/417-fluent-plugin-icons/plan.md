# Implementation Plan: Fluent 2 icons for the plug-ins; Appearance group renamed to Icon style

**Branch**: `417-fluent-plugin-icons` | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/417-fluent-plugin-icons/spec.md`

## Summary

The Fluent 2 icon set of 416 gets a `plugins\` part: one icon per known plug-in id (31) plus a default plug-in
icon and a default file-system icon, each with a hand-made Dark variant (33 + 33 SVGs, generated from the pinned
Fluent package by a committed port of the maintainer's study generator). The core replaces a plug-in's identity
icon by its set icon **at draw time**, in the sites that today take `CPluginData::PluginIcons` or `IDI_PLUGIN` /
`IDI_PLUGINFS`, only while Fluent 2 is active, only for a shipped plug-in (recognised by its DLL name
`<id>\<id>.spl`), and only when the set file is usable; every miss falls through to today's code, so Classic is
unchanged and the registry icon cache is never touched. The Plugins bar is rebuilt on every colour change. The
Appearance group is relabelled "Icon style" (`&Icon style`), with the `.slt` refresh of the enabled languages.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143, pure WinAPI
**Primary Dependencies**: vendored nanosvg (416's loader `LoadSetSVGImage` / `CreateSetSVGIcon`), `CIconList` (gray rule)
**Storage**: none new (the set choice is 416's "Toolbar Icon Set"; the plug-in icon cache `PluginIconList` is untouched)
**Testing**: `saltests` (pure rules + rasterization of the 66 new files), `check_iconset.py`, hidden-desktop probe
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand.vcxproj`); plug-ins unchanged
**Performance Goals**: a few dozen small SVGs parsed when an icon list is built (Plugins bar, a menu, a drive bar) - the same order as 416's toolbar lists
**Constraints**: Classic pixel-identical; no plug-in interface change; no set icon written into the configuration; paths UTF-8 opened wide, never cut; image-list mask keys never used as colours
**Scale/Scope**: ~10 core files, 1 dialog label, 66 data files, 1 generator, the checker, the test, the probe

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | SVGs are committed data; the generator is pinned to 416's package (version + sha512), not run by the build | PASS |
| II. Backward compatibility | no new stored value; Classic unchanged; the icon cache keeps the plug-ins' own icons; the plug-in ABI unchanged | PASS |
| III. Incremental modernization | an override in front of today's code at each site; today's code stays as the fallback | PASS |
| IV. Windows commitment | WinAPI / GDI only | PASS |
| V. Plug-in architecture preservation | no change to `spl_*.h`, `SetIconListForGUI`, `GetFSIcon` or any plug-in; third-party plug-ins keep their icons | PASS |
| VI. UI consistency | the plug-in icons join the window's default style; the dialog label fits in 8 languages | PASS |

Post-design re-check: unchanged (PASS).

## Project Structure

### Documentation (this feature)

```text
specs/417-fluent-plugin-icons/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/plugin-icon-files.md   # the plugins\ folder of the set and the replacement rules (extends 416's contract)
├── fix-log.md, closing-report.md
└── probe/                           # measure_plugins.ps1, plugin417_probe.ps1, captures, results
```

### Source Code (repository root)

```text
src/common/saliconset.h            # + plug-in ids, id from a DLL name, FS identity rule, default names, plug-in path
src/res/iconsets/fluent/plugins/   # 33 SVGs (31 plug-ins + _plugin + _pluginfs)
src/res/iconsets/fluent/plugins/dark/  # 33 hand-made Dark variants
src/svg.cpp / svg.h                # the loader takes the set's plug-in folder (CreateSetPluginSVGIcon)
src/salamdr1.cpp, src/consts.h     # CreatePluginSetIcon / CreatePluginSetDefaultIcon / PluginHasSetIcon
src/plugins2.cpp                   # CreateIconsList, Change Drive items, the "has an icon" checks of the menus
src/fileswn5.cpp                   # View With: the "has an icon" check
src/tabwnd.cpp                     # tab icon of a plug-in FS
src/fileswn3.cpp                   # directory line of a plug-in FS
src/drivelst.cpp                   # drive-list row of the open plug-in FS
src/dialogs6.cpp                   # Disconnect dialog: FS rows and the default FS icon
src/mainwnd1.cpp                   # OnColorsChanged rebuilds the Plugins bar
src/lang/lang.rc                   # " &Icon style "
src/vcxproj/!populate_build_dir.cmd # deploy plugins\ and plugins\dark\
src/saltests/saltests.cpp          # TestPluginIcons417
tools/brand/fluent-icons/          # gen_fluent_plugins.py, README.md, check_iconset.py
translations/*/salamand.slt|.origin # the new label (two-stage refresh)
```

**Structure Decision**: core-only change in the existing layout; the new files sit in a subfolder of 416's set.

## Design

1. **Pure rules** (`saliconset.h`): `SalIconSetPluginId(dllName)` - `dllName` relative, exactly `<a>\<b>.spl`
   with `a` equal to `b` (ASCII case-insensitive, no other separator, no drive / colon), `a` one of the 31 known ids
   -> the table's lower-case id, else NULL. `SalIconSetPluginFSIconIsIdentity(id)` - false only for `folders`.
   `SAL_ICONSET_NAME_PLUGIN` `"_plugin"`, `SAL_ICONSET_NAME_PLUGINFS` `"_pluginfs"`.
   `SalIconSetPluginFolder(set, dark)` - NULL for Classic, `iconsets\fluent\plugins\[dark\]` for Fluent 2;
   `SalIconSetBuildPluginPath(...)` - like `SalIconSetBuildPath` (shared builder, whole or refused).
2. **Loader** (`svg.cpp`): `LoadSetSVGImage` gains the folder kind (toolbar / plug-in); `CreateSetPluginSVGIcon(name,
   size)` = `CreateSetSVGIcon` for the active set's plug-in folder (NULL in Classic, on a miss, on an unusable file),
   the 416 dark rules unchanged.
3. **Core helpers** (`salamdr1.cpp`, declared in `consts.h`):
   - `HICON CreatePluginSetIcon(const char* dllName, int size, BOOL gray, BOOL fsIcon)` - NULL unless Fluent 2 is
     active, the id is known, (`fsIcon` ->) the FS icon is the identity, and the file renders; `gray` makes the
     copy with `CIconList::CreateAsCopy(..., TRUE)` (today's rule); the icon is HANDLES-tracked like `GetIcon(.., TRUE)`.
   - `HICON CreatePluginSetDefaultIcon(BOOL fs, int size)` - Fluent 2's `_plugin` / `_pluginfs`, NULL otherwise.
   - `BOOL PluginHasSetIcon(const char* dllName)` - Fluent 2 active, known id, the file exists.
4. **Sites**: each asks the helper first and keeps today's code as the `else`:
   - `CPlugins::CreateIconsList(gray)`: per plug-in the set icon (at the list's DPI size), else today's
     `PluginIcons` icon, else the default icon (Fluent 2 default when the set has it, else `IDI_PLUGIN`).
   - the "has an icon" tests (`PluginSubmenuIconIndex != -1`, `PluginIconIndex != -1` in `plugins2.cpp` and
     `fileswn5.cpp`) become `... || PluginHasSetIcon(p->DLLName)`.
   - `AddItemsToChangeDrvMenu`: `HIcon` / `HGrayIcon` from the set (identity icon, Folders included), else today's;
     the default branch takes the Fluent 2 default FS icon when there is one.
   - `tabwnd.cpp` plug-in FS tab: the set icon, else today's; `IconPluginFS` from the Fluent default when there is one.
   - `UpdateDriveIcon` (`fileswn3.cpp`), the drive-list row (`drivelst.cpp`) and the Disconnect dialog rows
     (`dialogs6.cpp`): the set icon with `fsIcon = TRUE` (not Folders) from `GetPluginFS()->GetDLLName()`, else
     `GetFSIcon`, else the default FS icon (Fluent 2 default or `IDI_PLUGINFS`).
5. **Rebuild**: `CMainWindow::OnColorsChanged` calls `PluginsBar->CreatePluginButtons()` when the bar exists (the
   drive bars, tabs and directory lines are already rebuilt there / by `ColorsChanged`; checked in the probe).
6. **Label**: `GROUPBOX " &Icon style "` (the access key stays `I`); preview strips unchanged; `.slt` refresh
   (stop-rules §2.13) with the read-back and pins.
7. **Data**: `tools/brand/fluent-icons/gen_fluent_plugins.py` (port of the study's generator: package path argument,
   output `src/res/iconsets/fluent/plugins[/dark]`, the transparent-key colour assertions); `check_iconset.py`
   checks the 33 names (ids from `saliconset.h` + the two defaults), both variants, nothing else, colours, parsing;
   README section; `!populate_build_dir.cmd` copies the two folders (the build's robocopy `/E` and the installer's
   recursive rule already take them).
8. **Tests**: `TestPluginIcons417` - the id rule (every shipped `<id>\<id>.spl`, case, wrong forms, absolute paths,
   unknown ids, non-ASCII), the FS identity rule, the path builder (whole or refused), and the 66 files rasterized
   at 16 / 20 / 24 / 32 px with 416's coverage and legibility thresholds; every known id and both defaults present.
9. **Probe** `plugin417_probe.ps1` (style of `iconset416_probe.ps1`, its helpers): Classic vs the build of `main`
   (Plugins bar, drive bar, a plug-in FS directory line, the Plugins manager list) 0 px; Fluent 2 per plug-in button
   differs and is drawn; switch both ways with OK; empty / removed set file -> today's icon; Folders' directory line
   unchanged; the label fits.

## Complexity Tracking

No constitution violations.
