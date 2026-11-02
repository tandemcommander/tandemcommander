# Research - 389-compare-icon-fits

## R1 - Where the cut text is read

- Decision: measure in `CCompareArgsDlg::Validate`, in a new `CChangeIconDialog::Validate` and at
  the top of `CChangeIconDialog::LoadIcons`.
- Rationale: winlib's IDOK calls `ValidateData` before `TransferData` (`src/common/winlib.cpp`
  `CDialog::DialogProc`), so `Validate` protects `Transfer`. But the Change Icon dialog reloads its
  icons from the field on EN_KILLFOCUS (the OK click moves the focus first - measured: the probe's
  first OK reloaded and the dialog closed) and on OK of a changed field; `LoadIcons` reads the field
  itself and fell back to the code-page text - measured "Cannot find the file ...???.exe" and
  SHELL32.DLL stored. So `LoadIcons` needs the check too.
- Alternatives: enlarging the buffers (`CompareName1/2`, the User Menu icon value) - rejected: the
  names go on into `ExpandUserMenuArguments` / the registry value read with `MAX_PATH`; the standing
  rule is refuse, never cut (097, 098, 101), and 251 / 270 / 291 refused the same way.

## R2 - What a refused reload leaves in the list

- Decision: the list keeps what it showed; the field keeps the typed text.
- Rationale: conservative (changes least); OK stays refused by `Validate` until the name fits, so
  nothing from the old list is stored for the new name. Falling back to SHELL32.DLL (the existing
  "cannot find" path) would overwrite the user's text - that is the defect.

## R3 - Callers

- `CCompareArgsDlg`: `CMainWindow::UserMenu` (`src/mainwnd4.cpp`) - the panels' User Menu
  (`src/mainwnd3.cpp`) and the Find dialog's User Menu (`src/finddlg1.cpp`).
- `CChangeIconDialog`: the User Menu configuration page only (`src/dialogs4.cpp`,
  `IDB_UM_CHANGEICON`).
