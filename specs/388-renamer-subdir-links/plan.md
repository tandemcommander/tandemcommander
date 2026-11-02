# Implementation Plan: Renamer "Include subdirectories" never descends into a junction or folder link

**Branch**: `388-renamer-subdir-links` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/388-renamer-subdir-links/spec.md`

## Summary

The Renamer's listing with "Include subdirectories" (`CRenamerDialog::ReloadSourceFiles` →
`LoadSubdir`, `src/plugins/renamer/rendlg.cpp`) walks every directory, links included. A pure rule
`SalListedDirIsLink` (new, in `src/common/salreparse.h`, built on feature 197's
`SalDeleteAsDirLinkDecision`) decides from the listed attributes and the reparse tag that the
listing already returns whether a directory is a link. A link is never walked; it becomes an item
of its own (folder, no extension, the mask applied), both when found by `LoadSubdir` and when it
is the selected panel item itself (feature 213's treatment in the core).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: WinAPI (`FindFirstFileW`), the plug-in interface (`SG->...`), header-only rules from `src/common/`  
**Storage**: N/A  
**Testing**: `saltests` (the new rule), hidden-desktop probe `probe/ren_link_probe.ps1`  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (`renamer.spl`)  
**Performance Goals**: no extra system call per listed entry (the tag comes with the listing); one `FindFirstFileW` per selected item only when its panel attributes carry the reparse bit  
**Constraints**: UTF-8 / WTF-8 names (`SplU8ToWExtAlloc`, `SplWToU8`); never cut a path (existing `IDS_TOOLONGPATH` refusal); no new UI string; plug-in ABI untouched  
**Scale/Scope**: 4 files: `salreparse.h`, `saltests.cpp`, `renamer/rendlg.cpp`, `renamer/crenamer.{h,cpp}`

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency; header-only rule; `build.cmd` unchanged - PASS |
| II. Backward compatibility | plain folders and non-link reparse folders walked as before; no setting or registry value changes; the plug-in interface is untouched - PASS |
| III. Incremental modernization | a local fix at the one recursive site; the rule shared with the core - PASS |
| IV. Windows commitment | WinAPI reparse tags - PASS |
| V. Plug-in architecture | the plug-in includes a header-only rule from `src/common/` (as `salnameorder.h`, `salsamefile.h`), no new export, no `spl_*.h` change - PASS |
| VI. UI consistency | no new UI; the link shown as a folder row as in the non-recursive mode - PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/388-renamer-subdir-links/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
├── probe/ren_link_probe.ps1 (+ result_*.txt)
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salreparse.h               # + SalListedDirIsLink (pure rule)
src/saltests/saltests.cpp             # + TestListedDirIsLink388
src/plugins/renamer/crenamer.h/.cpp   # CSourceFile(WIN32_FIND_DATAW&, ...) gets an isDir argument (default FALSE)
src/plugins/renamer/rendlg.cpp        # ReloadSourceFiles: a selected link is listed; LoadSubdir: a found link is listed, not walked; count of folders
```

**Structure Decision**: existing layout; no new project or file besides the probe.

## Complexity Tracking

None.
