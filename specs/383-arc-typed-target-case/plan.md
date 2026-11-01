# Implementation Plan: Copying into an archive folder typed in another case packs into that folder

**Branch**: `383-arc-typed-target-case` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/383-arc-typed-target-case/spec.md`

## Summary

F5 / F6 from a disk panel with a typed target `<archive>\<path>\` hands `<path>` to the
archive plug-in unchanged, so a path typed in another case than the archive spells its
folders packs into a new folder beside the existing one (measured 22 / 10 for 7z and ZIP).
The fix re-spells the typed root in the core right before `PackCompress` in
`src/fileswn8.cpp`: it takes the archive's listing (a panel's unchanged listing of the same
archive, else a fresh `PackList`), resolves the root with feature 382's
`CSalamanderDirectory::ResolvePathCase` (the rule the panel uses for the same typed path) and
lays the resolved names over the typed root with a new header-only helper
`SalArcPathApplyResolved` (`src/common/salarcpathspell.h`, saltests). Anything not resolvable
keeps the typed spelling.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI; the core's archive listing (`CSalamanderDirectory`, `PackList`)
**Storage**: N/A (no configuration change)
**Testing**: `saltests` (pure helper), hidden-desktop probe `probe/arctarget383_probe.ps1`
(7z / ZIP rows), regression probes of 273 and 382
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core change only, no plug-in change)
**Performance Goals**: one archive listing per Copy / Move into a typed archive root, skipped
when a panel holds an unchanged listing of the same archive
**Constraints**: never cut a path; no new UI string; plug-in ABI untouched
**Scale/Scope**: one site (`CFilesWindow::FilesAction`, archive branch), one helper, one test

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency, no project change (header-only helper) - PASS |
| II. Backward compatibility | exact names, twins and unresolvable paths pack as before; no stored data, no plug-in API change - PASS |
| III. Incremental modernization | reuses 273 / 382 rule; pure part in `src/common/` with saltests - PASS |
| IV. Windows commitment | unchanged - PASS |
| V. Plugin architecture | plug-ins get the root they would get through the panel already - PASS |
| VI. UI consistency | no new dialog or string; the existing "listing archive" wait window - PASS |

Re-check after design: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/383-arc-typed-target-case/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/arctarget383_probe.ps1, result_before.txt, result_after.txt
```

### Source Code

```text
src/common/salarcpathspell.h   # + SalArcPathApplyResolved (pure, header-only)
src/fileswn8.cpp               # archive branch of FilesAction: re-spell the typed root before PackCompress
src/saltests/saltests.cpp      # + TestArcPathApplyResolved383
```

**Structure Decision**: core only; no contract (no interface other code relies on changes).

## Design

1. `SalArcPathApplyResolved(char* typed, const char* resolved)`: `typed` = the root as typed
   (optional leading / trailing `\`); `resolved` = `ResolvePathCase`'s output (no leading /
   trailing `\`). When `resolved` has exactly the length of `typed` without those separators,
   its bytes replace that part in place and TRUE is returned when anything changed; otherwise
   `typed` is left alone (FALSE). Never writes past `typed`'s own length.
2. In `fileswn8.cpp`, archive branch, after the zero-size check (`haveSize`, `!nullFile`) and
   only when `hasPath`: a static helper `RespellTypedArchiveRoot(path, root, rootSize)`:
   - a panel (`MainWindow->LeftPanel` / `RightPanel`) that `Is(ptZIPArchive)` with
     `SalPathEqualOrdinalCI(GetZIPArchive(), path)` and whose `GetZIPArchiveDate()` /
     `IsSameZIPArchiveSize()` equal the file's now (read with `SalCreateFile` +
     `GetFileTime` / `SalGetFileSize`) and not `ArchiveNameLeadsElsewhere` → its `GetArchiveDir()`;
   - else `PackList` into a new `CSalamanderDirectory(FALSE)` with the add cache and the
     "listing archive" safe wait window (as `salshlib.cpp`); afterwards the plug-in data and the
     listing released as `salamdr3.cpp` does (only after a successful listing);
   - `ResolvePathCase(root, resolved, MAX_PATH)` → `SalArcPathApplyResolved(root, resolved)`.
   The re-spelled copy (`char packRoot[MAX_PATH]`) is passed to `PackCompress`; `path` /
   `secondPart` stay as typed (the error path that returns to the dialog restores the typed
   text, the history keeps it).
3. The listing is taken before `SetCurrentDirectory(GetPath())` / the thread priority change so
   the existing order of the pack is unchanged.

## Complexity Tracking

None.
