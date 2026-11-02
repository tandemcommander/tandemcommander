# Implementation Plan: Unpack reports a file whose only name normalizes to empty

**Branch**: `395-cpio-solo-empty-name` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/395-cpio-solo-empty-name/spec.md`

## Summary

A regular member with data whose name normalizes to nothing leaves `ReadArchiveHeader` as
`Ignored`; a whole Unpack reads its data past and reports success, so the core deletes the
archive. Mark such a member (`NameEmptyRegular`, any format - cpio and tar), and in
`DoUnpackArchive` decide with a new pure rule (`SalEmptyNameDataDecide`, `salcpiolink.h`, saltests)
whether its data reached an extracted name: a single-name member asked by its raw name (the mask)
is reported at once; a newc / crc group carrier is "pending" when its data passes unwritten, the
pending mark is cleared when a later member of the group writes the data or reports its loss
(394's "(2)"), and a pending group is reported at the end of the archive. A report is the system's
"(123)" text with the raw name in quotes, once per operation, and sets `refused` - the operation
fails after the rest is extracted, the archive is kept.

## Technical Context

**Language/Version**: C++20 (MSVC v143), plug-in `tar` (`src/plugins/tar/`)
**Primary Dependencies**: none new; `src/common/salcpiolink.h` (header-only, features 310 / 394)
**Storage**: N/A
**Testing**: `saltests` (pure rule), hidden-desktop probe `probe/cpiosolo_probe.ps1`; regression probes of 306 / 308 / 309 / 310 / 321 / 393 / 394
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in
**Performance Goals**: unchanged (a flag test per member, one pass over the groups at the end)
**Constraints**: plug-in ABI untouched (`SCommonHeader` is plug-in internal); no new UI string (system error text)
**Scale/Scope**: ~60 lines in `untar.cpp` / `tar.h`, ~30 in `salcpiolink.h`, saltests checks

## Constitution Check

- I Build reproducibility: no new dependency. PASS
- II Backward compatibility: archives without such a member take the same paths (7 control rows, regression probes); `.` folders and size-0 members stay silent. PASS
- III Incremental modernization: a local fix in the existing structure. PASS
- IV Windows commitment: N/A. PASS
- V Plug-in architecture: no interface change. PASS
- VI UI consistency: an existing system text ("(123)") in the plug-in's error box, as 306's "(206)". PASS

Re-check after design: PASS (unchanged).

## Project Structure

### Documentation (this feature)

```text
specs/395-cpio-solo-empty-name/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
├── checklists/requirements.md
└── probe/ (cpiosolo_probe.ps1, mkcpiosolo.py, result_*.txt, regress_*.txt)
```

No `contracts/`: nothing outside the plug-in relies on the changed code.

### Source Code

```text
src/common/salcpiolink.h        SalEmptyNameDataDecide, SalEmptyNamePendingCleared (new pure rules)
src/saltests/saltests.cpp       checks for them
src/plugins/tar/tar.h           SCommonHeader::NameEmptyRegular, SCpioGroup::EmptyLost / EmptyLostName,
                                CArchive::EmptyNameShown, ReportEmptyName, ReportCpioEmptyLost
src/plugins/tar/untar.cpp       constructor, Initialize, ReadArchiveHeader (empty-name branch),
                                DoUnpackArchive, WriteOutCpioGroupMember, ReportEmptyName, ReportCpioEmptyLost
```

**Structure Decision**: the existing plug-in and shared-header layout; no new files except the probe.

## Complexity Tracking

None.
