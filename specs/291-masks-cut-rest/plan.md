# Implementation Plan: Recycle Bin, Find, viewer and compare masks and the view name are never cut

**Branch**: `291-masks-cut-rest` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/291-masks-cut-rest/spec.md`

## Summary

Each mask field measures the UTF-8 (WTF-8) size of its **whole** text with feature 251's
`DlgItemTextFitsU8` before anything reads it into its fixed buffer, and refuses with the existing
"The path specified is too long." - in the page's / dialog's `Validate` (the Recycle Bin, viewer
and compare masks, Find), and before the Find dialog's three commands that read the field without
`Validate` (Add Current, Manage, Ignore). Choosing a stored Find option without a Named text keeps
the field's whole text. The Views in-place name edit reads the edit whole
(`SalGetWindowTextU8Alloc`) and refuses a name that does not fit its 30 bytes, storing nothing.

## Technical Context

**Language/Version**: C++20 (MSVC v143), pure WinAPI
**Primary Dependencies**: feature 251's helpers - `DlgItemTextFitsU8` (`src/dialogs.h` /
`dialogs3.cpp`; fails closed: no memory = does not fit), `SalWindowTextFitsU8`,
`SalGetWindowTextU8Alloc`, `SalGetWindowTextWAlloc` (`src/common/winlib.*`), the rule
`SalWTextFitsU8` (`src/common/salunicode.*`, saltests)
**Storage**: unchanged (masks strings, Find history and options, view names keep their sizes and
registry layout)
**Testing**: hidden-desktop probe `probe/mask291_probe.ps1` (17 rows); 270's and 251's probes as
regression checks; `saltests` (no new rule - the build and the existing checks)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application
**Performance Goals**: none (one measurement per OK / command)
**Constraints**: no new UI string (no `.slt` refresh); no plug-in interface change; text that fits
behaves exactly as before
**Scale/Scope**: 2 configuration pages, the Views page's label edit, the Find dialog, Compare
Directories - `dialogs4.cpp`, `dialogs6.cpp`, `finddlg1.cpp`

## Constitution Check

- I Build reproducibility: no new file in the build, no dependency. PASS
- II Backward compatibility: stored sizes and the registry unchanged; only texts that were cut are
  refused. PASS
- III Incremental modernization: 251's helper reused, not copied. PASS
- IV Windows commitment: WinAPI only. PASS
- V Plug-in architecture: untouched (the regedt plug-in's own `CFindDialog` is a different class). PASS
- VI UI consistency: the message of 214 / 251 / 270, the field marked by `ErrorOn` /
  `WM_NEXTDLGCTL`. PASS

Post-design re-check: unchanged, PASS.

## Design

| Site | Change |
|---|---|
| `CCfgPageSystem::Validate` (`dialogs4.cpp`) | first `if (!DlgItemTextFitsU8(HWindow, IDE_RECYCLEMASKS, &ti, MAX_PATH)) return;` - **before** the `useRecycle == 2` branch: `Transfer` stores the field whatever the radio |
| `CCfgPageViewer::Validate` | inside each `ti.IsGood()` block, before its `EditLine` and syntax check: the check for `IDC_VIEW_INTEXT`, then for `IDC_VIEW_INHEX` (the tab size check stays first) |
| `CCfgPageView` `LVN_ENDLABELEDIT` | read the edit whole (`SalGetWindowTextU8Alloc`; NULL = no memory: TRACE_E, nothing stored), `CleanName`; `strlen >= VIEW_NAME_MAX` -> `SalMessageBox(IDS_TOOLONGPATH)`, nothing stored (the row keeps its name - the list's own label change is already refused, the handler sets the text itself); the code-page fallback (no edit control) unchanged |
| `CCompareDirsDialog::Validate` (`dialogs6.cpp`) | first both fields, `IDE_COMPARE_IGNORE_FILES` then `IDE_COMPARE_IGNORE_DIRS`, whatever the check boxes (`Transfer` stores both) |
| `CFindDialog::Validate` (`finddlg1.cpp`) | first `DlgItemTextFitsU8(HWindow, IDC_FIND_NAMED, &ti, NAMED_TEXT_LEN)` - before the backup and the syntax check; covers Find, Find Now, Find Duplicates, Append / Subtract / Intersect (all `ValidateData()` first) |
| `CFindDialog` `CM_FIND_ADD_CURRENT`, `CM_FIND_MANAGE`, `CM_FIND_IGNORE` | before `TransferData(ttDataFromWindow)` (whose `HistoryComboBox` reads the field cut and writes the cut text back into it and the history): `DlgItemTextFitsU8(HWindow, IDC_FIND_NAMED, NULL, NAMED_TEXT_LEN)`, refused -> the command does nothing (Manage / Ignore before their in-use flags) |
| `CFindDialog::LoadControls` | the option has no Named text: the field's text fits -> read as before; does not fit -> its whole wide text is taken (`SalGetWindowTextWAlloc`) and put back after `TransferData(ttDataToWindow)`; no memory -> TRACE_E, the option is not loaded (nothing changes) |

Consumers enumerated (fix protocol): `CCfgPageSystem`, `CCfgPageViewer`, `CCfgPageView` - only the
Configuration dialog (`CConfigurationDlg`, pages 3, 22, 12); `CCompareDirsDialog` - only
`CMainWindow::CompareDirectories` (`mainwnd3.cpp`); `ValidateMask` only in
`CCompareDirsDialog::Validate`; the core `CFindDialog` - only `find.cpp` (`OpenFindDialog`); every
`TransferData(ttDataFromWindow)` of it: the three `ValidateData()`-guarded starts and the three
commands above. The masks' other writers (registry load `mainwnd2.cpp`, settings import
`cfgimport.cpp`) read at most `MAX_PATH - 1` bytes. `VIEW_NAME_MAX` names: registry load and the
import refuse longer names. No plug-in uses these classes.

## Project Structure

### Documentation (this feature)

```text
specs/291-masks-cut-rest/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
├── contracts/refusal.md
└── probe/mask291_probe.ps1, result_before.txt, result_after.txt
```

### Source Code (repository root)

```text
src/dialogs4.cpp   CCfgPageSystem::Validate, CCfgPageViewer::Validate, CCfgPageView LVN_ENDLABELEDIT
src/dialogs6.cpp   CCompareDirsDialog::Validate
src/finddlg1.cpp   CFindDialog::Validate, ::LoadControls, CM_FIND_ADD_CURRENT / MANAGE / IGNORE
```

**Structure Decision**: existing files only.

## Complexity Tracking

None.
