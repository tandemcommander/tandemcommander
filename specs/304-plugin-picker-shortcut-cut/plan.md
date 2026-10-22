# Implementation Plan: Plug-in folder picker never cuts a folder shortcut's target

**Branch**: `304-plugin-picker-shortcut-cut` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/304-plugin-picker-shortcut-cut/spec.md`

## Summary

`SplFileDlgDetail::ResolveNetHoodFolderW` (`src/plugins/shared/splfiledlg.h`) takes the target of
a picked folder shortcut from `IShellLinkW::GetPath`, which - measured - answers NOERROR with a
path cut at 259 units on a drive without 8.3 names, whatever the buffer size. The fix reads the
answer into a 32,768-unit buffer and, for an answer of 259 units or more, proves it whole from the
link's item list (`GetIDList` + `SHGetNameFromIDList(SIGDN_FILESYSPATH)`, plain form): equal or
extended by it → the whole item-list name; otherwise refused. The pure decision is a new
header-only function in the same header with saltests checks; `SplBrowseForFolderU8` shows the
existing "too long" message on a refusal.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI shell (`IShellLinkW`, `SHGetNameFromIDList`, `CompareStringOrdinal`) - Windows 7+ (`_WIN32_WINNT=0x0601`)
**Storage**: N/A
**Testing**: `saltests` (pure rule + end-to-end with real folder shortcuts); the measurement programs in `probe/`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, header-only helper compiled into plug-ins (PictView, UnCAB, Undelete) and saltests
**Performance Goals**: N/A (one shortcut read per pick; the item list is read only for answers of 259+ units)
**Constraints**: header-only (plug-ins cannot compile `src/common` `.cpp`); no new UI strings; plug-in interface unchanged
**Scale/Scope**: one header function changed, one added; saltests checks

## Constitution Check

| Principle | Status |
|---|---|
| I. Build reproducibility | Pass - no new dependency; shell32 / kernel32 already linked |
| II. Backward compatibility | Pass - every answer under 259 units unchanged; plug-in ABI (`spl_*.h`, interface version) untouched; `ResolveNetHoodFolderW` gains a defaulted out parameter (existing calls compile) |
| III. Incremental modernization | Pass - a local fix in one helper |
| IV. Windows commitment | Pass - WinAPI only |
| V. Plugin architecture preservation | Pass - no plug-in source or interface change |
| VI. UI consistency | Pass - the existing "too long" message |

Re-check after design: unchanged (Pass).

## Project Structure

### Documentation (this feature)

```text
specs/304-plugin-picker-shortcut-cut/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/folder-shortcut-target.md
├── probe/measure*.cpp        # the measurement programs
├── fix-log.md
└── tasks.md
```

### Source Code (repository root)

```text
src/plugins/shared/splfiledlg.h   # WholeFolderShortcutTargetW (new, pure), ResolveNetHoodFolderW, SplBrowseForFolderU8
src/saltests/saltests.cpp         # pure-rule checks + end-to-end folder shortcuts with a long target
```

**Structure Decision**: the rule stays in `splfiledlg.h` next to its only consumer (the plug-ins'
twin of the core's rule, as `IsFolderShortcutIni`); saltests already includes the header.

## Complexity Tracking

None.
