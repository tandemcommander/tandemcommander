# Implementation Plan: Shift+F6 renames the focused item in place

**Branch**: `346-shift-f6-inplace-rename` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/346-shift-f6-inplace-rename/spec.md`

## Summary

Give the existing in-place rename editor (Quick Rename window, `CFilesWindow::QuickRenameBegin`)
a keyboard entry: Shift+F6 in a panel and a new Files menu command *Rename in Place*. Both go
through one new command `CM_QUICKRENAMEINPLACE`; its handler revives the commented-out
`QuickRenameOnIndex` (bring the caret item into view, compute its label rectangle with
`CFilesBox::GetItemRect` + `GetIndex(..., &labelRect)`, store `QuickRenameIndex` /
`QuickRenameRect`, call `QuickRenameBegin`). The key is recognised in the panel's key handler
**after** plug-in hot keys (the plug-ins keep their place in front of panel keys);
`IsSalHotKey` reserves Shift+F6 for new bindings and `IsSalHotKeyKeptAtLoad` keeps an old one.
The key predicate is a pure header with `saltests` checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: WinAPI only  
**Storage**: N/A (no configuration added)  
**Testing**: `saltests` (pure key predicate), hidden-desktop GUI probe `rip346_probe.ps1`  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application (core module `salamand`)  
**Performance Goals**: N/A  
**Constraints**: plug-in ABI untouched; translations refreshed for the one new menu string  
**Scale/Scope**: ~8 source files, 1 UI string, 2 help pages

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | No new dependency; `build.cmd full` must stay green (new string refreshed in all enabled `.slt`) |
| II Backward compatibility | No key changes meaning; F2 / F6 / Ctrl+F6 / Alt+F6 / Ctrl+Shift+F6 untouched; existing plug-in Shift+F6 bindings kept (not erased) - they never ran from the key, see research R1; no registry change |
| III Incremental modernization | Reuses the existing editor; revives the upstream keyboard entry point |
| IV Windows commitment | WinAPI only |
| V Plugin architecture | No `spl_*.h` change; plug-in FS goes through the unchanged `QuickRename` modes 1/2 |
| VI UI consistency | Menu text with tab-separated shortcut like its neighbours; help pages updated |

Gate: PASS (no violations).

## Project Structure

### Documentation (this feature)

```text
specs/346-shift-f6-inplace-rename/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/keyboard-and-menu.md
├── fix-log.md, closing-report.md
├── probe/rip346_probe.ps1 (+ results)
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salrenamekey.h      # new: pure predicate "Shift+F6 = rename in place" (+ hot-key form)
src/tests/ (saltests)          # checks of the predicate
src/resource.rh2               # CM_QUICKRENAMEINPLACE 2954
src/texts.rh2, src/lang/texts.rc2   # IDS_MENU_FILES_RENAMEINPLACE 13019 "Rename in Place\tShift+F6"
src/menu4.cpp                  # Files menu row after Quick Rename
src/fileswnd.h, src/fileswn5.cpp    # QuickRenameOnIndex revived
src/fileswn0.cpp               # OnSysKeyDown: after Plugins.HandleKeyDown, post the command
src/mainwnd3.cpp               # WM_COMMAND case
src/keyboard.cpp               # IsSalHotKey VK_F6 + SHIFT; IsSalHotKeyKeptAtLoad Shift+F6
help/src/hh/salamand/shortcuts_keyboard.htm, advwork_rename.htm
translations/*/salamand.slt    # two-stage refresh
CHANGELOG.md                   # [Unreleased] entry
```

**Structure Decision**: core module only; the pure rule in `src/common/` per the working method.

## Complexity Tracking

None.
