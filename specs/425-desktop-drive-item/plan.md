# Implementation Plan: A real Desktop drive item; Shell Folders named for what they are

**Branch**: `425-desktop-drive-item` | **Date**: 2026-11-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/425-desktop-drive-item/spec.md` (backlog item
`ikona-na-desktop-vede-kamsi-neznamo-kam`, GitHub #31)

## Summary

Three parts, one feature. (1) The core gets a Desktop drive item of its own type, built like the
Documents item: after Documents in the Change Drive menu and on the drive bars, hot key `'`, icon
`OpenDesktop` (Fluent 2) / imageres 183 (Classic), switch "Change Drive Show Desktop" (default on) on
the Change Drive page; choosing it opens `FOLDERID_Desktop` (read wide, any length, whole or refused)
through `ChangePathToDisk`, after a check that the folder exists - otherwise a message and no change.
(2) The Folders plug-in's drive-menu text becomes `` `\tShell Folders`` . (3) The plug-in's
`ExecuteOnFS` asks the shell whether an entered folder is a file-system folder whose path is an
existing directory; if so it calls `ChangePanelPathToDisk` instead of staying in `fld:`. Pure rules in
the header-only `src/common/saldesktop.h` with `saltests`; Debug-only probe seams; one hidden-desktop
probe; the two-stage `.slt` refresh for `salamand` and `folders`; the manual pages.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143, pure WinAPI
**Primary Dependencies**: shell32 (`SHGetKnownFolderPath`, `SHGetPathFromIDListEx`, `ILCombine`,
`IShellFolder::GetAttributesOf`), the core's drive list (`drivelst.cpp`), plug-in API (`ChangePanelPathToDisk`)
**Storage**: one new configuration value `Change Drive Show Desktop` (REG_DWORD) under the existing
`Configuration` key, read with a default (absent = on)
**Testing**: `saltests` (pure rules), GUI probe `specs/425-desktop-drive-item/probe/desktop_probe.ps1`
on the hidden desktop
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core + plug-in)
**Performance Goals**: no measurable cost in the drive-list build (one icon load, no disk access at
build time - the path is read only when the item is chosen)
**Constraints**: UTF-8 / WTF-8 paths, never cut (refuse); plug-in ABI unchanged; no new network access
**Scale/Scope**: core files `drivelst.cpp/.h`, `fileswn3.cpp`, `fileswnd.h`, `toolbar6.cpp`,
`shellib.cpp`, `consts.h`, `cfgdlg.h`, `dialogs4.cpp`, `dialogs5.cpp`, `mainwnd2.cpp`, `texts.rh2`,
`lang/texts.rc2`, `lang/lang.rc`, `lang/lang.rh`, `common/saliconset.h`; plug-in `folders`
(`fs1.cpp`, `fs2.cpp`, `lang/lang.rc2`); `saltests`; three manual pages

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency; vendored only; `build.cmd` unchanged |
| II Backward compatibility (0.1.0) | new value read with a default; enum value appended at the end (374's trap); the plug-in's stored drive-menu name is replaced at its next connect; no ABI change |
| III Incremental modernization | follows the existing Documents / WSL items; pure rules in `src/common/` |
| IV Windows commitment | known-folder API, shell attributes |
| V Plug-in architecture | the plug-in uses the existing `ChangePanelPathToDisk` (allowed in `CPluginInterfaceForFS` methods) |
| VI UI consistency | the Fluent 2 `OpenDesktop` icon (light + dark exist), Classic shell icon; the switch beside Documents |

Gates pass; nothing maintainer-owned (no network, no stored-data layout change beyond one new value
next to the existing ones, no plug-in interface change, no installer change, no shipping change).

## Project Structure

### Documentation (this feature)

```text
specs/425-desktop-drive-item/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/probe-seams.md
├── fix-log.md
└── probe/desktop_probe.ps1, result_*.txt
```

### Source Code

```text
src/common/saldesktop.h            pure rules (new, header-only, used by the core and the plug-in)
src/saltests/saltests.cpp          TestDesktopDrive425
src/drivelst.h / drivelst.cpp      drvtDesktop: build, bar, tooltip, no context menu, execute
src/fileswnd.h / fileswn3.cpp      ChangePathToDesktop; ChangeDrive case
src/toolbar6.cpp                   drive bar Execute case
src/shellib.cpp, src/consts.h      GetDesktopPathU8 (+ Debug seam TC_PROBE_DESKTOP_FILE)
src/cfgdlg.h, dialogs4.cpp, dialogs5.cpp, mainwnd2.cpp   ChangeDriveShowDesktop
src/texts.rh2, src/lang/texts.rc2  IDS_DESKTOPDRIVE, IDS_DESKTOPNOTFOUND (bundle 885, free slots)
src/lang/lang.rc, lang.rh          IDC_CHD_SHOWDESKTOP on IDD_CFGPAGE_CHANGEDRIVE
src/common/saliconset.h            SAL_ICONSET_NAME_DESKTOP "OpenDesktop"
src/plugins/folders/fs1.cpp        ExecuteOnFS: a file-system folder opens as a disk path (+ seam)
src/plugins/folders/fs2.cpp        ListCurrentPath seam line
src/plugins/folders/lang/lang.rc2  "-\tShell Folders"
help/src/hh/salamand/{configuration_chdrv,navigating_chdrvmenu,windows_drivebar}.htm
```

**Structure Decision**: existing tree; one new header in `src/common/`.

## Complexity Tracking

None.
