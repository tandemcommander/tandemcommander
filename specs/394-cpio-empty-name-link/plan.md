# Implementation Plan: A cpio hard link whose data name normalizes to empty gets its data

**Branch**: `394-cpio-empty-name-link` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/394-cpio-empty-name-link/spec.md`

## Summary

A newc / crc cpio member whose name normalizes to nothing leaves `ReadArchiveHeader` early as
`Ignored` (no `NameRefused`), so feature 310's hard-link grouping drops it and the group's other
names are written empty at the trailer. Mark such a member (`NameEmpty`, cpio formats only), give
it the time and attributes a normal member gets, keep it in its group as "not asked" (the rule
feature 393 introduced for a refused name, now a pure decision in `salcpiolink.h` with saltests),
never treat it as asked, and verify the crc checksum of any data that is actually written even
when the carrier is `Ignored`.

## Technical Context

**Language/Version**: C++20 (MSVC v143), plug-in `tar` (`src/plugins/tar/`)
**Primary Dependencies**: none new; `src/common/salcpiolink.h` (header-only, feature 310), `saltarlink.h`
**Storage**: N/A
**Testing**: `saltests` (pure rule), hidden-desktop probe `probe/cpioempty_probe.ps1`; regression probes of 306 / 308 / 309 / 310 / 321 / 393
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in
**Performance Goals**: unchanged (one flag test per member)
**Constraints**: plug-in ABI untouched (`SCommonHeader` is plug-in internal); no UI strings
**Scale/Scope**: ~30 lines in `untar.cpp` / `tar.h`, ~15 in `salcpiolink.h`, saltests checks

## Constitution Check

- I Build reproducibility: no new dependency, nothing vendored. PASS
- II Backward compatibility: archives without an empty-name carrier take the same paths (control row, regression probes). PASS
- III Incremental modernization: a local fix in the existing structure. PASS
- IV Windows commitment: N/A. PASS
- V Plug-in architecture: no interface change (`LAST_VERSION_OF_SALAMANDER` untouched). PASS
- VI UI consistency: existing messages only ("(2)", checksum error). PASS

Re-check after design: PASS (unchanged).

## Project Structure

### Documentation (this feature)

```text
specs/394-cpio-empty-name-link/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
├── checklists/requirements.md
└── probe/ (cpioempty_probe.ps1, mkcpioempty.py, result_*.txt, regress_*.txt)
```

No `contracts/`: nothing outside the plug-in relies on the changed code.

### Source Code

```text
src/common/salcpiolink.h        SalCpioKeepsGroupMember (new pure rule)
src/saltests/saltests.cpp       checks for it and for the empty normalizations
src/plugins/tar/tar.h           SCommonHeader::NameEmpty
src/plugins/tar/untar.cpp       Initialize, ReadArchiveHeader (empty-name branch), IsCpioGroupMember,
                                DoUnpackArchive / UnpackOneFilePass (never asked), WriteOutData (crc check)
```

**Structure Decision**: existing plug-in files only.

## Design

1. `ReadArchiveHeader`, branch "skip invalid names": unchanged for tar; for a cpio format
   (newc, crc, odc, binary, swapped binary) also `NameEmpty = TRUE` and the time / attribute
   conversion of the normal path (MTime -> `FileInfo.LastWrite`, `FILE_ATTRIBUTE_ARCHIVE` /
   `READONLY`), so data written from it under a waiting name carries the member's time.
2. `IsCpioGroupMember` = `SalCpioKeepsGroupMember(newcOrCrc, mode, nlink, IsDir, Ignored,
   NameRefused || NameEmpty)`.
3. `DoUnpackArchive` and `UnpackOneFilePass`: a `NameEmpty` member is never `found` (asked).
   It was never listed, so nothing can name it; this guards a mask matching the raw name `.`.
4. `WriteOutData`: the crc check runs when the member is not `Ignored` **or when its data is
   written** (`!simulate`) - only the group paths write data from an `Ignored` header
   (WRITE_FOR_WAITING, `UnpackOneCpioGroupName`); a mismatch removes the file and fails.
5. Unchanged: `SalCpioLinkDecide`, the data-first report (feature 310), the listing.

## Complexity Tracking

None.
