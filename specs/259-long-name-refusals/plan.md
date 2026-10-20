# Implementation Plan: Long names - Paste copy name, Edit New File, simple-selection conversion

**Branch**: `259-long-name-refusals` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/259-long-name-refusals/spec.md`

## Summary

Three core sites refuse valid work or would act on a wrong name when a name or path is long:

1. `CFilesWindow::BuildScriptMain2` (fileswn6.cpp) builds the Paste copy name in a 260-byte window
   and silently drops it - the copy then targets its source ("to itself"). The Explorer-style
   rule moves into a header-only rule `src/common/salcopyname.h` (`SalMakeCopyNameU8`) that
   builds the candidate whole and says when it exceeds 255 UTF-16 units; the caller then shows
   BuildName's existing "name is too long" question (Skip / Skip all / Focus / Cancel).
2. `CFilesWindow::EditNewFile` (fileswn5.cpp) refuses any path of 260+ bytes: the 141 guard and
   `SalGetFullName`'s default `nameBufSize` (MAX_PATH). It takes `SAL_MAX_PATH_UTF8` as Create
   Directory does (feature 027); `checkPath` grows to the same size.
3. `IsSimpleSelection` (shellib.cpp) loses its `CP_ACP` / raw-byte / cutting fallbacks: a failed
   conversion refuses the selection; a common folder too long for `SrcPath` sets the new
   `CDragDropOperData::SrcPathTooLong`, and `DragDropToArcOrFS` says "The path specified is too
   long." instead of the Unicode message.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI only; existing helpers `SalNameTooLongForFileSystemU8`
(salmaskname.h), `BuildName` (salamdr1.cpp), `SalGetFullName`, `SalWToU8Alloc`
**Storage**: N/A (no registry or file format change)
**Testing**: `saltests` (new `TestCopyName259`), hidden-desktop probe `probe/editnew259_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand`)
**Performance Goals**: N/A (one name per pasted item)
**Constraints**: no new UI string (no `.slt` refresh); no plug-in ABI change (`CDragDropOperData`
is core-only, `shellib.h`); never cut a path or name
**Scale/Scope**: three functions, one new header, one struct field

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency; header-only rule listed in saltests.vcxproj |
| II. Backward compatibility | names that fit behave as before (the rule is a faithful port); no stored data changes |
| III. Incremental modernization | only the three sites; the pre-Vista copy patterns stay (only their "drop the result" becomes "too long") |
| IV. Windows commitment | WinAPI only |
| V. Plugin architecture | no plug-in interface touched |
| VI. UI consistency | existing messages and the existing Skip / Skip all / Focus question |

Gate: PASS (no violation). Re-checked after design: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/259-long-name-refusals/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
├── contracts/copy-name-rule.md
└── probe/editnew259_probe.ps1 (+ result_*.txt)
```

### Source Code (repository root)

```text
src/common/salcopyname.h          new: SalMakeCopyNameU8 (header-only)
src/fileswn6.cpp                  BuildScriptMain2: uses it; too long -> BuildName question
src/fileswn5.cpp                  EditNewFile: long paths
src/shellib.h / shellib.cpp       CDragDropOperData::SrcPathTooLong; IsSimpleSelection fallbacks
src/fileswna.cpp                  DragDropToArcOrFS: the too-long message
src/saltests/saltests.cpp         TestCopyName259
src/vcxproj/saltests/saltests.vcxproj   the header listed (as salcasetwins.h)
```

**Structure Decision**: core only; the pure rule in `src/common/` per CLAUDE.md working method.

## Complexity Tracking

None.
