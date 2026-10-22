# Implementation Plan: The Unpack dialog never cuts a long target path or mask

**Branch**: `299-unpack-dialog-text-fits` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/299-unpack-dialog-text-fits/spec.md`

## Summary

`CUnpackDialog` (Alt+F9) reads its target path and mask into the caller's 260-byte buffers, cut
at a whole character. Add `CUnpackDialog::Validate`, which measures both fields whole with 214's
`DlgItemTextFitsU8` (path first, then mask) and refuses with `IDS_TOOLONGPATH` before `Transfer`
reads them. No new string, no buffer grown, no limit added.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI, the core's winlib (`CDialog::ValidateData` -> `Validate` before `TransferData`)
**Storage**: N/A (nothing stored; the dialog stores no history)
**Testing**: hidden-desktop probe `probe/unpack299_probe.ps1`; regression: 204's `unpack_dir_probe.ps1` row `f9-zip`; `saltests` (core build)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand.vcxproj`)
**Performance Goals**: N/A (one length check at OK)
**Constraints**: never cut a path (CLAUDE.md, 097 / 214 / 251); no new UI string (084)
**Scale/Scope**: one dialog class, two files (`src/dialogs.h`, `src/dialogs3.cpp`)

## Constitution Check

- I Build reproducibility: no new file in the build, no dependency. PASS
- II Backward compatibility: text that fits behaves as before; only text that was cut is refused;
  no stored data, no plug-in interface. PASS
- III Incremental modernization: 214's helper reused, not copied. PASS
- IV Windows commitment: WinAPI only. PASS
- V Plug-in architecture: untouched (a plug-in's unpack command opens the same core dialog; no
  interface change). PASS
- VI UI consistency: the message of 214 / 251 / 270 / 291, the field marked by `ErrorOn`. PASS

Post-design re-check: unchanged, PASS.

## Design

| Site | Change |
|---|---|
| `class CUnpackDialog` (`src/dialogs.h`) | declare `virtual void Validate(CTransferInfo& ti);` |
| `CUnpackDialog::Validate` (`src/dialogs3.cpp`) | `if (!DlgItemTextFitsU8(HWindow, IDE_PATH, &ti, MAX_PATH)) return;` then `DlgItemTextFitsU8(HWindow, IDE_MASK, &ti, MAX_PATH);` - MAX_PATH is the size of the caller's `path` / `mask` buffers and of `Transfer`'s reads |
| `CUnpackDialog::Transfer` | unchanged (after `Validate` the text fits, `EditLine` reads it whole) |

Consumers enumerated (fix protocol): `CUnpackDialog` is constructed only in
`CFilesWindow::Unpack` (`src/fileswn7.cpp`), called from `CM_UNPACK` (`src/mainwnd3.cpp`, Alt+F9)
and from a plug-in's unpack request (`src/salamdr1.cpp`, `OpenUnpackDlg`). Its fields are read only
by `Transfer` (ttDataFromWindow), which winlib's IDOK handling runs only after `ValidateData()`
succeeds; the dialog has no other button reading them. After the dialog, `path` / `mask` go to
`SalGetFullName`, `CheckAndCreateDirectory`, `UnpackerConfig.ExecuteUnpacker` and back into the
dialog (`DO_AGAIN`) - all receive the dialog's whole text now. No other class derives from
`CUnpackDialog`.

## Project Structure

### Documentation (this feature)

```text
specs/299-unpack-dialog-text-fits/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/refusal.md
├── fix-log.md
├── probe/unpack299_probe.ps1, result_*.txt
└── tasks.md
```

### Source Code (repository root)

```text
src/
├── dialogs.h      # CUnpackDialog: Validate declared
└── dialogs3.cpp   # CUnpackDialog::Validate
```

**Structure Decision**: the core only; no `src/common/` header - the decision is the existing
`DlgItemTextFitsU8` / `SalWindowTextFitsU8` rule (already a winlib helper, 214), nothing new to test
in `saltests`.

## Complexity Tracking

None.
