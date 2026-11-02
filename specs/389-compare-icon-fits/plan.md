# Implementation Plan: User Menu compare names and the Change Icon file are never cut

**Branch**: `389-compare-icon-fits` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/389-compare-icon-fits/spec.md`

## Summary

Two core dialogs read a typed path into 260-byte buffers and use it cut (the compare names) or
in a code-page form (the Change Icon reload). Both get the area's standard measurement,
`DlgItemTextFitsU8` (features 214, 251, 270, 291): `CCompareArgsDlg::Validate` measures both names
first; `CChangeIconDialog` gets a `Validate` and its `LoadIcons` measures the field before reading
it. A text that does not fit is refused with the existing `IDS_TOOLONGPATH`; nothing else changes.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI, winlib (`CDialog`, `CTransferInfo`), `DlgItemTextFitsU8` (`src/dialogs3.cpp`, declared in `src/dialogs.h`)
**Storage**: none changed (the User Menu item's `Icon` value keeps its format and size)
**Testing**: GUI probe `probe/fit389_probe.ps1` on the hidden desktop; earlier probes 291 / 251 as regression; saltests unchanged (no new pure rule - the rule `SalWTextFitsU8` is already tested)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand`)
**Constraints**: no new UI string, no resource change (no `.slt` refresh needed); the plug-in ABI is not touched
**Scale/Scope**: 2 dialogs, 3 functions in `src/dialogs2.cpp` / `src/dialogs3.cpp`, one declaration in `src/dialogs.h`

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no build change - PASS |
| II Backward compatibility | text that fits behaves as before; stored data unchanged - PASS |
| III Incremental modernization | uses the existing rule, no new mechanism - PASS |
| IV Windows commitment | WinAPI only - PASS |
| V Plugin architecture | no plug-in interface touched - PASS |
| VI UI consistency | the same refusal message and focus behaviour as 251 / 270 / 291 - PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/389-compare-icon-fits/
├── spec.md, plan.md, research.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/fit389_probe.ps1, result_*.txt
```

No `data-model.md` (no data model changes) and no `contracts/` (no external interface changes - the
dialogs are internal UI).

### Source Code

```text
src/dialogs.h      CChangeIconDialog: + virtual void Validate(CTransferInfo& ti)
src/dialogs2.cpp   CCompareArgsDlg::Validate - measure IDE_UMC_NAME1, IDE_UMC_NAME2 first
src/dialogs3.cpp   CChangeIconDialog::Validate (new); CChangeIconDialog::LoadIcons - measure first
```

## Design

1. `CCompareArgsDlg::Validate`: before the empty checks,
   `if (!DlgItemTextFitsU8(HWindow, IDE_UMC_NAME1, &ti, MAX_PATH)) return;` and the same for
   `IDE_UMC_NAME2`. `Transfer` then reads text that fits (unchanged).
2. `CChangeIconDialog::Validate`: `DlgItemTextFitsU8(HWindow, IDE_CHI_FILENAME, &ti, MAX_PATH)`.
   winlib's IDOK runs `ValidateData` before `TransferData`, so `Transfer` never reads a cut name;
   the dialog's own IDOK handler (a changed field reloads first) runs before and stays as is.
3. `CChangeIconDialog::LoadIcons`: first
   `if (!DlgItemTextFitsU8(HWindow, IDE_CHI_FILENAME, NULL, MAX_PATH)) return FALSE;` - the message,
   the field focused with its text selected; the list keeps its icons. Its callers ignore the
   result (EN_KILLFOCUS, OK of a changed field, after Browse, `Transfer`); with the refusal they
   leave `Dirty` FALSE, so the next OK reaches `Validate`, which refuses again. The `Transfer`
   (`ttDataToWindow`) call loads a name the caller passed (<= 259 bytes), and the
   `ttDataFromWindow` call runs only after `Validate` passed - neither can be refused.
4. The code-page fallback in `LoadIcons` (`GetDlgItemText` when `SalWToU8` does not fit) becomes
   unreachable for a too long text; left as is (changes least).

## Complexity Tracking

None.
