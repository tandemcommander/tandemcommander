# Fix log: 251 - typed text is never cut to the caller's buffer

Backlog item `dialog-typed-text-cut-to-caller-buffer` (left by the review of 214): the same cut as
214's Copy / Move dialogs in Make File List, the user menu, viewers / editors, hot paths, the drives
page, Edit New's default and the browse-from-field buttons.

## Measured (before, c7f07bc6)

Sites at HEAD (found by name, the item's line numbers had moved):
- `CFileListDialog::Transfer` - `ti.EditLine(IDC_FL_FILENAME, Configuration.FileListName, MAX_PATH)`
  (core `CTransferInfo::EditLine` cuts at a whole character, 093), the line history
  `SalGetWindowTextU8(hWnd, buff, MAX_PATH)`; `CFileListDialog::Validate` reads the line and the file
  name into `MAX_PATH` buffers; `CMainWindow::MakeFileList` writes to `Configuration.FileListName`.
- `CCfgPageDrives::Transfer` - `ti.EditLine(IDE_DRVSPEC_ONERRGOTO, newPath, MAX_PATH)`; its
  `IDB_BROWSECOMMAND` reads the field into `MAX_PATH`.
- `CCfgPageUserMenu::StoreControls`, `CCfgPageViewers::StoreControls`,
  `CCfgPageEditors::StoreControls` - called on every `EN_CHANGE`, read into `MAX_PATH` /
  `USRMNUARGS_MAXLEN` buffers and `item->Set(...)` (the items are heap strings). The pages work on a
  copy; `Validate` runs on leaving the page (`PSN_KILLACTIVE`) and on OK (`_TPD_IDC_OK`).
  The configuration loads these values back with `GetValue(..., MAX_PATH)` (user menu: an item
  whose value does not fit is not loaded at all) - nothing longer may reach the configuration.
- `CCfgPageHotPath::StoreControls` / `StoreName` - wide read into a fixed buffer, and when the
  UTF-8 does not fit, `GetDlgItemText` (code page: `?`).
- Edit New's menu "Save as default" (`CEditNewFileDialog::DialogProc`, `IDB_BROWSE`):
  `SalGetDlgItemTextU8(..., Configuration.EditNewFileDefault, MAX_PATH)`.
- Browse-from-field: `InvokeDirectoryMenuCommand` (`salamdr3.cpp`, `DIRECTORY_COMMAND_BROWSE`),
  `CCfgPageDrives` `IDB_BROWSECOMMAND`, the user-menu compare dialog `IDB_UMC_BROWSENAME1/2`
  (`dialogs2.cpp`); also Make File List's `IDC_FL_FNBROWSE` (same dialog, not in the item's list).

Probe `probe/dlg251_probe.ps1` (written for this feature in the style of 214's; Debug x64 build of
c7f07bc6 copied to `build\tandemcommander\Debug_x64_pre251`), hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\251-dialog-text-fits\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\251-dialog-text-fits\probe\dlg251_probe.ps1 -Exe build\tandemcommander\Debug_x64_pre251\tandemcommander.exe -Label before"
```

Result (first runs from a scratch copy, the probe fixed twice on the way - the Configuration
dialog's OK button is id 5, a posted IDOK reached the page only; the seeded user menu item needs an
initial directory): every refusal row FAIL, the control PASS:
- mfl-name: a name of 274 bytes / 132 units - the list was written to `out\<67 CJK letters>`
  (no `.txt`) - **another file**;
- mfl-line: a format of 291 bytes - `list.txt` written without the `END` + line end;
- um-cmd: 277 bytes stored as 258; um-args: 33,000 bytes stored as 32,769;
- vw-cmd, ed-cmd: 277 bytes stored as 258;
- hp-path: 403 units stored as 403 `?`... (code page); hp-name: 100 units stored as `?`;
- drv-goto: 273 bytes stored as 258; drv-browse: "Select Path" opened from the cut path;
- en-default: the default stored as 258 bytes (86 letters);
- mfl-ctl: PASS (the list in `list.txt`).

## Decisions

- One pure rule `SalWTextFitsU8(const WCHAR*, int bufSize)` in `salunicode` (saltests), used by a
  winlib helper `SalWindowTextFitsU8(HWND, int)` and by a core refusing helper
  `DlgItemTextFitsU8(HWND dlg, int ctrlID, CTransferInfo* ti, int bufSize)` (dialogs3.cpp, the
  generalised 214 `CopyMoveTargetTextFits`).
- Pages that store on every keystroke keep the **whole** text in the item (a heap read,
  `SalGetWindowTextU8Alloc`) and refuse in `Validate` by length - before the existing checks.

## Work

(in progress)
