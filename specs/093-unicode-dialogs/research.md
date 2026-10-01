# Research: encoding cluster B-1 — "ANSI dialog windows"

Read-only research at HEAD of `088-plugin-interface-107` (2026-10-01). No repository
file was changed. Line numbers are HEAD's (several have moved since the 068/069
reports — e.g. `CChangeDirDlg` is now `dialogs3.cpp:1193`, not `:1180`).

Two kinds of evidence are used and kept apart:

- **[code]** — read in the tree, file:line given.
- **[probe]** — measured on this machine (ACP 1250) with a throw-away Win32 probe,
  `scratchpad\b1probe\B1Probe.cs` (+ `result.txt`), compiled with `Add-Type` and run
  on invisible windows. It creates the same dialog template through the A and the W
  entry point, posts `WM_CHAR` for `a ř Ж 日` (0061 0159 0416 65E5) and reads the
  text back wide. It does **not** drive Tandem Commander itself.
- Anything not covered by either is marked **[not verified]**.

**Probe caveat.** Characters are *posted* (`PostMessageW(WM_CHAR)`), not produced
by `TranslateMessage` from real keystrokes. In the ANSI windows `ř` came back as
`r` although ACP is 1250 and the thread's layout is Czech — the `WM_CHAR` W→A
down-conversion is evidently not a plain ACP conversion on a thread without real
input. Read the ANSI rows only as "lossy", not as the exact glyph a user gets. The
Unicode rows (all four units intact, or not) are unambiguous.

---

## 0. Corrections to the task's premises (measured)

1. **"With GetMessageA/DispatchMessageA, WM_CHAR for a Unicode window is still
   delivered correctly" — false.** [probe] A Unicode edit pumped with
   `PeekMessageA`+`DispatchMessageA` receives `0061 0072 003F 003F`; with
   `PeekMessageW`+`DispatchMessageW` it receives `0061 0159 0416 65E5`. The
   retrieval call converts the character, so **the pump matters as much as the
   window**. `PeekA + IsDialogMessageW` is lossy too.
2. **`IsDialogMessageA` on a message taken with `GetMessageW` corrupts every
   non-ASCII character, for Unicode *and* ANSI controls** [probe]: result
   `0061 0059 00E5` (Unicode edit) / `0061 0059 013A` (ANSI edit) — the UTF-16
   unit is re-read as code-page bytes (`0159`→`Y`). That is exactly the shape of
   the main loop: `GetMessageW` (`salamdr1.cpp:4646`) … `IsDialogMessage` = A
   (`:4682`) … `DispatchMessageW` (`:4689`). It only bites a **modeless winlib
   dialog active on the main thread**; I found no such dialog with a text field
   today (modal dialogs run USER32's own loop, Find and the viewers have their own
   threads, Configuration has its own loop), so it is **latent** — but it is the
   first thing a modeless Unicode dialog on the main thread would hit. [code+probe;
   absence of a victim not exhaustively verified]
3. **The count is now 89 of 91**, not 88 of 90: 63 `CCommonDialog`/`CDialog` + 28
   property pages in `src/*.cpp`, 2 Unicode (`dialogs3.cpp:394`, `:594`). [code]
4. **Property pages are not "ANSI unconditionally" in the path the product uses.**
   The only property dialog is `CConfigurationDlg : CTreePropDialog`
   (`cfgdlg.h:1196`). In tree mode pages are created by `ChildDialog->Create()`
   (`sheets.cpp:1113`) = `CDialog::Create`, which already honours `UnicodeWnd`
   (`winlib.cpp:628-641`). What is missing is only (a) a constructor parameter —
   `CPropSheetPage` passes none (`sheets.cpp:185-194`, `salamand.h:814-820`) — and
   (b) a wide pump in the holder (`sheets.cpp:1167-1179`, see §3). The classic
   `PropertySheet()`/`CreatePropertySheetPage()` path (`sheets.cpp:277,499`) is A
   only but has no caller in core.

---

## 1. How dialogs are created and how text is exchanged

### 1.1 Classes and creation calls [code]

| Layer | Where | Creation |
|---|---|---|
| `CWindowsObject` | `src/common/winlib.h:73-132` | carries `BOOL UnicodeWnd` (`:131`), no default at this level |
| `CWindow` | `winlib.h:138-200` | `unicodeWnd = FALSE` default (`:144,154,166`); `CreateEx` → `CreateWindowEx` (A), `CreateExW` → `CreateWindowExW` (`winlib.cpp:190-216`); `AttachToWindow` subclasses with `SetWindowLongPtrW` + `CWindowProcW` if `UnicodeWnd`, else the A pair (`winlib.cpp:251-292`) |
| `CDialog` | `winlib.h:366,380`; `winlib.cpp:614-641` | `Execute()`: `DialogBoxParamW` if `UnicodeWnd` (`:619-622`) else `DialogBoxParam` = A (`:625`). `Create()`: `CreateDialogParamW` (`:633-636`) else A (`:639`). **One** dialog procedure, `CDialog::CDialogProc` (`:712`), for both |
| `CCommonDialog` | `src/salamand.h:755-800` | `unicodeWnd = FALSE` default (`:768,782`); comment `:763-765` states the mechanism |
| `CPropSheetPage` / `CCommonPropSheetPage` | `src/common/sheets.cpp:185-194`, `salamand.h:814` | no `unicodeWnd` parameter at all |
| `CTreePropHolderDlg` | `sheets.cpp:667`, `:1160-1184` | `CreateDialogIndirectParam` (A, `:1164`), own loop `GetMessage`/`IsDialogMessage`/`DispatchMessage` — all A (`:1167-1179`) |
| Plug-in copy | `src/plugins/shared/winliblt.{h,cpp}` | `CDialog::Execute` → `DialogBoxParam` (A, `winliblt.cpp:445`), `Create` → A (`:452`); **no `UnicodeWnd` concept**; `AttachToWindow` always `SetWindowLongPtr` (A, `:226`) |

### 1.2 Text exchange helpers that already exist [code]

All in `src/common/winlib.cpp`, compiled only `#if defined(INSIDE_SALAMANDER) && !defined(_UNICODE)`:

| Helper | Line | What it does |
|---|---|---|
| `CTransferInfo::EditLine(int, char*, DWORD, BOOL)` | `:1042-1096` | to window: `SalU8ToWAlloc` + `SendMessageW(EM_LIMITTEXT)` + `SendMessageW(WM_SETTEXT)`; from window: `GetWindowTextLengthW`/`GetWindowTextW` + `SalWToU8`; **fallback `SendMessage(WM_GETTEXT)` (A) when the UTF-8 does not fit** (`:1091`) |
| `CTransferInfo::EditLineW` | `:1240-1262` | plain wide exchange |
| `SalSetWindowTextU8` / `SalGetWindowTextU8` | `:1101-1132` | `SetWindowTextW` / `GetWindowTextW`+`SalWToU8`, A fallback |
| `SalSetDlgItemTextU8` / `SalGetDlgItemTextU8` | `:1134-1152` | the same via `GetDlgItem` |
| `SalComboAddStringU8`, `SalListBoxAddStringU8` | `:1154-1166`, `:1188-1200` | `SendMessageW(CB_ADDSTRING / LB_ADDSTRING)` |
| `SalListViewSetItemTextU8`, `SalStatusSetTextU8`, `SalInsertMenuItemU8` | `:1202-1236`, `:1168-1186` | distinct W message numbers / not a window message → **not** affected by B-1 |

There is no `EditLineU8`; `EditLine` itself is the UTF-8 one. `IsWindowUnicode` is
already used at the three places that had to learn about feature 015:
`CreateKeyForwarder` (`salamdr3.cpp:4045`), `AttachBackspaceHandler`
(`editwnd.cpp:260`), `BSHandlerSubclassProc` (`editwnd.cpp:237,247`).
The plug-in copy has the same wide `EditLine` (`winliblt.cpp:1097-1146`); its
comment "standard controls are Unicode windows" (`:1108`) is wrong for an A dialog.

**So the helpers are already right; on 89 dialogs the window underneath them is not.**

### 1.3 What exactly makes an edit control an "ANSI window" [probe]

| Question | Measured answer |
|---|---|
| Does the dialog entry point decide? | **Yes.** `CreateDialogIndirectParamA` → dialog, edit, combo and the combo's inner edit all `IsWindowUnicode = FALSE`. Same template, same `DLGPROC`, `…ParamW` → all four `TRUE`. The dialog procedure has no A/W flavour of its own |
| ANSI edit: `SetWindowTextW("ařЖ日")` then `GetWindowTextW` | `0061 0159 003F 003F` — lost **at storage** |
| ANSI edit: `SendMessageW(EM_REPLACESEL)` / `CB_ADDSTRING`+`CB_GETLBTEXT` (W) | same loss |
| ANSI edit: typed `WM_CHAR`, any pump | lossy |
| Can an ANSI edit be *turned* Unicode by subclassing with `SetWindowLongPtrW`? | **No.** `IsWindowUnicode` flips to `TRUE`, but text is still `0061 0159 003F 003F` — the control decided its internal storage at creation |
| Unicode edit subclassed with `SetWindowLongPtrA` | flips to `IsWindowUnicode = FALSE`; text already stored reads back as `?`, new text and typing are lossy. Restoring the original procedure flips it back |
| Unicode edit: `SendMessageA(WM_SETTEXT, ACP bytes)` | converted correctly (`0061 0159 007A`) — A calls into a Unicode window keep working |
| Unicode edit: `GetWindowTextA` | `61 F8 3F 3F` — ACP projection, as expected |
| `CreateWindowExW("EDIT")` child inside an **A** dialog | `IsWindowUnicode = TRUE`, full round trip, typed text intact when the pump is wide |
| comctl32 `SetWindowSubclass` on a Unicode edit | stays Unicode, round trip intact (second mini-probe) |

**Answer to "can a child EDIT of an ANSI dialog keep non-ACP text via
SetWindowTextW/GetWindowTextW?"** — No. If the dialog manager created it from an
A dialog it is an ANSI control: the wide setter is down-converted before storage
and typed characters arrive already converted. Only a control *created* Unicode
(by a W dialog, or by `CreateWindowExW`) keeps them.

### 1.4 The message pump [probe + code]

| Pump | Unicode edit receives | Where this shape is in the tree |
|---|---|---|
| USER32's own modal loop, `DialogBox…W` | `0061 0159 0416 65E5`, surrogate pair `D83D DCC1` intact | every `CDialog::Execute()` with `UnicodeWnd` |
| USER32's own modal loop, `DialogBox…A`, Unicode **child** edit | intact | (approach ii) |
| `PeekW + IsDialogMessageW (+DispatchW)` | intact | — (nowhere yet) |
| `PeekW + DispatchW` | intact | main loop for non-dialog windows, `salamdr1.cpp:4646,4688-4689` (panel, quick rename, command line) |
| `PeekW + IsDialogMessageA` | **corrupted** `0061 0059 00E5` | main loop for an active winlib dialog, `salamdr1.cpp:4682` |
| `PeekA + IsDialogMessageA (+DispatchA)` | **lossy** `0061 0072 003F 003F` | Find thread `find.cpp:2072-2089`; Configuration holder `sheets.cpp:1167-1179` |
| `PeekA + DispatchA` | lossy | secondary pumps: `finddlg1.cpp:2181-2184`, `:4604-4607`, `dialogs.cpp:1446-1449`, `mainwnd2.cpp:3839`, `mainwnd3.cpp:6154,6795`, viewer thread `viewer2.cpp:315-320`, wait window `salamdr2.cpp:358` |

For **ANSI** controls the wide pump gives the same result as the A pump
(`PeekW + IsDialogMessageW` = `PeekA + IsDialogMessageA` in the probe), so
converting a loop to W is neutral for dialogs that stay ANSI.

### 1.5 The counter-examples [code]

| What | Where | How |
|---|---|---|
| `CCopyMoveDialog` (Copy/Move without options, Create Directory, Rename dialog, Edit New via `CEditNewFileDialog` `dialogs3.cpp:523`) | `dialogs3.cpp:389-395` | **approach (i)**: `TRUE /*unicodeWnd*/` → `DialogBoxParamW`, procedure unchanged. Feature 015 |
| `CCopyMoveMoreDialog` (Copy/Move with options) | `dialogs3.cpp:588-595` | the same |
| Fixes feature 015 needed around them | `salamdr3.cpp:3966-3981`, `:4042-4050` (`CKeyForwarder` takes `IsWindowUnicode`), `editwnd.cpp:234-270` (backspace subclass keeps the W/A flavour), `editwnd.cpp:296-300` (word-break callback: `EditWordBreakProcUNICODE` when comctl32 ≥ 6) | the ANSI subclass flipped the combo's edit back to ANSI — the trap of §5.1 |
| Quick-rename inline edit | `fileswn5.cpp:2914` (`CWindow(ooStatic, TRUE)`), created with `CreateExW`; read `GetWindowTextW` `:2619`, `:2829` | Unicode child of the (Unicode) panel, pumped by `PeekW + DispatchW` — this is approach (ii)'s mechanism, outside a dialog |
| Panel list `CFilesBox` | `filesbx1.cpp:25` | Unicode window class |
| Feature 071 Command Shell page | `dialogs4.cpp:4301` | **stayed ANSI.** Only the Browse button is wide (`SafeGetOpenFileNameW`, `dialogs4.cpp:4399-4430`, `salamdr6.cpp:1782`). The two fields (`EditLine` `:4450-4451`) still lose non-ACP input |
| Feature 004 | `salamdr1.cpp:4644-4646` | made the main pump W "for the Unicode panel window"; left `IsDialogMessage` A |
| Plug-ins outside winliblt | `mdview/viewer.cpp:678`, `codeview/viewer.cpp:751,764` (`DialogBoxParamW` with a plain `DLGPROC`); `regedt/dialogs.cpp:327-366` (own W dialog classes) | approach (i) at the raw API level |

---

## 2. Inventory of text-entry controls

"Read" = how the text leaves the control. All dialogs below are ANSI unless marked
**W**. Registry values go through the UTF-8 facade (§4).

### (a) Path / name / mask entry that is actioned or persisted

| # | Surface | Class, ctor | Resource / control | Read by | Stored / used |
|---|---|---|---|---|---|
| a1 | Change Directory (Shift+F7) | `CChangeDirDlg` `dialogs3.cpp:1193` | `IDD_CHANGEDIR` / `IDE_PATH` (combo) | `SalGetWindowTextU8` `:1214`; prefill `:1210` | change-dir target; `Configuration.ChangeDirHistory` → reg `ChangeDir History` (`mainwnd2.cpp:234,1960`) |
| a2 | Copy / Move, Create Directory, Rename dialog, Edit New | `CCopyMoveDialog` `:389`, `CCopyMoveMoreDialog` `:588`, `CEditNewFileDialog` `:523` | `IDD_COPYMOVEDIALOG[_CB[_BT]]`, `IDD_COPYMOVEMOREDIALOG`, `IDE_PATH` | `SalGetWindowTextU8` `:439`, `:640`; `EditLine` `:452`, `:653` | **W already.** Copy/CreateDir/QuickRename/EditNew histories. Remaining ANSI bit: the *named mask* field `IDC_CM_NAMED_MASK` is inside the W dialog, so it is fine |
| a3 | Quick rename in the panel | `CQuickRenameWindow` `fileswn5.cpp:2914` | inline edit | `GetWindowTextW` `:2619`, `:2829` | **W already** |
| a4 | Find (Alt+F7): Named, Look in, Containing | `CFindDialog` `finddlg1.cpp:1366` (modeless, own thread) | `IDD_FIND` / `IDC_FIND_NAMED` 2505, `IDC_FIND_LOOKIN` 2501, `IDC_FIND_CONTAINING` 2504 | `SalGetWindowTextU8` `:1778,1792`; `HistoryComboBox` `:1811,1813,1818`; `SalGetDlgItemTextU8` `:1843-1847` | search root / mask / grep text; reg `Named History`, `Look In History`, `Grep History` (`mainwnd2.cpp:1950-1955`) |
| a5 | Pack | `CPackDialog` `dialogs3.cpp:1885` | `IDD_PACK` / `IDE_PATH` | `EditLine` `:1967` | archive target path |
| a6 | Unpack | `CUnpackDialog` `dialogs3.cpp:2151` | `IDD_UNPACK` / `IDE_PATH`, `IDE_MASK` | `EditLine` `:2213`, `:2220` | target path, mask |
| a7 | Select / Unselect by mask | `CSelectDialog` `dialogs2.cpp:~560` | `IDE_FILEMASK` | `SalGetWindowTextU8` `:576,607` | selection mask; `SelectHistory` |
| a8 | Panel filter | `CFilterDialog` `dialogs3.cpp:262` | `IDD_CHANGEFILTER` / `IDE_FILTER` | `EditLine` `:281,305`, `SalGetWindowTextU8` `:321` | filter masks; `FilterHistory`, per-panel filter |
| a9 | Convert (mask) | `CConvertFilesDlg` `dialogs3.cpp:57` | `IDD_CHANGECODING` | `SalGetWindowTextU8` `:118`; A `WM_GETTEXT` `:78` | mask; `ConvertHistory` |
| a10 | Make File List | `CFileListDialog` `dialogs.cpp:1849` | `IDD_FILELIST` / `IDC_FL_FILENAME` + format combo | `EditLine` `:1864`, `SalGetWindowTextU8` `:1883,1900,1919`, `SalGetDlgItemTextU8` `:2005,2008` | output file name, `FileListHistory` |
| a11 | Compare Directories options | `CCompareDirsDialog` `dialogs6.cpp:1464` | `IDE_COMPARE_IGNORE_FILES/DIRS` | `EditLine` `:1534,1536` | ignore masks (config) |
| a12 | User-menu compare arguments | `CCompareArgsDlg` `dialogs2.cpp:1204` | `IDE_UMC_NAME1/2` | `EditLine` `:1235-1236`, `SalGetDlgItemTextU8` `:1275` | two file paths → external tool |
| a13 | Save / Load Selection | `dialogs6.cpp:1410`, `:1428` | — | `EditLine` `:1484` | masks |
| a14 | Change Icon | `CChangeIconDialog` `dialogs3.cpp:2310` | `IDE_CHI_FILENAME` | `EditLine` `:2340`, `GetDlgItemTextW` `:2369` | icon file path (user menu / hot path) |
| a15 | Drive Information — volume label | `CDriveInfo` `dialogs3.cpp:1270` | `IDE_VOLNAME` | `SalGetWindowTextU8` `:1284,1356` | written to the volume |
| a16 | Find: advanced / settings / ignore list | `filter.cpp:828`, `finddlg2.cpp:702`, `:966` | edit list boxes `:775`, `:1062` | `CEditListBox` (see c-row below) | stored find options, ignore paths |
| a17 | Internal viewer: Find text | `CFindSetDialog` `viewer.cpp:~330` | `IDC_FINDTEXT` | `HistoryComboBox` `:344` | searched text; `ViewerHistory` |
| **Configuration pages (tree property dialog)** | | | | | |
| a18 | Hot Paths | `CCfgPageHotPath` `dialogs4.cpp:2695` | `IDC_HOTPATH_PATH` 373, `IDC_HOTPATH_NAME`, list-view label edit | `GetDlgItemTextW` `:2901,2917`; `SalGetWindowTextU8` `:3217` | reg hot paths (`mainwnd1.cpp:244-245`) — **persisted** |
| a19 | User Menu | `CCfgPageUserMenu` `dialogs4.cpp:1997` | `IDE_COMMAND` 352, `IDE_ARGUMENTS`, `IDE_INITDIR`, edit list box `:2252` | `SalGetDlgItemTextU8` `:2192-2194` | user menu items — **persisted, and rewritten merely by selecting an item** (068 V2) |
| a20 | Viewers / Editors | `dialogs5.cpp:1919`, `:2357` | `IDE_COMMAND/ARGUMENTS/INITDIR`, mask list `:2154`, `:2506` | `SalGetDlgItemTextU8` `:2090-2092`, `:2472-2474` | reg viewers/editors |
| a21 | Packers / Unpackers / Archiver locations / Associations | `dialogsp.cpp:40`, `:463`, `:866`, `:1092` | `IDC_P1_*`, `IDC_P2_*`, `IDC_P3_*` | **A** `SendDlgItemMessage(WM_GETTEXT)` `:189,225-231,627,658-659,973,976,1047` | reg packer config (068 F-P2-12: UTF-8 values through A sinks — these pages need the Sal*U8 helpers *as well as* a Unicode window) |
| a22 | Command Shell (071) | `CCfgPageCmdShell` `dialogs4.cpp:4301` | `IDE_CMDSHELL_CUSTPROG`, `_CUSTARGS` | `EditLine` `:4450-4451`, `SalGetDlgItemTextU8` `:4408,4483,4504` | reg `Command Shell Program/Arguments` |
| a23 | Views (view name, masks), Viewer page masks, System (recycle masks), Drives (on-error path), Colors (highlight masks), Main Window (title prefix), Appearance (info line) | `dialogs4.cpp:993`, `:1637`, `:3315`, `:3476`; `dialogs5.cpp:1818`, `:2714`, `:2801` | various | `EditLine` `dialogs4.cpp:1668,1686,1718,1720,3331,3351`; `SalGetWindowTextU8` `:1524`; `dialogs5.cpp:1842-1888`, `:2754`, `:2863` | configuration |

Helpers shared by these dialogs that read the field with an **A** call and must
move with them: `BrowseDirCommand` `execute.cpp:1707-1720`, `BrowseCommand`
`execute.cpp:2132-2137` (A `WM_GETTEXT` + A `GetOpenFileName` — the browse sub-case
of F-P1-24), `DoHexValidation` `viewer.cpp:184`, `CEditListBox` (`edtlbwnd.cpp:474`
creates its inline edit with the A `Create("edit")`; reads `SalGetWindowTextU8`
`:542`) — used by ten pages/dialogs (`dialogs4.cpp:2252,3756`, `dialogs5.cpp:2154,2506`,
`dialogse.cpp:210`, `dialogsp.cpp:292,709,1269`, `finddlg2.cpp:775,1062`).

### (b) The command line

`CEditWindow::Create` `editwnd.cpp:1741` — `CreateEx(0, "ComboBox", …)` (A);
`CEditLine` (`:346`, `CWindow(ooStatic)`) subclasses the combo's edit (`:1773`).
Read `SalGetWindowTextU8` `:410`, `:2082`; write `SalSetWindowTextU8` (run-a-command
site), insert `SendMessageW(EM_REPLACESEL)` `:371`, `:1228`; history
`Configuration.EditHistory` → reg command history (`mainwnd2.cpp:1971`).
It is pumped by `PeekW + DispatchW` (the main window is not a dialog), so a Unicode
control would receive typed text intact [probe row "PeekW + DispatchW"].
What moves with a conversion (re-verified at HEAD, 069 R2's list):

| Item | Line |
|---|---|
| window creation → `CreateExW`, `CEditWindow` and `CEditLine` `UnicodeWnd = TRUE` | `:1741`, `:346`, `:1728` |
| `WM_CHAR` switch on `(TCHAR)wParam` | `:386-395` |
| programmatic `SendMessage(HWindow, WM_CHAR, '\r', 0)` | `:950` |
| selection offsets in UTF-8 bytes vs control characters | `EM_SETSEL` `:600`, `:792`, `:1222`, `:2094`; `EM_GETSEL` `:2083`; handler `case EM_SETSEL` `:635` |
| drop position | `EM_CHARFROMPOS` `:1161`, `EM_POSFROMCHAR` `:1169` |
| text measuring through A `GetWindowText` | `:1407` |
| Ctrl+Backspace handler (already W/A aware) | `:188-270` |
| word-break callback (already the Unicode one under comctl32 6) | `:296-300` |
| `CInnerText` (the path prefix static, A `STATIC`, A `GetTextExtentPoint32`) | `:1711`, `:1778` |

### (c) Plug-in dialogs

Plug-ins compile their **own copy** of the dialog library,
`src/plugins/shared/winliblt.{h,cpp}` (source-included in each `.vcxproj`, e.g.
`7zip.vcxproj:130`), not the core's `winlib`. Users among the 20 enabled plug-ins:
7zip, checksum, codeview, dbviewer, diskmap, filecomp, folders, ftp, mdview,
peviewer, pictview, portables, regedt, renamer, sftp, undelete, uniso. zip, uncab,
tar and sftp's dialogs call `DialogBoxParam` (A) directly
(`zip/dialogs*.cpp`, `sftp/dialogs.cpp:142-1464`). Core GUI objects reach plug-ins
only as *attached controls* through `CSalamanderGUIAbstract`
(`spl_gui.h:1973-2182`: `AttachProgressBar`, `AttachStaticText`, `AttachHyperLink`,
`AttachButton`, `AttachColorArrowButton`, `AttachToolbarHeader`) — no dialog class
crosses the ABI.

Text-entry plug-in dialogs that matter: 7zip password prompt
(`7zip/dialogs.cpp:642-651`, `IDD_ENTERPASSWORD`/`IDC_PASSWORD`, `ti.EditLine`),
7zip new-archive password (`:537-538`), zip password (`zip/dialogs.cpp:~1091`),
sftp connect/rename/symlink/password, ftp connect and the many ftp dialogs,
renamer masks, filecomp paths.

### (d) The rest — labels only

Message boxes (`CMessageBox` `msgbox.cpp:54,89`: title `:472`, body `:475`, `:698`,
buttons `:925,960` — display-only `?`), error/confirmation dialogs
(`dialogs.cpp:1542-1763`, `dialogs6.cpp:1982-2373`), progress dialogs, About,
Plugins Manager, task list, shares, drive info labels, the network-password dialog
(`dialogs3.cpp:1823` — dead code on Windows 7+, 068 V1). Master-password dialogs
(`pwdmngr.cpp:189,302,349`) read with the **A** `GetDlgItemText`
(`:203-378`) and derive a key from those bytes — see §5.6.

---

## 3. Technical approaches

### (i) Create the dialog with the W entry point, keep the procedure — **what feature 015 did**

Mechanism: pass `TRUE /*unicodeWnd*/`; `CDialog::Execute`/`Create` already switch
(`winlib.cpp:619,633`). Every control of the template becomes a Unicode control
[probe]; the existing `Sal*U8`/`EditLine` helpers stop being lossy without a line
changed at the call sites. A calls made by the dialog code (`SendMessage(…, WM_SETTEXT,
ansi)`, `SetDlgItemText`, `CB_ADDSTRING` with `LoadStr` text) are converted by the
system [probe T2] — correct **only if the bytes are ACP**; a call that passes UTF-8
through an A sink is mojibake before and after (that is F-P2-12, e.g. `dialogsp.cpp`).

What breaks, concretely:

1. **Every A subclass on a text control flips it back** [probe T7] — `CWindow`
   objects attached with the default `unicodeWnd = FALSE`: `CComboboxEdit`
   (`execute.cpp:18`; attached at `finddlg1.cpp:2988,3103`, `viewer.cpp:397`,
   `dialogs.cpp:1986`), `CKeyForwarderWindow` (`msgbox.cpp:17-21`), `CEditLBEdit`,
   and anything a plug-in attaches through winliblt (`winliblt.cpp:226`). Attaching
   A to a *static or button* (`CStaticText`, `CHyperLink`, `CButton` in `gui.cpp`)
   only makes that label ANSI again — harmless for text entry, and it is what the
   two W dialogs already live with.
2. **Common-control notifications change code.** A Unicode parent answers
   `WM_NOTIFYFORMAT` with `NFR_UNICODE` by default, so list/tree views start
   sending `…W` notifications. Handlers written against the A codes go silent:
   `LVN_BEGINLABELEDIT`/`LVN_ENDLABELEDIT` in Hot Paths (`dialogs4.cpp:3195,3205`)
   and Views (`:1494,1512`), `TVN_SELCHANGED` (`dialogs5.cpp:1778`), the holder's
   `TVN_SELCHANGING/SELCHANGED/ITEMEXPANDED` (`sheets.cpp:841,859,880`). Find and
   the packer auto-config dialog already handle both (`finddlg1.cpp:3983-4005`,
   `packac.cpp:186-196`). [code; the default answer of a W dialog not measured]
3. **The pump** for anything not run by `DialogBox…W` (§1.4): Find thread,
   Configuration holder, and the main loop's `IsDialogMessage`.
4. **`EM_LIMITTEXT` in bytes vs characters** (F-P3-04, `winlib.cpp:1057`): once the
   control can hold non-ACP text, UTF-8 needs up to 3 bytes per unit; when it does
   not fit, `EditLine`/`SalGetWindowTextU8` fall back to an A read
   (`:1091`, `:1131`) and hand **ACP bytes with `?`** to a UTF-8 buffer. Today this
   needs ~130 accented characters; with CJK input 87 characters reach it. The two
   W dialogs have this today (`CB_LIMITTEXT PathBufSize - 1`, `dialogs3.cpp:434,635`).
5. Code that reads the field with an A call keeps getting the ACP projection:
   `BrowseCommand`/`BrowseDirCommand` (`execute.cpp:1711,2136`), `dialogsp.cpp`,
   `DoHexValidation`.

Cost: per dialog, a constructor argument plus an audit of items 1, 2, 5.

### (ii) Unicode edit controls inside ANSI dialogs

Subclassing an existing edit to W does **not** work [probe T8]. Re-creating the
control with `CreateWindowExW` does [probe T6, T9]: full round trip, intact typing
under USER32's modal loop even though the dialog is A. But: the replacement must
copy position, style, font, id, z-order/tab order and the dark-theme pass; a
**combo box** has to be replaced whole (its inner edit follows the combo), which
loses the template's strings/limits and every subclass already attached; and under
a non-wide pump it is as lossy as (i). It is the right tool only where the dialog
cannot be made W — which is the plug-in case if winliblt were not touched, and the
command line and quick rename (which are this approach outside a dialog). For
template dialogs it is more code and more risk than (i) for the same result.

### (iii) Everything Unicode (`UNICODE`/`_UNICODE` build, or `unicodeWnd = TRUE` by default)

Flipping the default in `CCommonDialog` touches all 89 at once: every item of (i)
across every dialog, including ones with A-coded list-view handlers and the message
box hazard. A `_UNICODE` build is a different project altogether (every `char*`
API, the plug-in ABI). Not a first step; the per-dialog flag exists precisely so
this can be done in groups.

**Recommendation: (i), per group, with the shared prerequisites done first.**

---

## 4. History combos [code]

- Arrays are `char*[]` holding **UTF-8**. `LoadHistory` (`salamdr2.cpp:2618-2662`)
  reads through `GetValue` (the UTF-8 registry facade) and **drops** an entry that
  is not valid UTF-8 (`:2648-2652`); `SaveHistory` (`:2666-2692`) writes with
  `SetValue`.
- Into the combo: `LoadComboFromStdHistoryValues` (`salamdr6.cpp:383-391`) →
  `SalComboAddStringU8` → `SendMessageW(CB_ADDSTRING)` — wide already, lossy only
  because the combo is ANSI [probe T3: `0061 0159 003F 003F` in an A dialog, intact
  in a W dialog, including after `CB_SETCURSEL`].
- Out of the combo: `SalGetWindowTextU8` + `AddValueToStdHistoryValues`
  (`salamdr6.cpp:346-381`; comparison `StrICmp` = ACP byte tables, cluster B-2) or
  `HistoryComboBox` (`viewer.cpp:50-150`, `strcmp`).
- Feature 085's password stripping runs on the stored copies
  (`dialogs3.cpp:445-447`, `:1218`) and is encoding-neutral.
- Consequence: **histories need no data change.** A stored `?` entry from before
  the fix stays a `?` entry (it is valid UTF-8); nothing can repair it.
- Plug-ins get the same two functions through `CSalamanderGeneral`
  (`zip.cpp:4174-4213`) on their own (ANSI) combos.

---

## 5. Risks and traps

1. **A subclass on a text control undoes the fix silently** (§3 (i) 1). The
   product hit this in feature 015 (`salamdr3.cpp:3966-3969`). Fix once, in
   `CWindow`: let `AttachToWindow` take the flavour from `IsWindowUnicode(hWnd)`
   instead of the constructor default — but `CWindowProcInt` asserts
   `wnd->UnicodeWnd == unicode` with `TRACE_C` (`winlib.cpp:391,408,465`), so the
   member must be set consistently, and `WindowProc` overrides that look at
   `WM_CHAR`/`WM_GETTEXT` then see UTF-16 (`CComboboxEdit::WindowProc`
   `execute.cpp:26`, `CKeyForwarder` only compares/forwards).
2. **Message box**: `CKeyForwarderWindow` (`msgbox.cpp:17-21`) is attached to the
   buttons; in a W message box it would make them ANSI again (068 V2 called it a
   crash hazard; I see a label regression, crash **[not verified]**). Message boxes
   are display-only and are also what plug-ins call most — keep them out of the
   first feature.
3. **Notification format** (§3 (i) 2) — per dialog audit; or answer
   `WM_NOTIFYFORMAT` with `NFR_ANSI` centrally for W dialogs that have not been
   audited (`SetWindowLongPtr(DWLP_MSGRESULT)`, the pattern at `finddlg1.cpp:4003-4005`).
4. **Pumps** (§1.4). Find: `find.cpp:2072,2086,2089` plus the idle `PeekMessage`
   below it and the secondary pumps `finddlg1.cpp:2181`, `:4604`. Configuration:
   `sheets.cpp:1167-1179` (`src/common`, shared with translator/tserver — neutral
   for ANSI windows per the probe). Main loop: `salamdr1.cpp:4682`.
   `TranslateAccelerator`, `IsMenuBarMessage` and `ManageHiddenShortcuts` in the
   Find loop then see UTF-16 `WM_CHAR`/`WM_SYSCHAR`; the main loop has run that way
   since feature 004, the Find menu bar has not. **[not verified]**
5. **Plug-in ABI / FR-009 freeze**: untouched by core dialog conversion — no dialog
   class is exported, attached GUI objects are created by core code. Two things do
   reach plug-ins: `InstallWordBreakProc` (`zip.cpp:3882`, already W/A aware) and
   `LoadComboFromStdHistoryValues`/`AddValueToStdHistoryValues` (encoding-neutral).
   Changing **winliblt** is a source change compiled into each plug-in, not an
   interface change; it needs no version bump but every enabled plug-in rebuilds.
6. **Passwords must not change bytes.** Master-password dialogs read ACP bytes
   (`pwdmngr.cpp:203-378`) and derive the key from them; switching them to UTF-8
   would lock out every user with an accented master password. Out of scope.
   **Found on the way, in the 7zip prompt** [code, not executed]: winliblt's
   `EditLine` returns **UTF-8** (`winliblt.cpp:1136-1140`, unconditional), but the
   three consumers treat it as ACP — `open.cpp:77-80`, `extract.cpp:673-674`,
   `update.cpp:310-311` (`GetUnicodeString(pwd)` = `MultiByteToUnicodeString(…, CP_ACP)`,
   `StringConvert.h:9,24`). A password with an accented character that *is* in the
   code page (`ř`) would then reach the engine as mojibake. The comments say "ACP,
   not UTF-8"; the code they describe says otherwise. Worth a five-minute test
   with an archive encrypted under `heslo-ř`.
7. **Dark theme (036/049)**: subclasses with comctl32 `SetWindowSubclass`
   (`themes.cpp:991-1111`, `:1396`), which keeps a Unicode control Unicode
   [mini-probe], and paints with `GetWindowTextW` (`themes.cpp:303,412,610`). The
   two W dialogs already run under it. `CEditListBox` themes its inline edit after
   creation (`edtlbwnd.cpp:487`). No ANSI assumption found.
8. **Auto-complete / IME**: no `SHAutoComplete`, `IAutoComplete`, `WM_IME_*` or
   `WM_UNICHAR` handling anywhere in core (grep). IME composition into a Unicode
   edit is handled by the control; `WM_IME_CHAR` through an A pump would be lossy
   like `WM_CHAR`. **[not verified with a real IME]**
9. **Word-break callback**: already picks `EditWordBreakProcUNICODE` under
   comctl32 ≥ 6 (`editwnd.cpp:296-300`); no change. It is the command line's
   `(TCHAR)wParam` switch and offsets that move (§2 b).
10. **Buffer limits** (§3 (i) 4): fix the fallback before widening — on overflow
    truncate at a UTF-8 boundary (`SalU8TrimIncompleteTail` exists since 069)
    instead of the A read, in `EditLine` `winlib.cpp:1091` and `SalGetWindowTextU8`
    `:1131`.
11. **Lone surrogates**: a W control holds them and `SalWToU8` is WTF-8, so the
    round trip is lossless; typing a pair works [probe: `D83D DCC1` intact].
12. **Translations**: no string changes — only window flavour.
13. **Modeless + main thread** (§0.2): if any converted dialog is modeless and
    served by the main loop, `IsDialogMessageA` there corrupts it.

---

## 6. Proposed first B-1 feature

**Goal the user can see**: every place where a path, name or mask is typed or
prefilled survives outside the code page — and the 7-Zip password prompt accepts
any character (087 FR-010).

| Stage (one commit each) | Content | Sites |
|---|---|---|
| **S0 — shared prerequisites, no dialog converted** | (a) `CWindow::AttachToWindow` follows `IsWindowUnicode` (or an explicit parameter at the 4 `CComboboxEdit` attach sites + `CEditLBEdit`); (b) overflow fallback in `EditLine`/`SalGetWindowTextU8` truncates UTF-8 instead of the A read; (c) `IsDialogMessageW` in the main loop (`salamdr1.cpp:4682`) | ~8 |
| **S1 — modal path dialogs** | `TRUE /*unicodeWnd*/` for `CChangeDirDlg`, `CPackDialog`, `CUnpackDialog`, `CSelectDialog`, `CFilterDialog`, `CConvertFilesDlg`, `CFileListDialog`, `CCompareArgsDlg`, `CChangeIconDialog`, `CDriveInfo` (label); wide read in `BrowseCommand`/`BrowseDirCommand` + `SafeGetOpenFileNameW`; A `WM_GETTEXT` at `dialogs3.cpp:78` | 10 ctors + ~6 A reads |
| **S2 — Find** | `CFindDialog` W; pump `find.cpp:2072-2089` and the two secondary pumps → W; `CComboboxEdit` flavour; check the menu-bar/hidden-shortcut handlers with UTF-16 `WM_SYSCHAR`. Advanced/settings/ignore sub-dialogs with it | 4 ctors + 3 pumps |
| **S3 — Configuration pages that store paths** | `unicodeWnd` parameter on `CPropSheetPage`/`CCommonPropSheetPage`; holder pump `sheets.cpp:1167-1179` → W; pages: Hot Paths, User Menu, Viewers, Editors, Command Shell, Packers, Unpackers, Archiver Locations; `CEditListBox` inline edit via `CreateExW`; **W notification codes** for the label edits (`dialogs4.cpp:3195-3217`, `:1494-1524`) or `NFR_ANSI`; `dialogsp.cpp`'s 12 A `WM_GETTEXT`/`WM_SETTEXT` → `Sal*U8` (this also closes F-P2-12) | 8 pages + ~30 call sites |
| **S4 — the command line** | §2 (b) list | 1 control, ~12 sites |
| **S5 — 7-Zip password prompt** | winliblt: optional `unicodeWnd` on `CDialog` (`Execute`/`Create` W branch, as in core) — or, minimal, the prompt calls `DialogBoxParamW` itself; fix the UTF-8-vs-ACP conversion at the three consumers (§5.6) | 2 dialogs + 3 sites |

Roughly **25 dialog/page constructions, 4 pumps, 50–60 call sites**.

Deferred, with reasons:

- **Message boxes** — display-only, the `CKeyForwarderWindow` hazard, highest call
  volume in the product; own stage after the rest has proven the pattern.
- **Master-password dialogs** — bytes feed a key (§5.6).
- **The remaining ~55 label-only dialogs and pages** — no input to lose; convert
  when the default can be flipped.
- **All other plug-in dialogs** (ftp, sftp, zip, renamer, filecomp …) — each
  plug-in has its own A reads and its own consistent-ANSI chains (068 showed a
  naive sweep regresses FTP); B-3/B-5 territory.
- **`AddValueToStdHistoryValues`' `StrICmp`** — cluster B-2.
- **The classic `PropertySheet()` path** — no caller.

---

## 7. Testing without a person

The repository already has the driver: `specs/080-restart-manager-upgrade/probe/tc_drive.ps1`
(starts one instance, posts `WM_COMMAND` to its main window, finds its dialogs by
pid/title, `WM_SETTEXT`, `BM_CLICK`; no `SendInput`, no foreground games), and
`config_equivalence.ps1` shows the registry backup/restore discipline. Feature 078
used `drive.ps1` with the UI forced to English.

Probe design (`b1_probe.ps1`, Debug build, English UI, registry exported first and
restored at the end):

1. Fixture tree in `%TEMP%`: `D:\…\b1\Ж-проект\`, `…\日本\`, `…\📁\` (surrogate
   pair), each with one file. Start with `-l <fixture>`.
2. Per dialog under test: post the command (`CM_ACTIVE_CHANGEDIR` 862,
   `CM_FINDFILE` 741, `CM_PACK` 850, `CM_UNPACK` 851, `CM_CREATEDIR` 730 as the
   already-W control), wait for the dialog, `GetDlgItem(dlg, id)` (`IDE_PATH` 210,
   `IDC_FIND_NAMED` 2505, `IDC_FIND_LOOKIN` 2501, `IDC_FIND_CONTAINING` 2504,
   `IDE_MASK` 521; for a combo take its child edit).
3. **Assertions, three independent channels**:
   - `IsWindowUnicode(control)` is TRUE — catches the A-subclass flip directly;
   - **prefill**: `SendMessageW(WM_GETTEXT)` equals the fixture path (WM_GETTEXT is
     marshalled across processes) — catches the storage loss;
   - **typing**: clear, `PostMessageW(control, WM_CHAR, unit, 1)` per UTF-16 unit,
     then `WM_GETTEXT` — goes through the dialog's real pump, so it catches the
     Find/Configuration pump defect that a `WM_SETTEXT` test cannot see. This is
     the method my probe used; it distinguished all six pump shapes.
     (`EM_REPLACESEL` with a string from another process: **[not verified]** that
     USER32 marshals it — prefer `WM_CHAR` + `WM_SETTEXT`.)
4. **Outcome**: `BM_CLICK` on OK, then check the effect, not the control:
   Change Directory → the panel's path (window title / path static) is the fixture
   folder; Create Directory / Pack → the directory or archive exists on disk under
   the exact name (`[IO.Directory]::Exists`); Find → result list count ≥ 1.
5. **Persistence**: close the program normally (configuration is written on exit),
   then read `HKCU\Software\Tandem Commander\0.1\…\ChangeDir History\1`,
   `Look In History\1`, `Named History\1` with `Get-ItemProperty` and compare with
   the typed string (no `?`, code units equal). Hot Paths / User Menu: the stored
   path value.
6. **Negative control** (the house rule since 068: prove the check fires): run the
   same script against the preserved pre-change build — it must fail on exactly
   the converted dialogs and pass on Create Directory.
7. Limits to state in the record: posted `WM_CHAR` is not a keyboard or an IME;
   a real-keystroke and an IME pass stay owed to a person. The Win32 semantics
   themselves are already pinned by `scratchpad\b1probe` (copy it into the
   feature's `probe/` — it is the cheapest regression test for §1.3/§1.4).
