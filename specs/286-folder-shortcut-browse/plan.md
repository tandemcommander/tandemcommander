# Implementation Plan: A folder picked in Browse is handed back whole or refused - also a folder shortcut's target

**Branch**: `286-folder-shortcut-browse` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/286-folder-shortcut-browse/spec.md`

## Summary

`GetTargetDirectory` (`src/shellib.cpp`) hands its callers a picked folder in a `MAX_PATH`-byte
buffer. Two defects: (1) a picked folder whose UTF-8 path does not fit is replaced by the
code-page form (`SalSHGetPathFromIDListU8`'s `A` fallback) and returned as picked; (2) a picked
folder shortcut whose target does not fit is silently not followed (`ResolveNetHoodPath`), and its
`MAX_PATH` name buffers can make a folder shortcut near the limit go unrecognised. Fix: the
helper returns the full Unicode path or nothing (with a "too long" flag, no code-page fallback);
the folder-shortcut rule moves into a header (`salshelllink.h`: `SalIsFolderShortcutIni`,
`SalFolderShortcutTargetU8`) that reads the target whole into a heap buffer and reports "too
long" separately; `GetTargetDirectory` shows `IDS_TOOLONGPATH` and returns FALSE for both, and
writes `path` only on success.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: Win32 shell (`SHBrowseForFolder`, `SHGetPathFromIDListW`, `IShellLinkW`, `IPersistFile`)
**Storage**: N/A (reads `desktop.ini` / `target.lnk` of the picked folder; writes nothing)
**Testing**: `saltests` (real folder shortcuts in `%TEMP%`), hidden-desktop probe `fsc286_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand`)
**Performance Goals**: none new (the folder-shortcut read happens once per Browse OK, as before)
**Constraints**: plug-in interface unchanged (`GetTargetDirectory`, buffer >= `MAX_PATH`); no new UI string
**Scale/Scope**: 2 files of the core (`shellib.cpp`, `shellib.h`), 1 header (`src/common/salshelllink.h`), `saltests.cpp`

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency; vendored only - PASS |
| II. Backward compatibility | plug-in interface and its frozen code-page result unchanged; configuration unchanged - PASS |
| III. Incremental modernization | targeted fix of one routine; the rule in a testable header - PASS |
| IV. Windows commitment | Win32 only - PASS |
| V. Plug-in architecture | `spl_*.h` untouched; plug-ins see FALSE (nothing picked) on a refusal, as on Cancel - PASS |
| VI. UI consistency | the existing message "The path specified is too long." with the error title, as other refusals - PASS |

Re-check after design: PASS (no change).

## Project Structure

### Documentation (this feature)

```text
specs/286-folder-shortcut-browse/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/folder-shortcut-target.md
├── checklists/requirements.md
├── probe/fsc286_probe.ps1, result_before.txt, result_after.txt
├── fix-log.md, closing-report.md
```

### Source Code

```text
src/common/salshelllink.h   + SalIsFolderShortcutIni, SalFolderShortcutTargetU8 (header-only rule)
src/shellib.cpp             SalSHGetPathFromIDListU8 (no code-page fallback, tooLong out),
                            DirectoryBrowse (OK enabled for a too-long file-system folder),
                            GetTargetDirectoryAux (local buffer, tooLong out),
                            ResolveNetHoodPath (returns FALSE = target too long; uses the header),
                            GetTargetDirectory (message + FALSE)
src/shellib.h               ResolveNetHoodPath returns BOOL; GetTargetDirectoryAux not exported (unchanged)
src/saltests/saltests.cpp   TestFolderShortcut286
```

**Structure Decision**: core + `src/common` header + `saltests`, as features 128 / 194.

## Complexity Tracking

None.
