# Implementation Plan: Find's Containing text and the viewer's Find text are never cut

**Branch**: `311-find-containing-cut` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/311-find-containing-cut/spec.md`

## Summary

The Find dialog's Containing field gets feature 291's treatment of its Named field: the UTF-8
(WTF-8) size of the **whole** text is measured with feature 251's `DlgItemTextFitsU8` before
anything reads it into the 201-byte `GREP_TEXT_LEN` buffer, and a text that does not fit is refused
with the existing "The path specified is too long." - in `CFindDialog::Validate` (every search
start) and before the Options commands Add Current / Manage / Ignore; a stored option without a
Containing text keeps the field's whole text. The viewer's Find dialog (`CFindSetDialog`, 201-byte
`FIND_TEXT_LEN`) gets a `Validate` with the same check. Copying the Containing text into the
viewer's Find when a found file is viewed is skipped when it does not fit.

## Technical Context

**Language/Version**: C++20 (MSVC v143), pure WinAPI
**Primary Dependencies**: feature 251's `DlgItemTextFitsU8` (`src/dialogs.h` / `dialogs3.cpp`;
fails closed), `SalWindowTextFitsU8`, `SalGetWindowTextU8Alloc`, `SalSetWindowTextU8`
(`src/common/winlib.*`); the rule `SalWTextFitsU8` (`src/common/salunicode.*`, saltests)
**Storage**: unchanged (Find options, Find / viewer histories keep their sizes and registry layout)
**Testing**: hidden-desktop probe `probe/grep311_probe.ps1` (11 rows); 291's probe as the regression
check; `saltests` (no new rule)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application
**Performance Goals**: none (one measurement per OK / command)
**Constraints**: no new UI string (no `.slt` refresh); no plug-in interface change; text that fits
behaves exactly as before
**Scale/Scope**: the Find dialog and the viewer's Find dialog - `finddlg1.cpp`, `viewer.cpp`,
`viewer.h`

## Constitution Check

- I Build reproducibility: no new file, no dependency. PASS
- II Backward compatibility: buffer sizes, histories and the registry unchanged; only texts that were
  cut are refused. PASS
- III Incremental modernization: 251's helper reused, not copied. PASS
- IV Windows commitment: WinAPI only. PASS
- V Plug-in architecture: untouched (`CFindSetDialog` is core; no plug-in includes `viewer.h`). PASS
- VI UI consistency: the message of 214 / 251 / 270 / 291, the field marked by `ErrorOn` /
  `WM_NEXTDLGCTL`. PASS

Post-design re-check: unchanged, PASS.

## Design

| Site | Change |
|---|---|
| `CFindDialog::Validate` (`finddlg1.cpp`) | after 291's Named check: `if (!DlgItemTextFitsU8(HWindow, IDC_FIND_CONTAINING, &ti, GREP_TEXT_LEN)) return;` - before any read; covers Find, Find Now, Find Duplicates, Append / Subtract / Intersect (all `ValidateData()` first) and every mode (hex / regular expression read the same field) |
| `CFindDialog` `CM_FIND_ADD_CURRENT`, `CM_FIND_MANAGE`, `CM_FIND_IGNORE` | after 291's Named check, before `TransferData(ttDataFromWindow)` (whose `HistoryComboBox` cuts and writes back): the same check with `NULL` ti; refused -> the command does nothing (Manage / Ignore before their in-use flags) |
| `CFindDialog::LoadControls` | as 291's Named: the option has no Containing text and the field's text does not fit -> its whole text is taken (`SalGetWindowTextU8Alloc`) before `Data` changes and put back after `TransferData(ttDataToWindow)`; no memory -> TRACE_E, the option is not loaded; the "expand when Containing has text" test also counts the kept text |
| `CFindDialog::UpdateInternalViewerData` | the Containing field does not fit `FIND_TEXT_LEN` (`SalWindowTextFitsU8`) -> no copy at all (the core `CTransferInfo::EditLine` cuts at a whole character); the viewer keeps its find text and history |
| `CFindSetDialog` (`viewer.h` / `viewer.cpp`) | new `virtual void Validate(CTransferInfo& ti)`: `DlgItemTextFitsU8(HWindow, IDC_FINDTEXT, &ti, FIND_TEXT_LEN);` - before `Transfer`'s `HistoryComboBox` reads the field |

Consumers enumerated (fix protocol): the core `CFindDialog` - only `find.cpp` (`OpenFindDialog`);
every `TransferData(ttDataFromWindow)` of it: the three `ValidateData()`-guarded starts and the three
commands above; `LoadControls` only from `CM_FIND_OPTIONS_FIRST..` ; `UpdateInternalViewerData` only
from `OnViewFile` (View, Alt View) and `OnViewFileWith`. `CFindSetDialog`: the viewer's
`FindDialog` member executed only for `CM_FINDSET` / `CM_FINDNEXT` / `CM_FINDPREV` with no text
(`viewer3.cpp`), and the global `GlobalFindDialog` (never executed, data only). `HistoryComboBox`'s
other callers (`changeOnlyHistory` with a copied text) read no window. Stored values: the registry
load (`find.cpp`, `mainwnd2.cpp`) and the settings import (`cfgimport.cpp`, refuses too long) read
at most the buffer. The regedt plug-in's own Find dialog is a different class.

Out of scope: the viewer seeds its Find field from a selection of at most `FIND_TEXT_LEN - 1` bytes
(`GetFindText`) - a seed shown to the user, not a typed text; unchanged.

## Project Structure

### Documentation (this feature)

```text
specs/311-find-containing-cut/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
├── contracts/refusal.md
└── probe/grep311_probe.ps1, result_before.txt, result_after.txt
```

### Source Code (repository root)

```text
src/finddlg1.cpp   CFindDialog::Validate, ::LoadControls, ::UpdateInternalViewerData,
                   CM_FIND_ADD_CURRENT / MANAGE / IGNORE
src/viewer.h       CFindSetDialog::Validate (declaration)
src/viewer.cpp     CFindSetDialog::Validate
```

**Structure Decision**: existing files only.

## Complexity Tracking

None.
