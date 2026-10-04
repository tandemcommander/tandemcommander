# Research for feature 104: names outside the code page in the other plug-ins

Read-only research and measurements, 2026-10-04, branch `104-plugin-unicode-names` (HEAD
1fc230c9, feature 103). Machine ACP = 1250, OEM 852. Backlog: `specs/NEXT-WORK.md` item 5,
sub-item 5 ("Same class as 102 in other plug-ins"). Pre-change build:
`build\tandemcommander\Debug_x64_pre104`. Scratch measurement program (not in the repository):
`%TEMP%\...\scratchpad\m104\m104.cpp`.

Plug-ins are compiled **without** `UNICODE`/`_UNICODE`, so every unsuffixed call is the code-page
("A") one. Names are UTF-8 (WTF-8) inside the program since interface 104.

## 0. Headline

1. **The backlog's counts were partly wrong, partly incomplete.**
   - *"code-page subclasses on text controls in ftp (3), zip (4), 7zip (1)"*: of these eight,
     **none is on a text field that carries a name**. ftp's three lines are `CSetWaitCursorWindow`,
     which subclasses the *disabled parent window* (main window or a plug-in dialog - all code-page
     windows already) during an operation; 7zip's one subclasses the core's progress dialog (a
     code-page `CCommonDialog`); zip's four are a path **label** (`TextControlProc`, static),
     an icon, the volume-size combo (numbers) and the archive comment (content, not a name).
     The zip label *does* lose characters (display) - fixed.
   - **Not in the backlog and the most serious**: the **Renamer** attaches winliblt's
     code-page `CWindow::AttachToWindow` to the edits of *Mask*, *New name*, *Search*,
     *Replace* and to the *manual list*, runs a code-page message loop, and reads the mask and
     the manual list with code-page calls. Measured: a new name outside the code page became
     `?` or a **best-fit look-alike** - `voil<U+00E0>.txt` was renamed to `voila.txt`; a mask
     `<U+0416>*.txt` became `?*.txt`, a wildcard that selects **other files** for renaming.
   - *"`DragQueryFile` in dbviewer and pictview"*: both A calls are only the **count** query
     (`0xFFFFFFFF`); the names are read with `DragQueryFileW`. Not a defect.
   - *"`CreateFileA` fallbacks in checksum, peviewer, renamer"*: the fallback runs only for input
     that is not UTF-8 (WTF-8). peviewer and renamer never get such input; checksum's Verify
     never reaches its fallback (the existence check before it has none). Not a defect as such;
     see 4 (checksum) for what is lost there.
   - *"`salpvenv.exe` (probably dormant)"*: confirmed dormant - not in `salamand.sln`, not built,
     not shipped (Debug and Release trees, `setup/tandemcommander.iss`), and the code that started
     it is not compiled since feature 006 (`LoadPictViewDll` always uses WIC;
     `PICTVIEW_DLL_IN_SEPARATE_PROCESS` retired). Recorded, not rewritten.
2. **The general shape is the plug-in-facing code-page services.** `SafeGetOpenFileName`,
   `SafeGetSaveFileName` and `GetTargetDirectory` of `CSalamanderGeneral` are code-page calls
   with a frozen contract (interface FR-009; `zip.cpp:3404` converts the picked folder back with
   `SalU8ToACP`). The picked name comes back through `WideCharToMultiByte(CP_ACP, 0)` - **best
   fit**. Every plug-in that then opens, saves to or copies into that name can use **another
   existing file or folder**. Fourteen such call sites in six enabled plug-ins (Database
   Viewer 1, FTP 5, ZIP 2, PictView 2, Renamer 1, Undelete 3 - section 2), plus Undelete's
   own code-page `GetOpenFileName`.
3. **winliblt's `CTransferInfo::EditLine`** (compiled into 16 of the 20 enabled plug-ins) read a
   field through the code page (`WM_GETTEXT` A = best fit) whenever its UTF-8 form did not fit
   the caller's buffer (`EM_LIMITTEXT` counts units, the buffer bytes: about 87 CJK characters
   overflow a `MAX_PATH` buffer) or held a lone surrogate (strict conversion). The 093 record
   left it ("still falls back to a code-page read").
4. **Found on the way, outside the class, serious**: PictView's *Save As* (Ctrl+S) onto an
   existing file asks "replace?", **deletes the file on Yes, and then fails** - the WIC engine
   cannot write images (feature 006). Measured on both builds (probe FINDING row). Recorded in
   NEXT-WORK, not fixed here.

## 1. Primitive facts (scratch program `m104.cpp`, comctl32 6 manifest)

```
ACP 1250
text: voil<U+00E0> <U+FF21><U+FF22> <U+0416> <U+65E5> <U+1F4C1> <U+0159>
EDIT / STATIC / COMBOBOX's edit, created with CreateWindowExA: unicode=1
 W read (no subclass): exact
 A read (no subclass): 76 6F 69 6C 61 20 41 42 20 3F 20 3F 20 3F 3F 20 F8   (voila AB ? ? ?? r-caron)
 after SetWindowLongPtrA subclass: unicode=0
 SetWindowTextW + GetWindowTextW through it: "voila AB ? ? ?? <U+0159>"  (best fit STORED)
 after restoring the procedure: unicode=1
WideCharToMultiByte(CP_ACP, 0): best fit as above; WC_NO_BEST_FIT_CHARS: '?' for a, A, B
```

So a code-page subclass on a text control does not only produce `?`: it stores **best-fit
look-alikes**, also for text set with the W calls - the 102 finding, now on statics too.

## 2. Inventory, enabled plug-ins (20 in `plugins.cfg`)

Classes: **W** wrong file/folder (a different existing one is used, renamed onto, overwritten,
deleted or copied into), **G** a file is created/renamed with a garbled name, **L** fails with
an error (nothing wrong happens), **D** display only, **H** harmless. "Fixed" = changed by 104.

### Renamer (`src/plugins/renamer`) - fixed

| Site | What | Class (before) |
|---|---|---|
| `rendlg.cpp:742-746` `AttachToWindow` on the edits of Mask, New name, Search, Replace and on the manual list (`CComboboxEdit`, `CNotifyEdit`) | code-page subclass | W (best fit: `voil<U+00E0>` -> `voila`, measured), L (`?` = invalid name) |
| `rendlg.cpp:2339` dialog thread loop, `:1232/:1367` drain loops, `dialogs.cpp:869` progress drain | `PeekMessageA`/`IsDialogMessageA`/`DispatchMessageA` | typed text -> `?`/best fit (093 cause 1) |
| `rendlg.cpp:1176` mask for re-reading the files | `GetDlgItemText` A | **W**: `?` is a wildcard - other files selected (measured: `<U+0416>*.txt` listed 2 files, pre-104 probe) |
| `dialogs.cpp:278-291` history: `CB_ADDSTRING` A, `WM_SETTEXT` A of UTF-8 | mojibake list; after OK the field held the mojibake (`CB_SETCURSEL`) - next run renamed to it | G |
| `rendlg.cpp:1484` manual list filled with `WM_SETTEXT` A of UTF-8 | mojibake shown | D, G when edited |
| `rendlg2.cpp:530`, `preview.cpp:203` manual line read with `EM_GETLINE` A | code-page bytes / best fit | W / G / L |
| `rendlg4.cpp` external editor and filter command: `GetWindowText` A, `EM_REPLACESEL` A; the command line converted with `CP_ACP` | the file and the pipe carried the names' UTF-8 bytes by accident (the edit held them as code-page characters); a non-ASCII command was garbled | G (command) |
| `dialogs.cpp:1031` editor command Browse: `GetDlgItemText` A + `SafeGetOpenFileName` | best fit | W (another program started; exotic) |
| `editor.cpp` `$(WinDir)`, `$(SysDir)`, `$(SalDir)` (+ DOS and "2" forms): `GetWindowsDirectory`/`GetSystemDirectory`/`GetModuleFileName` A into UTF-8 text | an installation folder outside ASCII garbled the whole command line (`TextToWAlloc` falls back to CP_ACP for the whole line) | L |

### PictView - fixed (Copy To, Save As dialog, exif.dll); recorded (Save As delete, thumbnails, wallpaper)

| Site | Class |
|---|---|
| `dialogs.cpp:1933` Copy To Browse: `GetDlgItemText` A + `GetTargetDirectory` (code page) + `SetDlgItemText` A, then `SHFileOperationW` | **W**: copied into a look-alike existing folder (measured, pre-104 probe) |
| `saveas.cpp:727` Save As via `SafeGetSaveFileName` (A); the name then used as UTF-8 for the existence check and `DeleteFileW` | **W, destructive**: the "replace?" question names an existing look-alike and Yes deletes it |
| `saveas.cpp` *any* Save As onto an existing file | deletes it, then "Unable to save the image" - **recorded, not fixed** (not an encoding defect) |
| `pictview.cpp:1549` `GetModuleFileName` A + `LoadLibrary` A of `exif.dll` | L (EXIF unavailable for an installation folder outside the code page), in theory W (a look-alike folder's DLL) |
| `thumbs.cpp:270` *Regenerate thumbnail*: code-page name to the WIC engine; the command cannot work at all (WIC cannot encode) | recorded |
| `render2.cpp:380-417` wallpaper registry value via `RegQueryValueEx`/`RegSetValueEx` A | recorded (the commands that would set it fail earlier: no encoder) |
| `render1.cpp:2090` `DragQueryFile` | H (count only; names W) |
| `print.cpp`, `dialogs.cpp:771/787/888` | H (numbers, printer names) |

### Database Viewer - fixed

| `renmain.cpp:234` *Open* (Ctrl+O): `SafeGetOpenFileName` (A) -> `OpenFile` as UTF-8 | **W** (read-only): `voila.csv` opened for `voil<U+00E0>.csv` (measured, pre-104 probe) |
| `renmain.cpp:1559` `DragQueryFile` | H (count only) |
| `dialogs.cpp:33-52, 858` Find history combo with an A fallback | H (search text, not a name) - recorded |

### FTP - fixed (file dialogs, two text reads); recorded (password field, FTPS DLL path)

| Site | Class |
|---|---|
| `ctrlcon2.cpp:1998` Save log, `dialogs2.cpp:311` Save welcome/listing text, `dialogs3.cpp:183` export server type: `SafeGetSaveFileName` (A), the result passed **unconverted** to `FTPSetFileAttributesU8`/`FTPCreateFileU8` (UTF-8) | **W, destructive**: clears read-only and overwrites a look-alike existing file (the dialog's own overwrite prompt was for the real name); **L for every accented name** (also inside the code page, e.g. a user profile `C:\Users\Ji<U+0159><U+00ED>` as the start folder) |
| `dialogs3.cpp:258` import server type, `dialogs4.cpp:917` parser test "load text": `SafeGetOpenFileName` (A) | W (another file read) / L |
| `ftp4.cpp:15` `GetMyDocumentsPath`: `SHGetPathFromIDList` A | start folder only (H), feeds the above |
| `dialogs8.cpp:9` `HistoryComboBox` (Connect: host, initial path; Send FTP command), `dialogs4.cpp:1323` Copy/Move target path: W read, **A re-read when the UTF-8 form does not fit** | W (edge: long non-ASCII text; a command `DELE voila.txt`) |
| `dialogs2.cpp:800` `CSetWaitCursorWindow` (one of the backlog's "3") | H - the parent windows are code-page windows, no text control |
| `dialogs1.cpp:1312`, `dialogs8.cpp:1955` `CPasswordEditLine` (`AttachToWindow`) on the password fields, `dialogs1.cpp:1363/1992` *Show password* `GetWindowText` A | password class (094 left FTP): recorded |
| `ssl.cpp:769/166` `GetModuleFileName` A + `LoadLibrary` A of the OpenSSL DLLs | recorded: FTPS is not shipped (no `libeay32.dll` in any tree) |
| `operats2.cpp:58`, `ctrlcon2.cpp:1435`, `sockets.cpp:3129` code-page loops | H (no text fields) |

### ZIP - fixed (labels, change-disk Browse); recorded (comment, SFX)

| Site | Class |
|---|---|
| `dialogs.cpp:51-91,142` `TextControlProc` (A subclass, paints `GetWindowText` A + `DrawText` A into `char[MAX_PATH]`) on the path/name labels of the Pack options, Password, Low disk space and both Overwrite dialogs; the Password and Low-disk texts set with `WM_SETTEXT` A of UTF-8 | D (`?`, look-alikes, mojibake, cut at 259 bytes) - in a **destructive overwrite confirmation** the name may show `voila` while the target is `voil<U+00E0>` |
| `dialogs.cpp:1466, :1709` change-disk Browse (last volume / next volume): `U8ToDlgA` (best fit) + `SafeGetOpenFileName` + `DlgAToU8` | **W**: a look-alike existing archive read as the volume |
| `dialogs.cpp:158-199` `CBEditCtrlProc` (volume size combo) | H (numbers and units) |
| `dialogs3.cpp:40-183` comment edit (A subclass, `GetDlgItemText` A) | content, not a name (ZIP comments are code-page bytes) - recorded |
| SFX settings import/export (`dialogs2.cpp:1007/1187`), `prevsfx.cpp`, `dialogs2.cpp:78` loop, `selfextr`, `zip2sfx`, `sfxmake` | **unreachable**: no `sfx\*.sfx` package is shipped, so the SFX check box is disabled and *Create SFX* says "no SFX installed"; the three programs are not built by the default build / not shipped - recorded |
| `chicon.cpp:81-95` SFX icon (`WC_NO_BEST_FIT_CHARS`, refuses) | H (exact or refused) |

### CAB (uncab) - fixed

| `dialogs.cpp:153-243` next-volume dialog: the folder shown with `U8ToAcp` (best fit) and read back with `GetDlgItemText` A + `AcpToU8`; Browse `SHBrowseForFolder` A | **W** (folder): the field showed `...\voila\` for `...\voil<U+00E0>\` and OK took the next volumes from the look-alike folder (measured, pre-104 probe: extracted from the decoy's volumes). FDI's set-ID check refuses volumes of *another* cabinet set, so the extracted data were the set's own - the wrong folder was used, not wrong data |
| `dialogs.cpp:31-85` `TextControlProc` on the "continued file" label | D |

### Undelete - fixed (dialog fields, pickers); recorded (volume layer, 0xE5)

| Site | Class |
|---|---|
| `dialogs.cpp:384, 490, 540-560` Connect, *Disk image*: prefill `SetDlgItemText` A of UTF-8 (mojibake), read `GetDlgItemText` A, Browse plain `GetOpenFileName` A | W (read side: another image analysed), L |
| `dialogs.cpp:706` temp folder Browse, `fs2.cpp:1404` temp folder for View on the same volume: `GetTargetDirectory` (code page) - the second straight into `ConfigTempPath` (used as UTF-8) | W (temporary copies in a look-alike folder) / L |
| `dialogs.cpp:742-797` *Restore encrypted files* target: prefill A, Browse `GetTargetDirectory`, read `GetDlgItemText` A, then `SafeFileCreate` (UTF-8) | **W**: files restored into a look-alike existing folder |
| `library/os.cpp:84-214` volume/mount-point enumeration with A functions; `fs2.cpp:122`, `dialogs.cpp:529` `GetVolumePathName` A on UTF-8 | L / W (another volume) for mount folders with non-ASCII names - recorded |
| `fs2.cpp:203` `Replace0xE5` applied to UTF-8 names (a FAT relic): every name whose first byte is 0xE5 (CJK U+5000-U+5FFF) is listed with `$` and restored under a **garbled name** | G - recorded (NEXT-WORK, own feature) |

### Registry Editor (regedt) - fixed (Find loop, editor launch, browse fallbacks)

| `finddlg2.cpp:1187` Find dialog (a Unicode dialog) in a `GetMessageA`/`IsDialogMessageA` loop | L (typed search text outside the code page -> `?`; registry, no files) |
| `editor.cpp` external editor: `GetShortPathName` A on the UTF-8 temp folder/file, `CreateProcess` A; the `$(...)Dir` variables A | L / G (transient temp file) - only with a configured editor (default none) |
| `utils.cpp:584` file dialog helper: a UTF-8 result over `MAX_PATH` bytes degraded with `WideCharToMultiByte(CP_ACP, 0)`; `dialogs.cpp:1051/1269` fields re-read with A when the UTF-8 form does not fit | W (an export overwriting a look-alike `.reg`, after a question) - edge |

### SFTP - fixed (edge)

| `dialogs.cpp:33-58` `GetDlgItemTextU8`: A re-read when the UTF-8 form does not fit (key file `MAX_PATH`, host/user 256, initial path 1024) | W (a look-alike key file loaded) - edge |

### checksum, peviewer, codeview, mdview, diskmap, folders, portables, tar, uniso, 7zip, filecomp

- **checksum** `misc.cpp:96` fallback: unreachable (Verify checks existence with
  `SplU8ToWExtAlloc` + `FindFirstFileW` first). Names in a checksum *list file* are the file's
  bytes; an ANSI list with accented names reports them "missing" (L), a byte sequence that is
  accidentally valid UTF-8 verifies another file (read-only). List-file encoding detection is a
  separate topic - recorded. Save of a list: already W.
- **peviewer** `peviewer.cpp:291`: H (viewer names come from the core as UTF-8).
- **codeview, mdview, folders, uniso, tar, 7zip, portables**: every file call is W or on ASCII;
  their A loops have no text fields; `7zclient.cpp:1290/1864`, `7zip.cpp:1443`, `untar.cpp:701`,
  `zip/common.cpp:93-157`, `zip/repair.cpp` are inside `/* */`.
- **diskmap** (no `UNICODE`): `CCushionGraphics.h:56` `CreateFile` A - dead (no caller);
  `GUI.MainWindow.h:385` - not compiled (`#ifdef SALAMANDER`); the log window's list view is A
  (path column mojibake, D) - recorded.
- **filecomp**: after 102 nothing left (`dialogs4.cpp:259` attaches to a property-sheet frame,
  `mainwnd.cpp:1633` count-only `DragQueryFile`).
- **shared/lukas**: `utilaux.cpp` `GetOpenFileName` (A) is compiled into filecomp only and has
  no caller; `resedit.cpp` serves only the unreachable SFX; `utilbase.cpp:106` code-page
  `FormatMessage` text in a UTF-8 message (D) - recorded.

## 3. Disabled plug-ins (list only, unchanged)

`plugins.cfg` off: automation, checkver, demomenu, demoplug, demoview, mmviewer, nethood,
unchm, unmime, unole, unrar.

- code-page reads of names: unrar `dialogs.cpp:160/185` (next volume) and `:175`
  `SafeGetOpenFileName`; demoplug `fs1.cpp:132`; automation `cfgdlg.cpp:733` (script path),
  `dialogimpl.h:146`; mmviewer `mmviewer.cpp:1571/1576`, `renmain.cpp:58` file dialogs.
- `GetModuleFileName` A on paths that are opened: automation `automationplug.cpp:433`, checkver
  `internet.cpp:132`, unchm `chmfile.cpp:80`, unrar `unrar.cpp:942`.
- A subclasses: automation `cfgdlg.cpp:466` (a label edit holding a path), `guicomponent.cpp:266/312`;
  mmviewer `output.cpp:186`; unole `dialogs.cpp:67`, unrar `dialogs.cpp:60` (statics); demoplug
  `dialogs.cpp:206/428`, demoview `dialogs.cpp:138`.
- A loops: automation (4), checkver (2), demoplug (4), demoview, mmviewer, nethood.
- `DragQueryFile` A: demoplug `viewer.cpp:864`, demoview `viewer.cpp:645` - count only.

None of them is changed: the shared changes (winliblt, `splunicode.h`) are compiled into the
disabled plug-ins that use them too, but those are not built by the default build.

## 4. Decisions (see spec.md Clarifications)

- One shared, header-only helper for the two pickers (`src/plugins/shared/splfiledlg.h`):
  `SplGetFileNameU8` (an `OPENFILENAMEA` whose *names* are UTF-8 and *texts* code page, run as
  `GetOpenFileNameW`/`GetSaveFileNameW`, the core's `FNERR_INVALIDFILENAME` retry kept) and
  `SplBrowseForFolderU8` (`SHBrowseForFolderW`, the same old-style dialog as the core's
  `GetTargetDirectory`). No plug-in interface change (a W service would be interface 108).
- A name that does not fit the plug-in's buffer is **refused** with the system's text for
  `ERROR_FILENAME_EXCED_RANGE` (Windows translates it - no new string), never cut and never
  converted to the code page.
- winliblt `EditLine`: WTF-8 both ways; a text that does not fit is refused the same way (the
  field focused). The core cuts at a whole character (093 D4); in plug-ins the fields are mostly
  names and paths in `MAX_PATH` buffers, where a cut names another file. After review 1 (B1) the
  refusal happens before anything is stored: each field's buffer size is recorded when it is
  filled and `ValidateData` refuses before Validate/Transfer (fix-log T010).
- Renamer: `AttachToWindowKeepKind` (102's opt-in), wide loops (093), the menu bar still gets
  code-page characters (the plug-in-facing `IsMenuBarMessage` expects them; 093).
