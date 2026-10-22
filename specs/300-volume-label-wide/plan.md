# Implementation Plan: Drive Information writes the volume label as typed

**Branch**: `300-volume-label-wide` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/300-volume-label-wide/spec.md`

## Summary

`CDriveInfo::Validate` (`src/dialogs3.cpp`) writes the typed label with `SetVolumeLabel`, which in
the core (no `UNICODE`) is `SetVolumeLabelA`: the UTF-8 label and volume path are read in the code
page. The call becomes `SetVolumeLabelW` with both strings converted by `SalU8ToWAlloc`; a failed
conversion writes nothing and reports through the existing message (`IDS_UNABLETOCHANGEDRIVELABEL`
with `GetErrorText(ERROR_NO_UNICODE_TRANSLATION)`, or `ERROR_NOT_ENOUGH_MEMORY` when the allocation
failed - the 2-way split of `mainwnd4.cpp`). `SetVolumeLabel` joins `ANSI_NAME_API` in
`tools/check_encoding.py`.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143; Python 3 (the checker)
**Primary Dependencies**: WinAPI (`SetVolumeLabelW`), `src/common/salunicode.h` (`SalU8ToWAlloc`, WTF-8, 066)
**Storage**: N/A (the drive's label is the only thing written, as before)
**Testing**: import table of `tandemcommander.exe` (`dumpbin /imports`, PowerShell) before / after;
the checker's `--rule ansi-api-on-utf8-path` report before / after + a negative control; a
hidden-desktop probe `probe/vol300_probe.ps1` (unelevated error path, unchanged label, 270's
too-long refusal); `saltests` (core build); the real write is a person step
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand.vcxproj`)
**Performance Goals**: N/A (one conversion at OK)
**Constraints**: UTF-8 / WTF-8 names never through the code page (066, CLAUDE.md); refuse rather
than guess; no new UI string (084)
**Scale/Scope**: one call site (`src/dialogs3.cpp`), one checker list (`tools/check_encoding.py`)

## Constitution Check

- I Build reproducibility: no new file in the build, no dependency. PASS
- II Backward compatibility: an ASCII label is written exactly as before; only the bytes of
  non-ASCII letters change (they were garbled); no stored data, no plug-in interface. PASS
- III Incremental modernization: one call site moved to the wide API, the existing converter
  reused. PASS
- IV Windows commitment: WinAPI only. PASS
- V Plug-in architecture: untouched (no plug-in calls `SetVolumeLabel`; the plug-in scan finds
  none). PASS
- VI UI consistency: the existing error message and `ErrorOn` of the label field. PASS

Post-design re-check: unchanged, PASS.

## Design

| Site | Change |
|------|--------|
| `src/dialogs3.cpp` `CDriveInfo::Validate` | after the existing too-long refusal (270) and the "unchanged" test (069): `pathW = SalU8ToWAlloc(volumePathWithBackslash)`, `nameW = SalU8ToWAlloc(newName)`; either NULL → no write, `err` = `ERROR_NOT_ENOUGH_MEMORY` when the failed string's size query `SalU8ToW(src, -1, NULL, 0)` succeeds (the allocation failed), else `ERROR_NO_UNICODE_TRANSLATION`; the existing message box, `ti.ErrorOn(IDE_VOLNAME)`; else `SetVolumeLabelW(pathW, nameW)` inside the same hands-off bracket; both freed. The dead `SAD_` comment lines stay (legacy). |
| `tools/check_encoding.py` `ANSI_NAME_API` | `SetVolumeLabel` added to the alternation (the regex already accepts the `A` suffix) |

The conversion happens **before** the panels' hands-off, so a refusal leaves the panels untouched.
An empty label converts to `L""` (size 1) - written as empty, as before.

## Measurement

- **Before** (HEAD build): `dumpbin /imports` lists `SetVolumeLabelA` (measured at plan time on
  the current Debug build: `5BC SetVolumeLabelA`); checker with the list extended in memory: 40
  core findings, `dialogs3.cpp:1341` among them.
- **After**: `SetVolumeLabelA` gone, `SetVolumeLabelW` imported; the checker's report back to 39,
  no `SetVolumeLabel` hit; negative control: a scratch copy of `dialogs3.cpp` with the old call
  (checker run on a temporary tree, or the in-memory method of the measurement) is reported.
- **Probe** `vol300_probe.ps1` (style of 270's `mask270_probe.ps1`, 098's library, registry
  backup / restore): rows
  - `vol-fail`: Drive Information (CM 752) on the fixture's drive (fixed, unelevated), label
    `Zálohy`, OK → the "Unable to change drive label" message with the access-denied text, the
    dialog stays, the drive's label unchanged; NOT DRIVEN when elevated or not a fixed drive;
  - `vol-same`: the label left as shown, OK → the dialog closes, nothing asked, label unchanged;
  - `vol-long`: 270's row (140 `ř`, 280 bytes) → refused as too long, label unchanged.
  Rows run before (HEAD build) and after; all three are expected PASS on both - they guard the
  error path, not the defect (which the import table proves).
- **Person step**: on a USB stick or a VHD, elevated where needed: label `Zálohy` (and `Диск`
  if the field takes it) via Drive Information → Explorer shows it exactly.

## Project Structure

### Documentation (this feature)

```text
specs/300-volume-label-wide/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
├── probe/vol300_probe.ps1, result_*.txt
└── tasks.md
```

No `contracts/`: no interface other parts rely on changes.

### Source Code (repository root)

```text
src/dialogs3.cpp            CDriveInfo::Validate
tools/check_encoding.py     ANSI_NAME_API
```

**Structure Decision**: the existing core sources; no new file in the build.

## Complexity Tracking

None.
