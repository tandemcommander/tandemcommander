# Implementation Plan: Drive list and folder type names come from Windows as Unicode

**Branch**: `289-drive-list-wide-texts` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/289-drive-list-wide-texts/spec.md`

## Summary

The folder type name, the `..` type name, a removable drive's shell display name, a CD label and
the localized words of the Change Drive menu / drive bar tooltips are obtained in the ANSI code
page and stored where every sink reads UTF-8 first. The change asks Windows for the Unicode text
(`SHGetFileInfoW`, `GetVolumeInformationW`, `LoadStrU8`, `PrintDiskSize(..., TRUE)`), stores UTF-8
in buffers sized for the longest answer (never cut), keeps every fallback and the CD thread's
timeout, and extends the Debug-only probe seam of feature 246 so a hidden-desktop probe can read
the exact bytes. The pure rule (the trimming of the " (X:)" suffix of a display name and the size
bound) goes into a header-only `src/common/saldrivetext.h` with `saltests` checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: Win32 (shell32 `SHGetFileInfoW`, kernel32 `GetVolumeInformationW`), core helpers `SalWToU8`, `LoadStrU8`, `PrintDiskSize`
**Storage**: none (no registry, no file change)
**Testing**: `saltests` (pure rule), GUI probe on the hidden desktop through the seam `TC_PROBE_DRIVES_DUMP` (Debug)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand.vcxproj`)
**Performance Goals**: unchanged - one Unicode call replaces one ANSI call; the CD thread keeps 500 ms
**Constraints**: no new UI string; no plug-in ABI change; never cut a text mid-character (CLAUDE.md 097/098/101); UTF-8 sinks take `LoadStrU8` (CLAUDE.md)
**Scale/Scope**: 4 source files (`drivelst.cpp`, `icncache.cpp`, `salamdr1.cpp`, `salamdr5.cpp` + `consts.h`), one new header, saltests

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I Build reproducibility | no new dependency, no project change except a header picked up by existing include paths | PASS |
| II Backward compatibility | texts that render today render the same (sinks are UTF-8 first; ASCII bytes unchanged); no stored data; no plug-in interface touched | PASS |
| III Incremental modernization | narrow, per-site change following features 069 / 246 | PASS |
| IV Windows commitment | Win32 wide APIs only | PASS |
| V Plug-in architecture | `TransferBuffer` (1024 bytes) holds the larger folder type name; `spl_*.h` untouched | PASS |
| VI UI consistency | no new strings or layout | PASS |

Post-design re-check: PASS (no new violation; the seam is Debug-only like 246's).

## Project Structure

### Documentation (this feature)

```text
specs/289-drive-list-wide-texts/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/probe-seam.md      # amendment of 246's seam: TYPES line, TIP for every drive
├── fix-log.md, closing-report.md
└── probe/run289.ps1             # hidden-desktop probe, results_*.txt
```

### Source Code

```text
src/common/saldrivetext.h   # NEW header-only: SAL_DRIVE_TEXT_U8_MAX, SalDriveNameTrimLetterSuffixW
src/saltests/saltests.cpp   # checks of the header
src/icncache.cpp            # ReadDirectoryIconAndTypeAux: SHGetFileInfoW -> UTF-8
src/salamdr1.cpp            # FolderTypeName[] size; UpDirTypeName = LoadStrU8
src/consts.h                # FolderTypeName / ReadCDVolNameBuffer declarations
src/salamdr5.cpp            # ReadCDVolNameBuffer size
src/drivelst.cpp            # GetDisplayNameFromSystem (W), CD thread (W), LoadStrU8 texts,
                            # PrintDiskSize u8, buffer sizes, OneDrive name offsets, seam lines
```

**Structure Decision**: existing core files; the one pure rule in a new `src/common` header
(standing rule: pure decisions under `src/common/` with saltests).

## Design

1. **Size bound** `SAL_DRIVE_TEXT_U8_MAX = 3 * MAX_PATH + 1` bytes: a shell display name
   (`szDisplayName[260]`) or a volume label (buffer of `MAX_PATH + 1` units) is at most 260 UTF-16
   units, each at most 3 UTF-8 bytes (a surrogate pair = 2 units -> 4 bytes). The folder type name
   (`szTypeName[80]`) needs `3 * 80 + 1 = 241` bytes: `FolderTypeName[241]`.
2. **Folder type name** (`icncache.cpp`): `SHGetFileInfoW` on the wide system directory
   (`GetSystemDirectoryW`) with `SHGFI_TYPENAME`; `SalWToU8` into `FolderTypeName`; on failure the
   name stays as it was (empty at start) - as before.
3. **Up-directory type name** (`salamdr1.cpp`): `DupStr(LoadStrU8(IDS_UPDIRTYPENAME))`.
4. **Removable display name** (`GetDisplayNameFromSystem`): root converted with `SalU8ToW`,
   `SHGetFileInfoW(SHGFI_DISPLAYNAME)`, the suffix trimmed by `SalDriveNameTrimLetterSuffixW`
   (same rule as today: cut at the last '(' and the spaces before it), `SalWToU8` into the caller's
   buffer; a conversion failure leaves it empty (callers then show "Removable Drive").
5. **CD label** (`ReadCDVolNameThreadFBody`): `GetVolumeInformationW` into a wide buffer,
   `SalWToU8` into a local `SAL_DRIVE_TEXT_U8_MAX` buffer; empty -> `GetDisplayNameFromSystem`;
   copied whole into `ReadCDVolNameBuffer[SAL_DRIVE_TEXT_U8_MAX]` (strcpy_s - the sizes match, no
   `lstrcpyn` cut). No ANSI retry.
6. **Callers' buffers**: `volumeName` in `BuildData` and `GetDriveBarToolTip` become
   `2 * SAL_DRIVE_TEXT_U8_MAX + 100` (the ampersand doubling can double a label; the free-space
   text follows); `DuplicateAmpersands` gets the real size; the copy from `ReadCDVolNameBuffer`
   uses the real size.
7. **Localized texts**: every `LoadStr` that feeds `DriveText` or a drive bar tooltip becomes
   `LoadStrU8` (floppies, removable / local / compact disk, `AddToDrives`' `textResId`, OneDrive /
   Personal, tooltip words); `PrintDiskSize(..., 0, TRUE)` for both free-space texts.
   `ExecuteItem` / the OneDrive drop-down measure `LoadStrU8(IDS_ONEDRIVE)` (the same encoding the
   item was composed with).
8. **Seam** (Debug only, contract `contracts/probe-seam.md`): after the `BUILD` line a
   `TYPES folder=<FolderTypeName> updir=<UpDirTypeName>` line; `ProbeDumpToolTips` asks the
   tooltip of every drive item that has one (not only network drives); `TIP` is logged for every
   drive type (moved to the end of `GetDriveBarToolTip`).

## Complexity Tracking

None.
