# Implementation Plan: typed text is never cut to the caller's buffer

**Branch**: `251-dialog-text-fits` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/251-dialog-text-fits/spec.md`

## Summary

Every listed field measures the UTF-8 (WTF-8) size of its **whole** text against the buffer the
program uses and refuses with the existing "The path specified is too long." instead of cutting.
One pure rule (`SalWTextFitsU8`, unit-tested) under the window helpers; one refusing dialog helper
(the generalised 214 check) for the dialogs; pages that store on every keystroke keep the whole
text in their items and refuse at page validation.

## Technical Context

**Language/Version**: C++20 (MSVC v143), pure WinAPI
**Primary Dependencies**: winlib (`src/common/winlib.*`), `salunicode` (`src/common/salunicode.*`)
**Storage**: the configuration in `HKCU\Software\Tandem Commander\0.1` - unchanged layout; values
are only kept from becoming longer than the loader accepts
**Testing**: `saltests` (the rule), hidden-desktop probe `probe/dlg251_probe.ps1`, 214's probe
**Target Platform**: Windows 11 x64
**Project Type**: desktop application
**Performance Goals**: none (one measurement per validated field)
**Constraints**: no new UI string (no `.slt` refresh); no plug-in interface change; text that fits
behaves exactly as before
**Scale/Scope**: 8 dialogs / pages, ~12 sites

## Constitution Check

- I Build reproducibility: no new dependency or project; `salunicode.cpp` already in `saltests`. PASS
- II Backward compatibility: registry layout and loaded values unchanged; only refusals of values
  that could not be loaded back anyway (user menu) or were cut. PASS
- III Incremental modernization: small, local changes; 214's helper generalised, not copied. PASS
- IV Windows commitment: WinAPI only. PASS
- V Plug-in architecture: untouched. PASS
- VI UI consistency: the existing message of 214, the field marked as the pages' existing checks do. PASS

Post-design re-check: unchanged, PASS.

## Design

### Shared rule and helpers

- `src/common/salunicode.h/.cpp`: `BOOL SalWTextFitsU8(const WCHAR* src, int bufSize)` - TRUE when
  the UTF-8 (WTF-8) form of the null-terminated `src` with its terminator fits `bufSize` bytes;
  NULL counts as empty; `bufSize <= 0` or no memory to measure: FALSE (fail closed).
- `src/common/winlib.h/.cpp` (INSIDE_SALAMANDER section, beside `SalGetWindowTextU8`):
  - `BOOL SalWindowTextFitsU8(HWND hWnd, int u8BufSize)` - the whole window text against the size;
    FALSE without memory;
  - `char* SalGetWindowTextU8Alloc(HWND hWnd)` - the whole window text as malloc'd UTF-8 (WTF-8);
    NULL without memory.
- `src/dialogs3.cpp` + `src/dialogs.h`: `BOOL DlgItemTextFitsU8(HWND dlg, int ctrlID, CTransferInfo* ti, int bufSize)`
  - the generalised 214 `CopyMoveTargetTextFits`: when the text of `ctrlID` does not fit,
  "The path specified is too long." and `ti->ErrorOn(ctrlID)` (or, without `ti`, the focus and
  selection on the control); a missing control passes. 214's two calls use it.

### Sites

| Site | Change |
|---|---|
| `CFileListDialog::Validate` | refuse `IDC_FL_LINE` (MAX_PATH) before `ValidateMakeFileList`; refuse `IDC_FL_FILENAME` (MAX_PATH) when the destination is File |
| `CFileListDialog::Transfer` | from-window: store the file name only when it fits (otherwise keep the previous `FileListName`) |
| `CFileListDialog` `IDC_FL_FNBROWSE` | refuse instead of browsing from a cut name |
| `CCfgPageUserMenu::StoreControls` | whole text into the item (`SalGetWindowTextU8Alloc`) |
| `CCfgPageUserMenu::Validate` | every item, before the existing checks: Command / Initial directory `MAX_PATH`, Arguments `USRMNUARGS_MAXLEN` - refuse, select, mark |
| `CCfgPageViewers` / `CCfgPageEditors` `StoreControls` / `Validate` | the same with `MAX_PATH` for all three |
| `CCfgPageHotPath::StoreControls` / `StoreName` | whole text, no code-page fallback |
| `CCfgPageHotPath::Validate` | every slot: path `HOTPATHITEM_MAXPATH`, name `MAX_PATH` - refuse, select, mark |
| `CCfgPageDrives` | new `Validate`: an edited `IDE_DRVSPEC_ONERRGOTO` must fit `MAX_PATH`; browse refuses |
| `CEditNewFileDialog` "Save as default" | refuse; the default unchanged |
| `InvokeDirectoryMenuCommand` browse (`salamdr3.cpp`) | refuse (fits `MAX_PATH`) |
| `CCompareArgsDlg` `IDB_UMC_BROWSENAME1/2` (`dialogs2.cpp`) | refuse (fits `MAX_PATH`) |

The pages' items are heap strings, so the whole text costs nothing; `Validate` runs on OK
(`_TPD_IDC_OK`) and on leaving the page (`PSN_KILLACTIVE`), so no item longer than its loader's
buffer reaches the configuration. In-page uses of an item while editing (icon lookup through
`ExpandCommand(..., MAX_PATH)`) refuse too long input by themselves.

## Project Structure

### Documentation (this feature)

```text
specs/251-dialog-text-fits/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/text-fits.md
├── fix-log.md, closing-report.md
└── probe/dlg251_probe.ps1, result_*.txt
```

### Source Code

```text
src/common/salunicode.h, salunicode.cpp   SalWTextFitsU8
src/common/winlib.h, winlib.cpp           SalWindowTextFitsU8, SalGetWindowTextU8Alloc
src/saltests/saltests.cpp                 checks of the rule
src/dialogs.h, dialogs3.cpp               DlgItemTextFitsU8 (214 generalised), Edit New default
src/dialogs.cpp                           Make File List
src/dialogs4.cpp                          user menu, hot paths
src/dialogs5.cpp, cfgdlg.h                drives, viewers, editors
src/dialogs2.cpp, salamdr3.cpp            browse-from-field
```

**Structure Decision**: the existing core layout; no new files besides the feature's docs.

## Complexity Tracking

None.
