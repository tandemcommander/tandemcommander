# Fix log - 389-compare-icon-fits

Backlog item `user-menu-compare-names-and-the-change-icon-file-are-cut-to` - User Menu compare
names and the Change Icon file are cut to 259 bytes.

## Measurement at df4d92be (before)

Sites (found by name at HEAD):
- `src/dialogs2.cpp` `CCompareArgsDlg::Validate` - reads both fields into `char buf[MAX_PATH]`
  with `ti.EditLine` (only an empty check); `Transfer` - `ti.EditLine(IDE_UMC_NAME1/2,
  CompareName1/2, MAX_PATH)` (cut at a whole character).
- `src/dialogs3.cpp` `CChangeIconDialog::Transfer` - `ti.EditLine(IDE_CHI_FILENAME, IconFile,
  MAX_PATH)`; **also** `CChangeIconDialog::LoadIcons` - reads the field as wide text, and when
  `SalWToU8` does not fit 260 bytes falls back to the code-page `GetDlgItemText` (best fit /
  `?`). `LoadIcons` runs on EN_KILLFOCUS of the changed field and on OK of a changed field - before
  OK reaches `Validate`, so a `Validate` alone would not be enough.

Callers (Grep):
- `CCompareArgsDlg`: only `CMainWindow::UserMenu` (`src/mainwnd4.cpp`), reached from the panels'
  User Menu (`mainwnd3.cpp`, `CM_USERMENU_MIN + i`) and the Find dialog's User Menu
  (`finddlg1.cpp`).
- `CChangeIconDialog`: only the User Menu configuration page, button `IDB_UM_CHANGEICON`
  (`src/dialogs4.cpp`). The hot path configuration does not use it. The page's `fileName` is
  `MAX_PATH + 10`; the stored `Icon` value is read with `MAX_PATH` (no overflow there).
- `BrowseCommand` (both dialogs' Browse) already refuses a picked name >= MAX_PATH (172); the
  compare dialog's folder browse measures with `DlgItemTextFitsU8` (251).

Probe `specs/389-compare-icon-fits/probe/fit389_probe.ps1` (hidden desktop, Debug x64 of
df4d92be, ACP 1250): `result_before.txt` 4 FAIL / 6 PASS (the chi-ctl row's first verdict was the
probe's fault - it expected two OKs; the OK click moves the focus, EN_KILLFOCUS loads the icons and
the click ends the dialog; fixed, `result_before_chi.txt` chi-ctl PASS, chi-file FAIL):
- umc-name1 FAIL: name 1 = `C:\` + 86 CJK + `a` (262 bytes): dialog closed, nothing asked, the
  command wrote `C:\` + 85 `?` + `#C:\b` - the tail `a` lost (cut).
- umc-name2 FAIL: the same for name 2 (tail `b` lost).
- umc-ctl PASS: two names of 259 bytes reached the command whole.
- chi-file FAIL: `<fixture>\icons\<86 CJK>.exe` (312 bytes, exists): "Cannot find the file
  ...\icons\ ???...???.exe", the field replaced by `C:\WINDOWS\system32\SHELL32.DLL`, the next OK
  stored SHELL32.DLL (Change Icon opened again shows it).
- chi-ctl PASS: a 259-byte name loaded and was stored whole.

Command:
`powershell -File tools\run_on_hidden_desktop.ps1 -Log <...>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <...>\fit389_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib <...>\fix_probe_lib.ps1"`
(run from the scratchpad before the branch existed; the copy in `probe/` is the same script).

## Decisions

- `CCompareArgsDlg::Validate`: `DlgItemTextFitsU8(..., &ti, MAX_PATH)` for name 1, then name 2,
  before the empty checks.
- `CChangeIconDialog`: a new `Validate` with `DlgItemTextFitsU8(IDE_CHI_FILENAME, &ti, MAX_PATH)`;
  `LoadIcons` measures first (`DlgItemTextFitsU8(..., NULL, MAX_PATH)`) and returns FALSE without
  touching the list (conservative: no other file is read, the field keeps its text).
