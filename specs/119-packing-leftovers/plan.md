# Implementation Plan: the leftovers of the packing fixes

**Branch**: `119-packing-leftovers` | **Date**: 2026-10-06 | **Spec**: [spec.md](spec.md)

## Summary

Close the five small items 106 recorded. In the ZIP plug-in's multi-volume pack: record every
volume this operation creates with its file identity and delete them (only while the name still
holds that file) when the pack ends without a complete archive; refuse a set whose last volume
could not be renamed to an existing `name.zip`, before anything is created, with the plug-in's
existing `IDS_CANTMULTIVOL`; report a failed final rename. In the core: refuse every pack into an
archive that is one of its own sources, before any question or packer, on the Pack dialog, F5 / F6
and drag & drop / paste routes, with a box that names the archive.

## Technical Context

C++20, MSVC v143, WinAPI. Core (`fileswn7.cpp`, `fileswn8.cpp`, `fileswna.cpp`, `fileswnd.h`) and
the ZIP plug-in (`add.cpp`, `add_del.{h,cpp}`); new header-only `src/common/salpackvol.h` (the ZIP
project cannot compile a shared `.cpp`), saltests. No interface change (107), no string, no
registry. Probe: Windows PowerShell 5.1 on the hidden desktop, extending 106's
`packself_probe.ps1` (098's `fix_probe_lib.ps1`), 7z.exe reads the results.

## Constitution Check

- Backward compatibility: archives unchanged; a behaviour change (a pack into a selected archive is
  refused as a whole) recorded in the spec and CHANGELOG.
- Plugin architecture preservation: no interface change; the core's check runs before any packer,
  so third-party packers are covered without knowing about it.
- UI consistency: existing texts and the existing error dialog; no new string.

## Design

| Piece | Where | What |
|---|---|---|
| `CSalPackCreatedFiles` | `salpackvol.h` | list of (UTF-8 name, `CSalFileIdentity`), malloc-based, not copyable |
| `SalPackVolCleanupScope(failed, outputComplete, removable)` | `salpackvol.h` | none / current / all |
| `SalPackCreatedMayDelete(created, sizeKnown, size, nowExists, now)` | `salpackvol.h` | same id (and creation time if known) -> yes; another id or gone -> no; no usable ids -> only a file with the recorded creation time and written size (review SF1) |
| `SalMultiVolFinalNameTaken(sfx, seq, winzip, removable, exists)` | `salpackvol.h` | refuse before creating |
| `CZipPack::CreatedVolumes` | `add_del.h` | pointer to `PackMultiVol`'s local list (scope guard), NULL elsewhere |
| `CreateNextFile` | `add.cpp` | records a created volume with `SalFileIdentityFromHandle`; low memory -> the file is deleted, `IDS_LOWMEM` |
| `PackMultiVol` | `add.cpp` | the `IDS_CANTMULTIVOL` check first; `outputComplete` before `CleanUpSource`; the rename checked; clean-up by scope |
| `DeleteCreatedVolumes(all)`, `DeleteCreatedVolume`, `NoteVolumeSize` | `add.cpp` | all recorded volumes (identity re-read with `linkItself`), or on removable media the one still being written; sizes recorded at close; `NextDisk` clears `TempNameOurs` before the disk can change (review SF2) |
| `PackArchiveIsSelectedSource` | `fileswn7.cpp` | was static (106) - now shared; ancestors from the typed and the resolved path; plain-file pre-filter (review SF5) |
| `ShowPackIntoItselfRefusal` | `fileswn7.cpp` | `CFileErrorDlg(..., IDD_ERROR3)`: Name = archive, Error = copy / move "to itself" |
| Pack dialog | `fileswn7.cpp` | refusal before the link scan and the question; 106's Overwrite guard uses the named box |
| F5 / F6 | `fileswn8.cpp` | refusal after the 099 link scan, before the zero-size archive is deleted |
| drag & drop / paste | `fileswna.cpp` | refusal after the 099 link scan |

## Phases

1. Research by code reading (`research.md`); pre-change build copied to `Debug_x64_pre119`.
2. Pure header + saltests; ZIP plug-in; core routes.
3. Debug build, saltests, strict guard, clang-format on the changed regions, full Release build.
4. Hostile re-read; probe written (not run); records; `Debug_x64_119` copied for the GUI runs.
