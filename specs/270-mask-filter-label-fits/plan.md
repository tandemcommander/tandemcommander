# Implementation Plan: typed masks, filter, volume label and hot path name are never cut

**Branch**: `270-mask-filter-label-fits` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/270-mask-filter-label-fits/spec.md`

## Summary

Each of the five fields measures the UTF-8 (WTF-8) size of its **whole** text with feature 251's
`DlgItemTextFitsU8` before anything reads it into the 260-byte buffer, and refuses with the
existing "The path specified is too long."; the hot path label edit reads the whole name with
`SalGetWindowTextU8Alloc` and leaves the refusal to the page's existing `Validate` (251).

## Technical Context

**Language/Version**: C++20 (MSVC v143), pure WinAPI
**Primary Dependencies**: feature 251's helpers - `DlgItemTextFitsU8` (`src/dialogs.h` /
`dialogs3.cpp`), `SalGetWindowTextU8Alloc` (`src/common/winlib.*`), the rule `SalWTextFitsU8`
(`src/common/salunicode.*`, saltests `TestTextFits251`)
**Storage**: unchanged (selection mask, filter masks string / history, hot path slot names keep
their sizes and registry layout)
**Testing**: hidden-desktop probe `probe/mask270_probe.ps1` (11 rows); feature 251's probe as a
regression check; `saltests` (no new rule - the build and the existing checks)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application
**Performance Goals**: none (one measurement per OK)
**Constraints**: no new UI string (no `.slt` refresh); no plug-in interface change; text that fits
behaves exactly as before
**Scale/Scope**: 5 dialogs / one page, 6 sites in `dialogs2.cpp`, `dialogs3.cpp`, `dialogs4.cpp`

## Constitution Check

- I Build reproducibility: no new file in the build, no dependency. PASS
- II Backward compatibility: stored sizes and the registry unchanged; only texts that were cut are
  refused. PASS
- III Incremental modernization: 251's helper reused, not copied. PASS
- IV Windows commitment: WinAPI only. PASS
- V Plug-in architecture: untouched. PASS
- VI UI consistency: the message of 214 / 251, the field marked by `ErrorOn`. PASS

Post-design re-check: unchanged, PASS.

## Design

| Site | Change |
|---|---|
| `CSelectDialog::Validate` (`dialogs2.cpp`) | first `if (!DlgItemTextFitsU8(HWindow, IDE_FILEMASK, &ti, MAX_PATH)) return;` - before the syntax check (one message); `Transfer` reads only after a passed `Validate` (winlib runs `Transfer` only when `ti.IsGood()`) |
| `CConvertFilesDlg::Validate` (`dialogs3.cpp`) | the same, before its syntax check and the convert-action check |
| `CFilterDialog::Validate` | the same, **before** the `useFilter` branch: the text is stored by `Transfer` in either case |
| `CDriveInfo::Validate` | the same for `IDE_VOLNAME` inside the `ttDataFromWindow` branch, before `SetVolumeLabel` |
| `CCfgPageHotPath` `LVN_ENDLABELEDIT` (`dialogs4.cpp`) | read the edit whole (`SalGetWindowTextU8Alloc`), `CleanName`, `SetName`; a NULL result (no memory) changes nothing; the code-page fallback (no edit control) stays; `Validate` (251) refuses a name of `MAX_PATH` bytes or more at OK / leaving the page, the slot selected and its name field reloaded whole (`PeekName`) |

Consumers enumerated (fix protocol): `CSelectDialog` - only `CFilesWindow::SelectUnselect`
(`fileswn1.cpp`, `MainWindow->SelectionMask[MAX_PATH]`); `CConvertFilesDlg` - only
`CFilesWindow::Convert` (`fileswn5.cpp`, `Mask[MAX_PATH]`); `CFilterDialog` - only
`CFilesWindow::ChangeFilter` (`fileswn9.cpp`, `CMaskGroup` of 1,001 bytes read with `MAX_PATH`);
`CDriveInfo` - only `fileswn2.cpp`; the hot path page's label edit - its own handler. No plug-in
uses these classes.

## Project Structure

### Documentation (this feature)

```text
specs/270-mask-filter-label-fits/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
├── contracts/refusal.md
└── probe/mask270_probe.ps1, result_before.txt, result_after.txt
```

### Source Code (repository root)

```text
src/dialogs2.cpp   CSelectDialog::Validate
src/dialogs3.cpp   CConvertFilesDlg::Validate, CFilterDialog::Validate, CDriveInfo::Validate
src/dialogs4.cpp   CCfgPageHotPath::DialogProc, LVN_ENDLABELEDIT
```

**Structure Decision**: existing files only.

## Complexity Tracking

None.
