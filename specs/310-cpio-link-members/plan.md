# Implementation Plan: Links in a cpio or rpm are extracted or reported, never dropped silently

**Branch**: `310-cpio-link-members` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/310-cpio-link-members/spec.md`

## Summary

The TAR plug-in's cpio reader (`CArchive::ReadArchiveHeader` / `ReadNewASCIIHeader`,
`src/plugins/tar/untar.cpp`) marks every member that is not a regular file or a folder `Ignored` and
never reads `c_ino`, `c_nlink` or the device of a newc / crc header. A symbolic link is therefore
skipped without a word (and `DoUnpackArchive` returns TRUE, so "Delete archive after unpacking"
deletes the archive), and the names of a hard-linked file that GNU cpio, rpm and libarchive store with
size 0 (the data only with the last name) are written as empty files.

The fix, on top of feature 309's link machinery:

1. **Symbolic links**: a cpio `S_IFLNK` member gets `LinkType = SYMTYPE` and its target (its data,
   up to 4096 bytes, read in `ReadArchiveHeader`) as `LinkName`; feature 309's code in
   `DoUnpackArchive` then reports it ("(50) not supported", `name -> target`) and fails the operation.
2. **Hard-link groups** (newc / crc only): the header keeps `c_ino`, `c_nlink`, `c_devmajor`,
   `c_devminor`. `DoUnpackArchive` keeps a map *group key -> state* (no data yet / data written to
   name X / data lost) with the asked names waiting for the data. The per-member action comes from a
   pure rule, `SalCpioLinkDecide` (new header `src/common/salcpiolink.h`, saltests): write normally,
   wait, copy from the written name (`WriteOutLinkCopy` of feature 309), write the data under the first
   waiting name (the data name was not asked), report (data not written), or skip. At the end of the
   archive the groups that never carried data write their waiting names as empty files.
3. **Single-file extraction** (`UnpackOneFile`, F3 / Enter on one name): a found name stored with size
   0 reads on to the member of its group that carries data and writes that data under the asked name;
   if the data came earlier in the archive (rare data-first layout) the member is reported and the
   operation fails - never an empty file.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; new header-only rule `src/common/salcpiolink.h` (shared with
saltests); feature 309's `saltarlink.h` (`SAL_TAR_TYPE_SYMLINK`), `WriteOutLinkCopy`,
`ReportLinkMember`, `salsamefile.h` identity check
**Storage**: N/A (no registry or configuration change)
**Testing**: `saltests` (`TestCpioLink310`: the grouping rule and every decision row); hidden-desktop
probe `probe/cpio310_probe.ps1` (fixtures `probe/mkcpio310.py`); regressions: 309 probe (16 / 0), 308
probe (12 / 0), 306 probe (28 / 0)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, archiver plug-in (TAR)
**Performance Goals**: one map lookup per grouped member; an extra name costs one file copy
**Constraints**: plug-in ABI untouched; no UI string added; names stay UTF-8 (WTF-8) and are never cut
**Scale/Scope**: `src/plugins/tar/untar.cpp`, `tar.h`, `precomp.h` (if `<map>` is needed);
`src/common/salcpiolink.h` (new); `src/saltests/saltests.cpp`

## Constitution Check

- I Build reproducibility: no dependency, no build step change (a new header only) - PASS.
- II Backward compatibility: listing unchanged; tar, odc / binary cpio, files without links, folders,
  devices, FIFOs and sockets extract exactly as before - PASS.
- III Incremental modernization: a local change in one plug-in; the pure rule header-only with tests -
  PASS.
- IV Windows commitment: copies instead of links (no privilege needed) - PASS.
- V Plugin architecture preservation: no `spl_*.h` change, `LAST_VERSION_OF_SALAMANDER` untouched -
  PASS.
- VI UI consistency: feature 309's error box (system texts + `name -> link name`), no new string; the
  copies use the same overwrite questions as any extracted file - PASS.

Standing rules touched: never lose the user's data (a link left out or data not written fails the
operation, the archive is kept; a copy never writes its source - identity check); UTF-8 names (every
file API through `SplU8ToWExtAlloc` / `SafeFileCreate`, no `A` API); a path is never cut (heap
strings).

## Project Structure

### Documentation (this feature)

```text
specs/310-cpio-link-members/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/   cpio310_probe.ps1, mkcpio310.py, result_*.txt
```

No `contracts/`: no interface other components rely on changes (the plug-in returns FALSE from an
operation it already could fail).

### Source Code (repository root)

```text
src/common/salcpiolink.h     SalCpioIsLinkGroupMember, SalCpioLinkDecide (pure, header-only)
src/plugins/tar/tar.h        SCommonHeader::CpioIno / CpioNLink / CpioDevMajor / CpioDevMinor;
                             CArchive helpers for the group store
src/plugins/tar/untar.cpp    ReadNewASCIIHeader reads ino / nlink / dev; ReadArchiveHeader reads a
                             symlink's target; DoUnpackArchive groups; UnpackOneFile reads on
src/saltests/saltests.cpp    TestCpioLink310
```

**Structure Decision**: existing tar plug-in and shared headers; one new header in `src/common/`.

## Complexity Tracking

None - no constitution violation.
