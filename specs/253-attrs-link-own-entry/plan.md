# Implementation Plan: Change Attributes on a junction changes the junction, not its target folder

**Branch**: `253-attrs-link-own-entry` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/253-attrs-link-own-entry/spec.md`

## Summary

`DoChangeAttrs` (`src/worker.cpp`) decides once per entry whether it is a directory link - the
entry's listed attributes hold `FILE_ATTRIBUTE_DIRECTORY` and `FILE_ATTRIBUTE_REPARSE_POINT` and
`DeleteAsDirLink` (197 / 213, fail closed) takes it for a link. For such an entry the compression
(`CompressFile` / `UncompressFile`) and the times are applied through a handle opened with
`FILE_FLAG_OPEN_REPARSE_POINT` - the link's own entry (measured to work on NTFS); an encryption
change (set or clear, only when the link's state differs from the request) is refused with
`ERROR_NOT_SUPPORTED` under the existing `IDS_ERRORENCRYPTING` error dialog, because
`EncryptFileW` / `DecryptFileW` cannot stay on a link. The decisions are pure inline functions in
`src/common/salreparse.h` with `saltests` checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: Win32 (`CreateFileW` flags, `FSCTL_SET_COMPRESSION`, `SetFileTime`);
`DeleteAsDirLink` (`src/salamdr2.cpp`), `src/common/salreparse.h` (header-only, feature 197)
**Storage**: N/A
**Testing**: `saltests` (the decision); hidden-desktop probe `probe/attrs_link253_probe.ps1`
(rows COMP, UNCOMP, TIME, SUBC, PLAIN; ENC not driven); regression: 213's
`attrs_case_link_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core worker)
**Performance Goals**: one extra reparse query only for entries listed as reparse-point folders
**Constraints**: no new UI string (the `.slt` refresh is not done in a run); no plug-in interface
change; the copy / move callers of the four helpers unchanged
**Scale/Scope**: `src/worker.cpp` (three functions), `src/common/salreparse.h`,
`src/saltests/saltests.cpp`

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency, no project change |
| II Backward compatibility | plain folders, files, cloud placeholders, file symbolic links and Copy / Move unchanged; links: only the target folder is no longer touched |
| III Incremental modernization | a pure decision in `src/common/` with `saltests` checks |
| IV Windows commitment | documented `FILE_FLAG_OPEN_REPARSE_POINT` semantics |
| V Plug-in architecture preservation | no plug-in or ABI change |
| VI UI consistency | the refusal uses the existing error dialog and texts |

Gate: PASS (pre- and post-design).

## Design

1. **`src/common/salreparse.h`** - feature 253 section:
   - `SalAttrsEntryIsDirLink(DWORD listedAttr, BOOL deleteAsDirLink)` - TRUE for a folder with the
     reparse bit that the Delete rule takes for a link. (The caller asks `DeleteAsDirLink` only when
     both bits are set.)
   - `SalAttrsOpenFlags(BOOL isDir, BOOL isDirLink)` - `FILE_FLAG_BACKUP_SEMANTICS` for a folder,
     plus `FILE_FLAG_OPEN_REPARSE_POINT` for a directory link; 0 for a file.
   - `SalAttrsLinkRefusesEncryption(BOOL isDirLink, BOOL changeEncryption, DWORD listedAttr,
     DWORD wantedAttr)` - TRUE when a directory link's encryption state would change.
2. **`src/worker.cpp`**:
   - `CompressFile` / `UncompressFile` get a trailing `BOOL ownEntry = FALSE`; the `SalCreateFile`
     flags become `SalAttrsOpenFlags(TRUE, ownEntry)` (today `FILE_FLAG_BACKUP_SEMANTICS` for
     every call - files open fine with it, so the value stays identical when `ownEntry` is FALSE).
     The copy / move callers keep the default.
   - `DoChangeAttrs`: before the retry loop `isDirLink = (fileAttr & DIRECTORY) && (fileAttr &
     REPARSE_POINT) && DeleteAsDirLink(name)` through `SalAttrsEntryIsDirLink`; `refuseCrypt =
     SalAttrsLinkRefusesEncryption(...)`. Uncompress / compress pass `isDirLink`; the decrypt and
     encrypt branches set `error = ERROR_NOT_SUPPORTED` (title `IDS_ERRORENCRYPTING`) instead of
     calling `MyDecryptFile` / `MyEncryptFile` when `refuseCrypt`; the time handle uses
     `SalAttrsOpenFlags(isDir, isDirLink)`.
   - `ERROR_NOT_SUPPORTED` is not `ERROR_INVALID_FUNCTION`, so the refusal goes through the
     ordinary Retry / Skip / Skip all / Cancel error, never through the "not supported on this
     volume" branch that switches encryption off for the rest of the operation.
3. **`src/saltests/saltests.cpp`** - `TestAttrsLink253()`.
4. **Probe** `probe/attrs_link253_probe.ps1` (written during measuring): before 4 FAIL, after all
   PASS; 213's probe as regression.

## Project Structure

```text
specs/253-attrs-link-own-entry/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
└── probe/attrs_link253_probe.ps1, result_before.txt, result_after.txt
src/common/salreparse.h        (decision)
src/worker.cpp                 (CompressFile, UncompressFile, DoChangeAttrs)
src/saltests/saltests.cpp      (checks)
```

No `contracts/`: no external interface changes (internal worker behaviour only).

## Complexity Tracking

None.
