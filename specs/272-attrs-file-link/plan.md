# Implementation Plan: Change Attributes on a file symbolic link changes the link, not its target file

**Branch**: `272-attrs-file-link` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/272-attrs-file-link/spec.md`

## Summary

Feature 253 decides in `DoChangeAttrs` (`src/worker.cpp`) whether an entry is a **directory** link
and then applies compression and times through `FILE_FLAG_OPEN_REPARSE_POINT` and refuses an
encryption change. This feature widens the same decision to every entry listed with
`FILE_ATTRIBUTE_REPARSE_POINT` - files too - using the same fail-closed rule (`DeleteAsDirLink`,
197: a link when the destination is read, the tag cannot be read or the tag is a name surrogate;
a readable non-surrogate tag - cloud placeholder, deduplicated file, third-party tag - is not a
link). For a file link the time handle opens with `FILE_FLAG_OPEN_REPARSE_POINT` (today 0) and the
compression helpers with `FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT` (measured to
reach the link itself); an encryption change is refused exactly as for a directory link. The pure
decisions in `src/common/salreparse.h` are widened, with `saltests` checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: Win32 (`CreateFileW` flags, `FSCTL_SET_COMPRESSION`, `SetFileTime`);
`DeleteAsDirLink` (`src/salamdr2.cpp`; works on a file entry - `GetReparsePointDestination` and
`GetReparsePointTag` open with `FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT`),
`src/common/salreparse.h` (header-only)
**Storage**: N/A
**Testing**: `saltests` (`TestAttrsLink253` adjusted, `TestAttrsFileLink272` new); hidden-desktop
probe `probe/attrs_flink272_probe.ps1` (COMP, UNCOMP, TIME, SUBC, PLAIN, NONLINK; ENC not driven);
regressions: 253's `attrs_link253_probe.ps1`, 213's `attrs_case_link_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core worker)
**Performance Goals**: one extra reparse query only for files listed with the reparse-point bit
**Constraints**: no new UI string; no plug-in interface change; Copy / Move callers of the four
helpers unchanged
**Scale/Scope**: `src/worker.cpp` (`DoChangeAttrs`), `src/common/salreparse.h`,
`src/saltests/saltests.cpp`

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency, no project change |
| II Backward compatibility | plain files and folders, directory links (253), non-surrogate reparse files and Copy / Move unchanged; file links: only the target file is no longer touched |
| III Incremental modernization | a pure decision in `src/common/` with `saltests` checks |
| IV Windows commitment | documented `FILE_FLAG_OPEN_REPARSE_POINT` semantics, measured on NTFS |
| V Plug-in architecture preservation | no plug-in or ABI change |
| VI UI consistency | the refusal uses the existing error dialog and texts |

Gate: PASS (pre- and post-design).

## Design

1. **`src/common/salreparse.h`** (feature 253 section, widened by 272):
   - `SalAttrsEntryIsDirLink` -> `SalAttrsEntryIsLink(DWORD listedAttr, BOOL linkByRule)`: TRUE
     for any entry listed with the reparse bit that the Delete rule takes for a link (the
     directory bit no longer required). The caller asks `DeleteAsDirLink` only when the reparse
     bit is set.
   - `SalAttrsOpenFlags(BOOL isDir, BOOL isLink)`: `(isDir ? FILE_FLAG_BACKUP_SEMANTICS : 0) |
     (isLink ? FILE_FLAG_OPEN_REPARSE_POINT : 0)` - for a non-link the old values (folder
     `FILE_FLAG_BACKUP_SEMANTICS`, file 0); a file link now `FILE_FLAG_OPEN_REPARSE_POINT`.
   - `SalAttrsLinkRefusesEncryption(BOOL isLink, ...)`: unchanged logic, the parameter now means
     any link.
2. **`src/worker.cpp` `DoChangeAttrs`**: `isLink = SalAttrsEntryIsLink(fileAttr, (fileAttr &
   FILE_ATTRIBUTE_REPARSE_POINT) && DeleteAsDirLink(name))`; passed to `UncompressFile` /
   `CompressFile` (`ownEntry` - `SalAttrsOpenFlags(TRUE, TRUE)` = backup semantics + open reparse
   point, measured on a file link), to the two `SalAttrsLinkRefusesEncryption` calls and to the
   time handle (`SalAttrsOpenFlags(isDir, isLink)`). `CompressFile` / `UncompressFile` comments
   name file links too. Copy / Move callers keep `ownEntry = FALSE`.
3. **`src/saltests/saltests.cpp`**: `TestAttrsLink253` - the two checks that pinned "a file link
   unchanged" now pin 272's rule; new `TestAttrsFileLink272` (file link, non-surrogate reparse
   file, hard-link-like plain file, open flags, encryption refusal).
4. **Probe** `probe/attrs_flink272_probe.ps1` (written while measuring): before COMP / UNCOMP /
   TIME / SUBC FAIL, after all PASS; PLAIN, NONLINK PASS before and after.

## Project Structure

```text
specs/272-attrs-file-link/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
└── probe/attrs_flink272_probe.ps1, result_before*.txt, result_after.txt
src/common/salreparse.h        (decision)
src/worker.cpp                 (DoChangeAttrs; comments of CompressFile / UncompressFile)
src/saltests/saltests.cpp      (checks)
```

No `contracts/`: no external interface changes (internal worker behaviour only).

## Complexity Tracking

None.
