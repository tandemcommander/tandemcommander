# Implementation Plan: ZIP leaves the archive and no stray file after a failed replace

**Branch**: `320-zip-failed-replace` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/320-zip-failed-replace/spec.md`

## Summary

The ZIP plug-in's two replace steps (`CZipPack::PackNormal` in `src/plugins/zip/add.cpp`,
`CZipPack::DeleteFromArchive` in `src/plugins/zip/add_del.cpp`) delete the archive and rename the
temporary working file over it; a failure leaves `Sal*.tmp` behind (measured) or the archive gone
(319). Both are replaced by one member `CZipPack::ReplaceArchiveWithTemp()` that calls the project's
rule `SalReplaceWithTempW` (`src/common/salsafereplace.h`, feature 105) and maps its four results:
done (attributes as before), kept (delete the temporary file, `IDS_ERRRESTORE`), left at temp (keep
it, name it, never "not changed"), both gone (an access error). No new string, no ABI change.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: Win32 (`ReplaceFileW`, `MoveFileExW`), header-only `salsafereplace.h`  
**Storage**: files - the user's archive and its temporary working file next to it  
**Testing**: `saltests` (new `TestSafeReplace320`: a stream target, a target held without / with
delete sharing, the replacement's last-write time and the target's named stream); GUI probe
`specs/320-zip-failed-replace/probe/zipreplace_probe.ps1` on the hidden desktop  
**Target Platform**: Windows 11+, x64  
**Project Type**: desktop application, plug-in DLL (`zip.spl`)  
**Performance Goals**: none (one rename at the end of an operation)  
**Constraints**: header-only shared rule (the ZIP project compiles no `src/common` `.cpp`); paths
UTF-8/WTF-8 converted with `SplU8ToWExtAlloc` (lossless, `\\?\` for long paths); no new UI string  
**Scale/Scope**: two call sites, one new member function, saltests checks, one probe

## Constitution Check

- I Build reproducibility: no new dependency, no project change (a header already in the tree,
  included by relative path as `salsamefile.h` and others are) - PASS.
- II Backward compatibility: plug-in ABI untouched; registry untouched; a successful replace gives
  the same archive; the failure paths become true - PASS.
- III Incremental modernization: replaces a two-step delete + rename with the tree's existing rule -
  PASS.
- IV Windows commitment: Win32 only - PASS.
- V Plug-in architecture: change inside one plug-in, no interface change - PASS.
- VI UI consistency: no new string; the existing message and error texts - PASS.

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/320-zip-failed-replace/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
├── probe/zipreplace_probe.ps1, result_*.txt
└── tasks.md
```

No `contracts/`: the change has no interface other plug-ins or the core rely on.

### Source Code (repository root)

```text
src/plugins/zip/add_del.h    # declare CZipPack::ReplaceArchiveWithTemp()
src/plugins/zip/add.cpp      # the member; PackNormal calls it
src/plugins/zip/add_del.cpp  # DeleteFromArchive calls it
src/saltests/saltests.cpp    # TestSafeReplace320
```

**Structure Decision**: the existing plug-in and test layout; no new file in `src/`.

## Complexity Tracking

None.
