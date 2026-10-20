# Implementation Plan: 7-Zip, TAR and SFTP listings declare case sensitivity

**Branch**: `252-archive-case-sensitivity` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/252-archive-case-sensitivity/spec.md`

## Summary

7-Zip and TAR listings are built case-sensitively (`SALDIRFLAG_CASESENSITIVE` set before the first
item is added); when the listing is complete a header-only rule walks the built tree and, if no
folder holds two names that differ only in case, the flag is cleared again - the listing is then
exactly the case-insensitive one of today. A listing with such "case twins" stays case-sensitive,
so the core's paste lookup, selection lists and tree building tell the twins apart. SFTP listings
always declare `SALDIRFLAG_CASESENSITIVE` (as FTP's do).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: plug-in API (`spl_com.h`, unchanged), `src/common/salnameorder.h`
(header-only name rules, feature 115)
**Storage**: N/A
**Testing**: `saltests` (the pure rule, with a fake directory tree); hidden-desktop probe
`probe/arc252_probe.ps1` (TAR and 7z fixtures)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application + plug-ins
**Performance Goals**: no second read of the archive; the check sorts the names of each folder
(two `qsort`s per folder)
**Constraints**: plug-in ABI append-only - no interface change; header-only code for plug-ins
**Scale/Scope**: three plug-ins (7zip, tar, sftp), one new header in `src/common/`

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency; header-only code; `build.cmd` unchanged |
| II Backward compatibility | archives without case twins behave exactly as before; no ABI change; SFTP follows FTP's existing declaration |
| III Incremental modernization | a pure rule in `src/common/` with `saltests` checks |
| IV Windows commitment | uses `CompareStringOrdinal` / `CharLowerA` rules already in `salnameorder.h` |
| V Plug-in architecture preservation | only documented `CSalamanderDirectoryAbstract` methods (`SetFlags`, `GetFilesCount`, `GetDirsCount`, `GetFile`, `GetDir`, `GetSalDir`) |
| VI UI consistency | no UI change, no strings |

Gate: PASS (pre- and post-design).

## Design

1. **`src/common/salcasetwins.h`** (header-only, includes `salnameorder.h`):
   - `SalNamesHaveCaseTwins(const SalCaseTwinName* names, int count)` - TRUE when two byte-different
     names are equal by `SalNameOrderCompareCI` (= the core's `SalNameCompareOrdinalCI`, used by the
     panel's name lists) or by `SalNameOrderDetail::LegacyCompareCI` (= `StrICmpEx`, used by
     `CSalamanderDirectory::SalDirStrCmp` while the tree is built and paths are compared). Both are
     total orders: sort a copy by each, compare neighbours. Low memory -> TRUE (keep the exact,
     case-sensitive listing - never merge).
   - `template <class TDir> BOOL SalDirTreeHasCaseTwins(const TDir* root)` - walks the tree with an
     explicit heap stack (no recursion), for each folder gathers its dirs and files (`Name`,
     `NameLen`) and asks `SalNamesHaveCaseTwins`. Low memory -> TRUE.
2. **7-Zip** (`src/plugins/7zip/7zclient.cpp`, `C7zClient::ListArchive`): `dir->SetFlags(
   SALDIRFLAG_CASESENSITIVE)` before the item loop; after it, `if (!SalDirTreeHasCaseTwins(dir))
   dir->SetFlags(0)`. Covers the panel listing, the paste re-listing (`PackList`) and Unpack whole
   archive (`GatherItems` walks the same tree).
3. **TAR** (`src/plugins/tar/tardll.cpp`, `CPluginInterfaceForArchiver::ListArchive`): the same
   around `archive->ListArchive(NULL, dir)` - covers tar and every format `CreateArchive` returns
   (cpio, rpm, deb, a single compressed stream).
4. **SFTP** (`src/plugins/sftp/fs.cpp`): `dir->SetFlags(SALDIRFLAG_CASESENSITIVE |
   SALDIRFLAG_IGNOREDUPDIRS)`.

Why "build case-sensitive, then clear": with the flag clear while adding, folders "D" and "d" are
merged before anything can notice; the TAR data cannot be read a second time cheaply. When no folder
of the case-sensitively built tree holds names equal by either rule, every merge the
case-insensitive build would have made joins byte-identical names only - the two trees are equal,
so clearing the flag yields exactly today's listing (FR-002).

## Project Structure

### Documentation (this feature)

```text
specs/252-archive-case-sensitivity/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/case-twins.md
├── fix-log.md, closing-report.md
└── probe/arc252_probe.ps1, probe/result_*.txt
```

### Source Code (repository root)

```text
src/common/salcasetwins.h              # new: the rule + tree walk
src/saltests/saltests.cpp              # checks of the rule
src/vcxproj/saltests/saltests.vcxproj  # ClInclude of the new header
src/plugins/7zip/7zclient.cpp          # ListArchive: build CS, clear without twins
src/plugins/tar/tardll.cpp             # ListArchive: the same
src/plugins/sftp/fs.cpp                # SetFlags(CASESENSITIVE | IGNOREDUPDIRS)
```

**Structure Decision**: existing layout; the shared rule is header-only in `src/common/` because the
7-Zip and TAR plug-ins cannot compile the core's `.cpp` files (CLAUDE.md rule).

## Complexity Tracking

None.
