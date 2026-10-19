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

## Analyze

`speckit-analyze`: no CRITICAL / HIGH. Accepted: C1 (MEDIUM) - of the four browse-from-field
buttons only the drives page's is driven by the probe (`drv-browse`); the directory menu
(`InvokeDirectoryMenuCommand`, a popup menu), `CCompareArgsDlg` and Make File List's file browse
use the same helper and are checked by reading and review. C2 / F1 (LOW): no change needed.

## Work

- `src/common/salunicode.h/.cpp`: `SalWTextFitsU8` (wide text vs a UTF-8 buffer, WTF-8, fail
  closed) and `SalU8TextFits` (a value already in UTF-8, kept whole by a page).
- `src/common/winlib.h/.cpp`: `SalWindowTextFitsU8`, `SalGetWindowTextU8Alloc` (beside
  `SalGetWindowTextU8`).
- `src/dialogs.h`, `src/dialogs3.cpp`: `DlgItemTextFitsU8(dlg, ctrlID, ti, bufSize)` - 214's
  `CopyMoveTargetTextFits` generalised (both 214 calls use it); without `ti` the field is focused
  with its text selected. Edit New's "Save as default" calls it - the default unchanged.
- `src/dialogs.cpp` Make File List: `Validate` refuses the line (before `ValidateMakeFileList`)
  and, with the destination File, the name (before `SalGetFullName`); `Transfer` stores the name
  only when it fits (another destination: the previous name stays); the file browse refuses.
- `src/dialogs4.cpp` user menu: `StoreControls` keeps the whole texts; `Validate` checks every item
  (every type) before the existing checks - Command / Initial directory `MAX_PATH`, Arguments
  `USRMNUARGS_MAXLEN`: the item selected, the message, the field marked.
- `src/dialogs5.cpp` viewers / editors: the same (`ViewEditTooLongField` /
  `ViewEditRefuseTooLong`, `MAX_PATH` for all three - their loader's size, `salamdr2.cpp`).
- `src/dialogs4.cpp` hot paths: `StoreControls` / `StoreName` read whole, the code-page fallback
  is gone; `Validate` refuses a path >= `HOTPATHITEM_MAXPATH` or a name >= `MAX_PATH` bytes.
- `src/cfgdlg.h`, `src/dialogs5.cpp` drives: new `CCfgPageDrives::Validate` (an edited "go to"
  path must fit `MAX_PATH`); the browse button refuses.
- `src/salamdr3.cpp` (`InvokeDirectoryMenuCommand`, browse) and `src/dialogs2.cpp`
  (`CCompareArgsDlg`, folder browse): refuse instead of browsing from a cut path.
- `src/saltests/saltests.cpp`: `TestTextFits251` (ASCII / CJK exact fit and one over, the
  measured 90 CJK letters, surrogate pair 4 bytes, lone surrogates 3, empty / NULL, zero and
  negative buffers, agreement with `SalWToU8`; `SalU8TextFits` likewise).

Not changed (out of the item's scope, noted): the hot path list's in-place label edit
(`LVN_ENDLABELEDIT`, a display label cut at a whole character into `MAX_PATH`); the hot path
label shown while a too-long path is being edited (`GetDisplayName` into `MAX_PATH`, display only,
refused at OK).

## Checks

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd`: `BUILD SUCCEEDED` (warnings only in untouched `salamdr2.cpp` / `zip.cpp`).
- `saltests`: `24352 checks, 0 failed` (24,342 before the `SalU8TextFits` checks).
- Negative control: `SalWTextFitsU8` loosened by one byte (`need <= bufSize + 1`) - `saltests`
  `8 failed`; reverted, rebuilt, `0 failed`.
- No UI string added or removed (`IDS_TOOLONGPATH` exists) - no `.slt` refresh needed.

## Measured (after)

The probe got four control rows (`um-ctl`, `vw-ctl`, `hp-ctl`, `drv-ctl`: CJK text that fits
exactly, 259 / 1,039 bytes + NUL - accepted, nothing asked, stored whole), then ran on both builds:
- `probe/result_before.txt` (Debug_x64_pre251, c7f07bc6): PASS 21, FAIL 11 - exactly the 11
  refusal rows; every control and END row PASS; registry restored identical.
- `probe/result_after.txt` (this branch): PASS 32, FAIL 0 - every refusal row "The path specified
  is too long.", the dialog stayed open; Make File List's `out\` empty; Edit New's default still
  `new.txt`; the drives browse showed the refusal and no "Select Path"; registry restored identical.
- `probe/regress_214.txt`: 214's `cm_text_probe.ps1` PASS 4, FAIL 0.

## Review

### Review 1 (refute-first agent) - 1 MUST, 2 SHOULD, 5 NOTE

It re-ran the build, `saltests`, the encoding guard, the probe (32 / 0) and, as a negative control,
rows on the build before (the measured failures reproduced).
- **MUST 1** - hot paths: `CCfgPageHotPath::LoadControls` still read the slot into fixed buffers
  (`GetName(..., MAX_PATH)`, `GetPath(..., HOTPATHITEM_MAXPATH)`, cut by bytes). When the refused
  slot was not the selected one, `Validate` selected it, `LoadControls` reloaded it cut - inside a
  letter, the wide conversion failed and the code-page fallback showed mojibake (1,039 units);
  a mixed path (1,000 `a` + 20 CJK) was shown cut at a whole letter, and one more edit stored the
  cut path without a word. **Fixed**: `CHotPathItems::PeekName` / `PeekPath` (`src/mainwnd.h`,
  the whole stored text) and `LoadControls` shows them whole.
- SHOULD 2 - no row refused a slot other than the selected one: **added** `hp-other`,
  `hp-other-mixed`, `hp-other-name` (Down in the list after typing; the row checks the selection
  moved, and every refusal row now also checks the field holds the typed text at the refusal).
  Negative control: the old `LoadControls` restored temporarily - the three rows FAIL (1,039 units
  / 2,175 bytes of mojibake; 1,015 units / 1,039 bytes cut; 259 units / 548 bytes), `hp-path`
  still PASS; the fix back, rebuilt.
- SHOULD 3 - two claims without a row: **added** `mfl-keep` (destination Viewer: the next Make
  File List shows the previous name; before: a 258-byte cut name) and `mfl-browse` (refused; before:
  "Save As" opened). Still read-only checked: the directory menu's browse (`InvokeDirectoryMenuCommand`,
  a popup menu) and `CCompareArgsDlg`'s - the same `DlgItemTextFitsU8(..., NULL, MAX_PATH)` call as
  the driven `drv-browse` / `mfl-browse`.
- NOTE 4 - the hot path list label cut inside a letter while a long name is typed: **fixed**
  (`SalU8TrimIncompleteTail` in `RefreshItemLabel`).
- NOTE 5 - 172's `BrowseDirCommand` (the hot path page's own browse) opens without a starting
  folder for a long text, the new browse buttons refuse: kept (the item's *Expected* says refuse;
  172's behaviour is not part of this item).
- NOTE 6 - the same class of cut outside the item's list (Select / Unselect and Convert masks,
  the filter, the volume label, the hot path label edit): **recorded** as an Inbox item
  (`leftover:251`).
- NOTE 7 - without memory, `StoreControls` leaves the item's previous value: accepted (no cut, the
  previous value is the user's own).
- NOTE 8 - closing records: done at closing.

Checks after the fixes: `BUILD SUCCEEDED`; `saltests` 24352 / 0; encoding guard `TOTAL: 0`;
probe `result_after.txt` **PASS 42, FAIL 0**, registry restored identical; `result_before.txt`
(Debug_x64_pre251) PASS 26, FAIL 16 - exactly the 16 refusal rows, every control and END row PASS.
