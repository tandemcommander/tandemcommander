# Implementation Plan: Link members of a tar are extracted or reported, never dropped silently

**Branch**: `309-tar-link-members` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/309-tar-link-members/spec.md`

## Summary

`CArchive::ReadTarHeader` (`src/plugins/tar/untar.cpp`) marks hard links ('1') and symbolic links ('2')
`Ignored` and forgets the name they link to (the ustar `linkname` is never read, a GNU long link name 'K'
is read and discarded, a PAX `linkpath` record is ignored by `salpaxheader.h`); `DoUnpackArchive` skips
them and returns TRUE, so the core deletes the archive when "Delete archive after unpacking" is checked.
The fix: the header keeps the link type and the link name (PAX `linkpath` > GNU 'K' > ustar `linkname`,
decoded and normalized like member names); an extraction remembers the archive names of the files it
wrote; a hard link asked for whose target was written is extracted as a copy of that file (through the
plug-in's usual `SafeFileCreate`, never writing the target itself); any other link asked for is reported
(one box per operation, system text + "name -> link name") and the operation returns FALSE after the
rest is extracted - the rule feature 308 applied to refused names.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; header-only rules in `src/common/` (shared with saltests):
`salpaxheader.h` (linkpath), new `saltarlink.h` (name normalization moved out of `ReadArchiveHeader`,
the copy / report decision); `salsamefile.h` (file identity, already header-only for plug-ins)
**Storage**: N/A (no registry or configuration change)
**Testing**: `saltests` (linkpath precedence, normalization, decision); hidden-desktop probe
`probe/link309_probe.ps1`; regressions: 308 probe (12 / 0), 306 probe (28 / 0)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, archiver plug-in (TAR)
**Performance Goals**: one hash-set insert per written file; a hard link costs one file copy
**Constraints**: plug-in ABI untouched; no UI string added; names stay UTF-8 (WTF-8) and are never cut
**Scale/Scope**: `src/plugins/tar/untar.cpp`, `tar.h`, `precomp.h`; `src/common/salpaxheader.h`,
`src/common/saltarlink.h` (new); `src/saltests/saltests.cpp`

## Constitution Check

- I Build reproducibility: no dependency, no build step change (a new header only) - PASS.
- II Backward compatibility: listing unchanged; files, folders, devices and 306/308 behaviour unchanged;
  archives without link members extract exactly as before - PASS.
- III Incremental modernization: a local change in one plug-in; pure rules header-only with tests - PASS.
- IV Windows commitment: copies instead of symbolic links (no privilege / Developer Mode needed) - PASS.
- V Plugin architecture preservation: no `spl_*.h` change, `LAST_VERSION_OF_SALAMANDER` untouched - PASS.
- VI UI consistency: the plug-in's existing error box (title "TAR Plugin Error"), system texts, no new
  string; the copy uses the same overwrite questions as any extracted file - PASS.

Standing rules touched: never lose the user's data (a link left out fails the operation, the archive is
kept; the copy never opens its source for writing, a same-file destination is detected by identity -
`salsamefile.h`); UTF-8 names (`SplU8ToWExtAlloc` for every file API, no `A` API); a path is never cut
(heap buffers sized for the whole name).

## Project Structure

### Documentation (this feature)

```text
specs/309-tar-link-members/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/   link309_probe.ps1, mklink309.py, result_*.txt
```

No `contracts/`: no interface other components rely on changes (the plug-in returns FALSE from an
operation it already could fail).

### Source Code (repository root)

```text
src/common/saltarlink.h        SalTarNormalizeNameU8 (moved from ReadArchiveHeader), SalTarLinkDecide
src/common/salpaxheader.h      SalPaxValues::LinkPath, "linkpath" in SalPaxApply, SalPaxEffectiveLinkPath
src/plugins/tar/precomp.h      <string>, <unordered_set> before the debug 'new' macro
src/plugins/tar/tar.h          SCommonHeader::LinkType / LinkName; CArchive::ReportLinkMember,
                               WriteOutLinkCopy; WriteOutData gets an optional 'written' out-parameter
src/plugins/tar/untar.cpp      ReadTarHeader keeps type + link name; ReadArchiveHeader normalizes it;
                               DoUnpackArchive copies / reports; UnpackOneFile reports
src/saltests/saltests.cpp      TestTarLink309
```

**Structure Decision**: existing tar plug-in and shared headers; one new header in `src/common/`.

## Complexity Tracking

None.
