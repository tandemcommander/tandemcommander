# Implementation Plan: The Change Drive menu and the drive bar offer the WSL distributions

**Branch**: `374-wsl-drive-item` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/374-wsl-drive-item/spec.md`

## Summary

Add WSL distributions to the Change Drive menu and the drive bar, following the OneDrive
pattern: one menu item `Linux - <distribution>` per installed distribution (read from the
per-user `Lxss` registry key only), opening `\\wsl.localhost\<distribution>` through the
ordinary disk path change; on the drive bar one button (one distribution) or one drop-down
button (several). A new option on the Change Drive configuration page (default on) hides them.
Pure rules (usable name, path, "path is on this distribution", sort, fingerprint) in a new
header `src/common/salwsl.h` with `saltests` checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI only (`RegOpenKeyExW` / `RegEnumKeyExW` / `RegQueryValueExW`,
`SHDefExtractIconW` for the icon of `System32\wsl.exe`)
**Storage**: one new DWORD `Change Drive Show WSL` under the existing `Configuration` key
**Testing**: `saltests` (pure rules); GUI probe `specs/374-wsl-drive-item/probe/wsl374_probe.ps1`
on the hidden desktop with the Debug seam `TC_PROBE_DRIVES_DUMP` (246/289) extended
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core module `salamand`)
**Performance Goals**: the WSL part of the list build < 10 ms (SC-004)
**Constraints**: never start WSL while building the list; UTF-8 (WTF-8) names in the core; never
cut a path (an unusable or too long name is left out)
**Scale/Scope**: ~8 core files, one header, one dialog resource, two strings

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency; vendored only - PASS |
| II Backward compatibility (0.1.0) | new item types appended at the end of `CDriveTypeEnum` (existing numbers kept); new configuration value absent = default on; no change to existing values - PASS |
| III Incremental modernization | pure rules in a header with tests - PASS |
| IV Windows commitment | WinAPI, Windows 11 `\\wsl.localhost` - PASS |
| V Plugin architecture | no plug-in interface change - PASS |
| VI UI consistency | the OneDrive pattern, the checkbox among the other Additional items, translated texts - PASS |

## Project Structure

### Documentation (this feature)

```text
specs/374-wsl-drive-item/
├── plan.md  research.md  data-model.md  quickstart.md  fix-log.md
├── contracts/probe-seam.md
├── probe/wsl374_probe.ps1 (+ results)
└── tasks.md
```

### Source Code

```text
src/common/salwsl.h          new: pure rules (+ saltests in src/saltests/saltests.cpp)
src/drivelst.h / .cpp        drvtWSL, drvtWSLMenu; list of distributions; BuildData; ExecuteItem;
                             IncludeDriveInDriveBar; FillDriveBar; tooltips; context menu; focus;
                             cloud mask fingerprint; probe lines
src/fileswn3.cpp             CFilesWindow::ChangeDrive: drvtWSL -> ChangePathToDisk
src/toolbar6.cpp             CDriveBar::Execute: drvtWSL -> ChangePathToDisk
src/cfgdlg.h, dialogs4.cpp, dialogs5.cpp, mainwnd2.cpp   option ChangeDriveShowWSL
src/lang/lang.rc, lang.rh    checkbox IDC_CHD_SHOWWSL on IDD_CFGPAGE_CHANGEDRIVE
src/texts.rh2, src/lang/texts.rc2   IDS_WSLLINUX (14169) "Linux"
translations/*/salamand.slt (+ .origin)  two-stage refresh
```

## Design

1. **Reading the distributions** (`GetWslDistributions`, drivelst.cpp): open
   `HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss` (`KEY_READ`), enumerate subkeys, read
   `DistributionName` (REG_SZ, wide) and `State` (DWORD, optional); keep those with
   `SalWslDistroUsableW` and state absent or 1; convert to UTF-8 (`SalWToU8Alloc`); sort with
   `SalNameOrderCompareCI`; drop exact duplicates. No other access (no WSL API, no file system
   access to `\\wsl.localhost`).
2. **Building** (`BuildData`, after the cloud storages, before Network), when
   `Configuration.ChangeDriveShowWSL`: the names are kept in a list member of `CDrivesList`
   (`WslDistros`); the icon is `SHDefExtractIconW(<system dir>\wsl.exe, 0)` at the 16 px DPI
   size (registered with `HANDLES_ADD`), else the Network icon. Drive bar with several
   distributions: one `drvtWSLMenu` item (text "Linux"); otherwise one `drvtWSL` item per name,
   `Param` = its index, text `Linux - <name>`. `CachedCloudStoragesMask` gets
   `0x20 | (fingerprint << 8)` when at least one distribution is listed, so the drive bars are
   rebuilt when the set changes (FR-008).
3. **Executing**: `ExecuteItem` - `drvtWSL`: `*DriveTypeParam = DupStr(name)`; `drvtWSLMenu`:
   re-read the distributions, track a `CMenuPopup` of `Linux - <name>` items, on a choice
   `*DriveType = drvtWSL`, param = `DupStr(name)`; nothing listed any more -> post
   `WM_USER_DRIVES_CHANGE`, FALSE. `ChangeDrive` / `CDriveBar::Execute`: `drvtWSL` -> build the
   path with `SalWslDistroPathU8` (refuse if it does not fit), `ChangePathToDisk`, free the
   param.
4. **Focus** (FR-006): when the panel's path is on a distribution (`SalWslPathOnDistroU8`), its
   item becomes `FocusIndex` (before the Network fallback); on the drive bar
   `FindPanelPathIndex` gives the WSL button.
5. **Other switches**: `IncludeDriveInDriveBar` (+2 types), `FillDriveBar` (no text, drop-down
   style for the menu type), `GetDriveBarToolTip` (`Linux - <name>` / "Linux"), `OnContextMenu`
   (no context menu, as the cloud storages), `ChangeDrive` / `Execute` unexpected
   `drvtWSLMenu` trace.
6. **Option**: `ChangeDriveShowWSL` (cfgdlg.h), default TRUE (dialogs4.cpp), registry value
   `Change Drive Show WSL` saved and loaded (mainwnd2.cpp), checkbox `IDC_CHD_SHOWWSL`
   "&Linux Distributions (WSL)" between Cloud Storage Services and Network (lang.rc; the group
   box grows by 13 units, the line below moves down).
7. **Settings import**: the import of feature 245 reads Altap / Open Salamander settings only,
   which have no such value, and its rule FR-016 keeps Tandem Commander's own settings off its
   allow-list (saltests counts 112 entries) - so the new option is **not** added to
   `cfgimport.cpp`; the program's own export / import (a `.reg` of the whole key) carries it
   with no change. Recorded as a deviation from the item's "imported like ChangeDriveShowNet".
8. **Probe seam**: `BuildData` dumps `WSL count=<n> ms=<t> fp=<hex>` (the WSL part's time) and
   `TIME build=<ms>`; the `ALL` lines carry the new items (types 19 `drvtWSL`, 20 `drvtWSLMenu`).

## Complexity Tracking

None.
