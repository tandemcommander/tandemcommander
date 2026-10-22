# Implementation Plan: The Unpack dialog never offers a default target path or mask cut

**Branch**: `315-unpack-default-whole` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/315-unpack-default-whole/spec.md`

## Summary

`CFilesWindow::Unpack` prepares the Unpack dialog's defaults in 260-byte buffers with byte copies
that cut (`lstrcpyn`), drops the archive subfolder silently when it does not fit, and after OK turns
an empty target into the archive panel's path cut the same way. A new header-only rule
`src/common/salunpackdefault.h` copies a default whole or leaves it empty, and appends the archive
subfolder whole or empties the entry. `Unpack` uses it at the four sites: the other panel's path
(left out), the subfolder (entry left out), a plug-in's mask (`*.*` instead), the empty-target
fallback (refused with `IDS_TOOLONGPATH`, the dialog again). `saltests` checks the rule. No new
string, no buffer grown.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI; core `CFilesWindow::Unpack` (`src/fileswn7.cpp`), `CUnpackDialog` (unchanged)
**Storage**: N/A (nothing stored)
**Testing**: `saltests` (the pure rule, with a negative control); hidden-desktop probe `probe/unpack315_probe.ps1`; regression: 299's `unpack299_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand.vcxproj`, `saltests.vcxproj`)
**Performance Goals**: N/A (a few length checks per Alt+F9)
**Constraints**: never cut a path (CLAUDE.md, 097 / 098 / 101 / 214); paths are UTF-8 (066); no new UI string (084)
**Scale/Scope**: one function, one new header, saltests rows

## Constitution Check

- I Build reproducibility: a header-only file added to `saltests.vcxproj` (ClInclude), no dependency. PASS
- II Backward compatibility: every default that fits is offered exactly as before; only defaults
  that were cut are left out; no stored data, no plug-in interface change
  (`PostOpenUnpackDlgForThisPlugin` keeps its contract - a mask that does not fit was never usable
  whole). PASS
- III Incremental modernization: a small header-only rule in the style of 280's `salumvalue.h`. PASS
- IV Windows commitment: WinAPI only. PASS
- V Plug-in architecture: untouched. PASS
- VI UI consistency: the existing "The path specified is too long." through the existing
  error-and-reopen path of `Unpack` (`DO_AGAIN`). PASS

Post-design re-check: unchanged, PASS.

## Design

| Site (`CFilesWindow::Unpack`, `src/fileswn7.cpp`) | Today | Change |
|---|---|---|
| other panel's path into `path` (UA on) / `pathAlt` (UA off) | `lstrcpyn(..., MAX_PATH)` - cut | `SalUnpackDefaultCopy(target->GetPath(), buf, MAX_PATH)` - whole or left out (empty) |
| archive subfolder appended (SD on), for `path` and `pathAlt` | fits: appended; not: `TRACE_E`, bare path kept | `SalUnpackDefaultAddSubdir(buf, MAX_PATH, fileName, nameLen)` - appended whole, or the entry emptied (`TRACE_I`) |
| plug-in mask into `mask` | `lstrcpyn(mask, unpackMask, MAX_PATH)` - cut | `SalUnpackDefaultCopy`; FALSE -> `"*.*"` (`TRACE_E`) |
| after OK, empty target (`IDS_EMPTYNAMENOTALLOWED`) | `lstrcpyn(path, GetPath(), MAX_PATH)` - cut | `SalUnpackDefaultCopy(GetPath(), path, MAX_PATH)`; FALSE -> `text = LoadStr(IDS_TOOLONGPATH)` -> the existing message + `goto DO_AGAIN` |

An entry left out is empty; `CUnpackDialog::Transfer` adds `Path`, then `PathAlt` unless equal
(`StrICmp`) - two empty entries are shown once, as for a non-disk other panel. With SD on, an empty
entry gets the archive's name alone (relative: resolved next to the archive by `SalGetFullName`,
which refuses a too-long result itself, `IDS_TOOLONGPATH`) - unchanged behaviour of an empty
entry.

Consumers enumerated (fix protocol): `CFilesWindow::Unpack` is called from `CM_UNPACK`
(`src/mainwnd3.cpp`, Alt+F9) and from a plug-in's unpack request (`src/salamdr1.cpp`,
`OpenUnpackDlg`, mask from `CSalamanderGeneral::PostOpenUnpackDlgForThisPlugin`, `src/zip.cpp`).
`path` / `pathAlt` / `mask` are read by `CUnpackDialog` (Transfer: combo items, `EditLine` back into
`path` / `mask` with 299's `Validate`), then `SalGetFullName`, `CheckAndCreateDirectory`,
`UnpackerConfig.ExecuteUnpacker`, `PostChangeOnPathNotification`. None depends on a non-empty
default. `target->UserWorkedOnThisPath = TRUE` stays (it marks the other panel's path as used for
the default action; harmless when the entry is left out - kept to change least).

## Project Structure

### Documentation (this feature)

```text
specs/315-unpack-default-whole/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/salunpackdefault.md
├── probe/unpack315_probe.ps1 (+ result_*.txt)
├── fix-log.md
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salunpackdefault.h          new: the pure rule (header-only)
src/fileswn7.cpp                       CFilesWindow::Unpack - the four sites
src/saltests/saltests.cpp              rows of the rule
src/vcxproj/saltests/saltests.vcxproj  ClInclude of the header (+ .filters if the project lists them)
```

**Structure Decision**: core fix plus a header-only rule under `src/common/` (CLAUDE.md working
method: pure decisions in a header with `saltests` checks).

## Complexity Tracking

None.
