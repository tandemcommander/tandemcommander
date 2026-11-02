# Implementation Plan: ZIP updates an archive reached through a symbolic link

**Branch**: `399-zip-symlink-archive` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/399-zip-symlink-archive/spec.md`

## Summary

When the archive's name is a file symbolic link, the ZIP plug-in makes its temporary working file next
to the link and the one-step replace onto the link fails (1464). The plug-in will resolve the name
once the archive is open: when the name itself is a name-surrogate reparse point (a file symbolic
link), the *replace target* becomes the opened file's final path (links resolved, `\\?\` removed);
the temporary file is made in that folder and replaces that file; the attributes restored afterwards
are that file's. Everything else (messages, other names, in-place mode) stays as it is. The pure part
(which name is followed; cleaning the final path) goes into the header-only `salsafereplace.h` with
`saltests` checks; one I/O helper there reads the reparse tag and the final path.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: Win32 (`FindFirstFileW` for the reparse tag, `GetFinalPathNameByHandleW`, `ReplaceFileW` through `SalReplaceWithTempW`)  
**Storage**: files (the user's archive)  
**Testing**: `saltests` (pure rule + a real link replace under `%TEMP%`), hidden-desktop probe `probe/zipsymlink_probe.ps1`  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (ZIP, `src/plugins/zip/`)  
**Performance Goals**: one extra `FindFirstFileW` per update with the backup option; one `GetFinalPathNameByHandleW` only for a link  
**Constraints**: header-only shared code (the ZIP plug-in cannot compile a `.cpp` of `src/common`); UTF-8 (WTF-8) names; a path is never cut; no new UI string  
**Scale/Scope**: two call sites (`PackNormal`, `DeleteFromArchive`) through `CreateTempFile` / `ReplaceArchiveWithTemp`

## Constitution Check

- I Build reproducibility: no new dependency, no project change - PASS.
- II Backward compatibility (0.1.0 baseline): plain archives, hard links, junction paths, in-place mode
  unchanged; no registry, no plug-in ABI change - PASS.
- III Incremental modernization: a local change at the replace site; the shared helper gains functions,
  existing ones unchanged - PASS.
- IV Windows commitment: Win32 only - PASS.
- V Plug-in architecture preservation: no `spl_*.h` change - PASS.
- VI UI consistency: no new text, no dialog change - PASS.
- Data safety (CLAUDE.md): the replace stays `SalReplaceWithTempW` (temporary file + one step); the
  link is never deleted or rewritten; a failure keeps the archive (FR-003) - PASS.

Re-check after Phase 1: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/399-zip-symlink-archive/
├── plan.md  research.md  data-model.md  quickstart.md  fix-log.md
├── probe/zipsymlink_probe.ps1, result_*.txt
└── tasks.md
```

No `contracts/`: the change is internal to the ZIP plug-in; the header functions are a shared rule,
not a plug-in interface.

### Source Code

```text
src/common/salsafereplace.h     + SalReplaceFollowsName (pure), SalFinalPathPlainW (pure),
                                  SalReplaceTargetOfLinkW (I/O: tag + final path of the open handle)
src/saltests/saltests.cpp       + TestSafeReplace399 (pure rows; a real file link replace, skipped
                                  with a printed line when links cannot be made)
src/plugins/zip/add_del.h       + char* ReplaceTarget (UTF-8, heap; NULL = ZipName itself)
src/plugins/zip/add_del.cpp     constructor / destructor: ReplaceTarget
src/plugins/zip/add.cpp         CreateTempFile: resolve once (ZipFile open) -> the temporary file's
                                  folder and ZipAttr from the real archive;
                                  ReplaceArchiveWithTemp: replace / attributes / time on the target
```

**Structure Decision**: the existing core + plug-in layout; the rule in the shared header.

## Complexity Tracking

None.
