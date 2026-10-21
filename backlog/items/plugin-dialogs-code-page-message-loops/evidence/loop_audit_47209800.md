# Message loops of the shipped plug-ins - audit at 47209800 (2026-10-21)

Run of `/tandem-backlog-implement` on this item. Shipped = `plugins.cfg` on (20 plug-ins).
Plug-ins are built without `UNICODE`, so `GetMessage` / `PeekMessage` / `IsDialogMessage` /
`DispatchMessage` are the code-page (A) forms. A code-page loop loses a typed character only
when it retrieves a `WM_CHAR` meant for a **text field** (093's rule). Modal dialogs
(`DialogBoxParam*`, `CDialog::Execute`, common dialogs, property sheets) run the system's own
loop and were measured lossless by 093 / 104; they are not listed.

Search: `grep -rnE "\b(GetMessage|PeekMessage|IsDialogMessage|DispatchMessage)[AW]?\s*\("`
over `src/plugins/<shipped>` (`.cpp`, `.h`), plus `CreateDialog*` / `->Create()` for the
modeless dialogs those loops serve, plus `EDITTEXT` / `COMBOBOX` in the language resources.
No shipped plug-in creates an edit or combo box outside a dialog resource.

## Already wide

| Site | Feature |
|---|---|
| `filecomp/filecomp.cpp` (dialog + comparator loop), `filecomp/mainwnd.cpp` (two drains) | 102 |
| `renamer/rendlg.cpp` (dialog loop, two drains), `renamer/dialogs.cpp` (progress drain) | 104 |
| `regedt/finddlg2.cpp` (Find thread loop); `regedt/dialogs.cpp` creates with `CreateDialogParamW` | - |

## Code page, harmless (reason)

| Site | What it pumps | Why no typed text is lost |
|---|---|---|
| `7zip/7zthreads.cpp` `LaunchAndDo7ZipTask` | main window and its children only (`hWnd` filter) | every caller (`Decompress`, `TestArchive`, `DoUpdate` routes) opens the core progress dialog first, which disables the main window (`CSalamanderForOperations::OpenProgressDialog`); the progress dialog is an owned pop-up, not pumped here, and has no text field |
| `checksum/dialogs.cpp` `CCalculateDialog::RefreshUI` | the checksum dialog's own thread (`CCalculateDialogThread`) while it reads folders | that thread's windows have no text field (no `EDITTEXT` / `COMBOBOX` in the checksum resources) |
| `checksum/dialogs.cpp` `WM_DESTROY` wait | `PM_NOREMOVE \| PM_QS_SENDMESSAGE` | sent messages only, nothing removed |
| `codeview/viewer.cpp`, `mdview/viewer.cpp` viewer thread | the viewer window (WebView2) | web content takes keys in the browser process; the only native fields (Find, Go to, Configuration) are modal `DialogBoxParamW` / `DialogBoxW` |
| `dbviewer/dbviewer.cpp` viewer thread | the viewer window | no modeless dialog; Find / Go to / CSV / Columns / Configuration are modal |
| `diskmap/DiskMapPlugin.cpp` viewer thread | the Disk Map window | no text field at all |
| `pictview/pictview.cpp` (two viewer loops), `histwnd.cpp` (histogram thread), `render1.cpp` `ProgressProcedure`, `wiawrap.cpp` (WIA start) | viewer / histogram windows | no modeless dialog with a field; Rename, Copy to, Zoom, Page, Capture, Configuration are modal |
| `pictview/saveas.cpp` | `WM_KEYUP` of the viewer only | no `WM_CHAR` is retrieved |
| `ftp/ctrlcon1.cpp` `WaitForEventOrESC`, `ftp/operats1.cpp` `WaitForFinishOrESC` | the calling thread while a wait window shows | each of the 13 callers disables `parent` first (`StartControlConnection`, `CloseControlConnection`, `SendFTPCommand`, `OpenForListeningAndWaitForRes`, `StopWorkers`; `WaitForEndOfKeepAlive` is reached with the parent disabled or in `kamNone`, where it does not wait); the wait window has no text field |
| `ftp/operats2.cpp` Operation dialog thread | `IDD_OPERATIONDLG` | statics, buttons and two owner-data list views whose type-ahead is switched off (`LVN_ODFINDITEM` answers -1, `dialogs6.cpp`); Solve Error dialogs are modal |
| `ftp/ctrlcon2.cpp` Logs dialog thread | `IDD_LOGSDLG` | a drop-down list (no typing) and a read-only log edit |
| `ftp/sockets.cpp` sockets thread | a hidden window | no UI |
| `ftp/dialogs2.cpp` (`WM_APP_UPDATELISTOFLOGS`, `WM_APP_UPDATELOG`, `WM_TIMER` filters) | private messages | no keyboard message |
| `undelete/dialogs.cpp` `CSnapshotProgressDlg` / `CCopyProgressDlg::GetWantCancel` | the main thread | the main window is disabled before each progress dialog (`fs2.cpp`, `restore.cpp`); the progress dialogs have no text field |
| key-discard loops: `filecomp/mainwnd.cpp`, `viewwnd.cpp`, `viewwnd3.cpp`; `ftp/ctrlcon1.cpp`, `fs1.cpp`, `operats1.cpp`; `regedt/utils.cpp`; `renamer/rendlg.cpp` | `WM_KEYFIRST..WM_KEYLAST`, removed and dropped | the keys are discarded on purpose (ESC test); nothing is dispatched |

## Code page, unreachable

| Site | Why |
|---|---|
| `zip/dialogs2.cpp` `CAdvancedSEDialog::Proceed` (modeless `IDD_ADVANCEDSE`, text fields) | no `sfx\*.sfx` package is built or shipped, so the self-extractor check box is disabled (104 `research.md`; decided in the rejected item `zip-comment-and-sfx-stay-code-page`). The fields are also stored as code page (`WM_GETTEXT` A, the stub is a code-page program): a wide loop would *show* a letter that is then stored as `?` or a best-fit look-alike - keep the code-page loop if the SFX is ever shipped, or widen loop and storage together |
| `zip/add_del.cpp` loop | commented out |
| `zip/selfextr/selfextr.cpp` | separate SFX program, not shipped; removes one message without dispatch while waiting for a process |
| `7zip/7za/CPP/Windows/ProcessMessages.cpp` | not in any project |
| `portables/wtl/atlapp.h` `CMessageLoop` | not used by the plug-in |

## Result

No reachable loop of a shipped plug-in delivers typed characters to a text field, so there is
nothing to type into for the item's measurement: the defect class is not present at 47209800.
