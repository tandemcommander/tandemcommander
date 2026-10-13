# Triage: pictview (feature 130)

Read: every `LoadStr(` use in `src/plugins/pictview/*.cpp` and `*.h` (171 lines with `LoadStr`,
menu items and tool tips included), plus the sinks `SetWindowText*`, `SetDlgItemText*`,
`ShowMessageBox`, `GetErrorText`. No build, nothing run - everything below is from reading.

## 1. How the names are encoded

- File names are UTF-8: `render1.cpp:132` ("the title carries the name of the viewed file: it is
  UTF-8"), `render1.cpp:316` (`oiei.FileName = name` - "'name' is UTF-8; the WIC engine opens
  Unicode/long paths directly"), `wicengine.cpp:957` (`OpenFromFileU8`), `saveas.cpp:698-705`
  (the Save As dialog converts `lpstrFile` with `SplU8ToW`).
- `SalamanderGeneral->GetErrorText()` is UTF-8 (`saveas.cpp:1100`, `render2.cpp:475` comments).
- The engine's error text (`PVW32DLL.PVGetErrorText`) is ASCII: the only engine initialised is
  the built-in WIC one (`pictview.cpp:1450` `InitWicEngine`), its texts are English literals
  (`wicengine.cpp:1096-1131`). `PVEXEWrapper.cpp` (the localized `IDS_DLL` texts) is in no
  `.vcxproj` of the plug-in.
- **Pseudo names**: `FileName` of a pasted / captured / scanned / deleted image is a `LoadStr()`
  text (`<Clipboard>`, `<Screen Capture>`, `<Scan>`, `<Deleted>`; `render1.cpp:3325, 3559, 4520`,
  `render2.cpp:248`, `pictview.cpp:2638`) - **code page**, and it is compared with `LoadStr()` by
  `_tcscmp` (`saveas.cpp:856-866`, `render1.cpp:3556, 3688, 3695`, `pictview.cpp:2332`). Left as
  they are; where such a name joins a UTF-8 sentence it is converted for that sentence only
  (`SplLegacyToU8Alloc`).

## 2. Compositions

| Place | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `render1.cpp:207-211` `SetTitle` | `IDS_TITLE` / `IDS_TITLE_MULTI` (cp; German has an en dash) | file name UTF-8 (or a cp pseudo name); `colors` from `IDS_NCOLORS*` (cp; Hungarian `szín`); numbers; `IDS_PLUGINNAME` (cp; Czech `Prohlížeč PictView`, Slovak `Prehliadač PictView`) | `SplU8ToWAlloc` -> `SplSetWindowTitleW`, else `SetWindowTextA` (`render1.cpp:220-224`) | **FIXED**: all four texts `LoadStrU8`, the name through `SplLegacyToU8Alloc`, `colors` 30 -> 100 bytes and bounded, `fmt` 32 -> 100, tail trims |
| `render1.cpp:410-421` `OpenFile` error | `IDS_ERROR_OPENING` (cp) | name UTF-8 (cp for the scanned bitmap's `<Scan>`), engine text ASCII | `SalMessageBox` | **FIXED**: `LoadStrU8`, name through `SplLegacyToU8Alloc` |
| `render1.cpp:4180-4195` printing failed | `IDS_PRINTING_FAILED` (cp; hu, sk, es accented) | `GetErrorText` UTF-8, or `IDS_UNKNOWN_ERROR` + `IDS_CHECK_EVENTLOG` (cp) | `SalMessageBox` | **FIXED**: three `LoadStrU8`; `errBuff[164]` filled by an unbounded `_stprintf` from `errTmp[MAX_PATH + 20]` -> `errTmp[1000]`, `errBuff[1200]`, `_TRUNCATE`, trim |
| `dialogs.cpp:1140` rename dialog subject | `IDS_RENAME_TO` (cp; cs, sk, hu accented) | name UTF-8 | core `SetSubjectTruncatedText` (`plugins3.cpp:523`: composes, shows through `SalSetWindowTextU8` - UTF-8 when valid, else code page; the core itself passes `LoadStrU8` templates to the same class, `fileswn7.cpp:2075`) | **FIXED**: `LoadStrU8` |
| `saveas.cpp:880` proposed name of a pasted / captured / scanned image | `"%s%d"` with `IDS_CLIPBOARD_FNAME` / `IDS_CAPTURE_FNAME` / `IDS_SCAN_FNAME` (cp; Czech `Zachycení`, `Skenování`, Slovak `Zachytiť`, Hungarian `Vágólap`, `Vizsgálat`) | number | `fileName` = UTF-8 for `SaveAsDialogU8` (`SplU8ToW` fails -> empty name, `saveas.cpp:704`) | **FIXED**: `LoadStrU8`, bounded. The word is short; `fileName` is `MAX_PATH` |
| `thumbs.cpp:407-412` thumbnail could not be written | `IDS_REGENERATE_THUMB_WRITEFILE` (cp) | name UTF-8 | `ShowMessageBox` | **FIXED**: `LoadStrU8`, own buffer `msg[1200]` (was an unbounded `_stprintf` into `newFile[_MAX_PATH]`), trim |
| `saveas.cpp:1055`, `1114`, `114` (`FormatNameMessageU8`) | `IDS_READ_ONLY_REWRITE`, `IDS_SAVE_ERR_EXISTS_OVERWRITE`, `IDS_SAVEERROR` (cp) | name / `GetErrorText` / temp path UTF-8 | composed wide, stored UTF-8, `SalMessageBox` | RIGHT AS IT IS (feature 104 / 111: the template is converted from the code page on the way) |
| `saveas.cpp:899`, `1023` | `IDS_SAVEERROR` (cp) | engine text ASCII | `SalMessageBox` | RIGHT AS IT IS (all code page) |
| `thumbs.cpp:288` | `IDS_ERROR_OPENING_CONTINUE` (cp) | number, engine text ASCII | `DialogError` text argument (the name is a separate argument) | RIGHT AS IT IS |
| `thumbs.cpp:515` | `IDS_SAVEERROR` (cp) | engine text ASCII | `ShowMessageBox` | RIGHT AS IT IS |
| `thumbs.cpp:308, 328, 434, 454-474` | `IDS_NOT_JPEG_FILE`, `IDS_NOT_EXIF_CREATE_JFXX`, `IDS_READ_ONLY_MODIFY` or `GetErrorText` alone | - (name is its own argument) | `DialogError` / `DialogQuestion` | RIGHT AS IT IS (no composition) |
| `thumbs.cpp:537-544` | `IDS_N_OF_N_FILES_PROCESSED` (cp, plural) | numbers | `ShowMessageBox` | RIGHT AS IT IS |
| `pictview.cpp:1577` | `IDS_LOADEXIF` (cp) | the DLL path converted to the code page on purpose (`pictview.cpp:1569-1571`) | `SalMessageBox` | RIGHT AS IT IS (a letter outside the code page shows as `?` - display only) |
| `pictview.cpp:3027` | `IDS_SCAN_OPEN_EXTRA_IMGS` (cp) | number | `SalMessageBox` | RIGHT AS IT IS |
| `wiawrap.cpp:2364` | `IDS_WIA_ERROR_ACQUIREIMG` (cp) | number, `_com_error::ErrorMessage()` (A build: code page) | `SalMessageBox` | RIGHT AS IT IS |
| `wiawrap.cpp:1681` | progress texts (cp) | number | `SetDlgItemText` A | RIGHT AS IT IS |
| `render1.cpp:1429-1442`, `statsbar.cpp:56-192`, `dialogs.cpp:178-238` | pipette, status bar, image properties (cp) | numbers | tool tip / status bar / `SetDlgItemText` A | RIGHT AS IT IS |
| `render1.cpp:2967-2972`, `3077`, `3088`; `saveas.cpp:1044, 1076`; `render2.cpp:335`; `render1.cpp:1784, 5032` | none (`GetErrorText` or the engine's text alone, or `"%s\n\n%s"` of two UTF-8 pieces) | - | `SalMessageBox` | RIGHT AS IT IS |
| `render1.cpp:217` (no image) | `IDS_PLUGINNAME` alone | - | wide when valid UTF-8, else A | RIGHT AS IT IS |
| `pictview.cpp:613-614` | `IDS_EXCEPT_INFO1` + `IDS_EXCEPT_INFO2` | - | kept text | RIGHT AS IT IS (both code page) |
| menus, tool tips, combo boxes, captions, `ShowOneTimeMessage`, `histwnd.cpp`, `print.cpp`, `pvtwain.cpp` | constant texts | - | A / core | RIGHT AS IT IS (no composition) |
| `PVEXEWrapper.cpp:524` | `LoadString(IDS_DLL + i)` | - | - | not compiled into the plug-in |

Counts: **6 fixed**, 20 rows right as they are, 0 recorded as unfixed compositions.

`LoadStrU8` was added to `pictview.cpp:433` (declaration `pictview.h:466`); `splloadstru8.h` is
included by `pictview.cpp` and `render1.cpp` only - not by `precomp.h`, which `salpvenv`'s
sources include too.

## 3. How to reach the fixed places (Czech or Slovak user interface)

1. **Title** (easiest): F3 on an image whose name has an accented letter
   (`Příliš žluťoučký kůň.png`). Before: the name in the title bar is garbled (the title is not
   valid UTF-8 because of `Prohlížeč PictView`, so it goes through `SetWindowTextA`). German:
   the same through the en dash of `IDS_TITLE`. Also a multi-page TIFF / animated GIF
   (`IDS_TITLE_MULTI`) and, as the negative control, a pasted image (`<Schránka>` must still
   read correctly).
2. **Open error** (easy): a text file renamed to `Žluťoučký.png`, F3 (PictView as the viewer of
   `*.png`) - the box `Nelze otevřít soubor ...` shows the name garbled before.
3. **Proposed name in Save As** (easy): Plugins > PictView > Screen Capture (or paste a bitmap
   with Ctrl+Shift+B), then File > Save As: Czech proposed nothing before, now `Zachycení1`.
4. **Rename dialog**: in the viewer File > Rename (the viewed file has an accented name): the
   line `Přejmenovat soubor "..." na` showed the name garbled.
5. Printing failed: File > Print to a printer that fails (`StartDoc` / `StartPage` error) -
   hard to drive.
6. Thumbnail update: Plugins > PictView > Update Thumbnails on a JPEG with EXIF when EXIF.DLL
   cannot write the new file - hard to drive (and see defect 2 below: accented names do not get
   that far).

## 4. Other defects seen (not fixed)

1. `thumbs.cpp:179` `CEnumFiles::GetFile`: `_sntprintf(fileName, _MAX_PATH, "%s%s%s", path, ..., Name)`
   into `path[_MAX_PATH]` (`thumbs.cpp:229`) - a full UTF-8 name over 259 bytes is **cut and left
   without a terminator**; the cut path is then opened, replaced (`ReplaceFileU8`,
   `thumbs.cpp:424`) and copied with `_tcscpy` (`thumbs.cpp:391`). A cut path that is used as a
   path.
2. `thumbs.cpp:277`: the path is converted to the code page (`U8ToDLLPathAlloc`, written for the
   old ANSI-only engine) and handed to the WIC engine, which reads `FileName` as UTF-8
   (`wicengine.cpp:957`). Read, not measured: Update Thumbnails cannot open a JPEG whose path
   has a letter outside ASCII (or opens a short 8.3 name). `thumbs.cpp:397-398` hand code-page
   paths to EXIF.DLL (its interface is ANSI - correct there).
3. `pictview.cpp:1570-1597` `InitEXIF`: when the plug-in's path does not fit `path[MAX_PATH]` in
   the code page (a DBCS code page) `path` is empty and `_tcsrchr(path, '\\') + 1` is `NULL + 1`
   - a write to address 1; the `"lang\\exif\\%s"` append is unbounded; `initTransl(path)` gets a
   code-page path (an installation folder outside the code page: no EXIF translations).
4. `thumbs.cpp:288`: unbounded `_stprintf` into `newFile[_MAX_PATH]` (template + engine text;
   fits today's texts).
5. `dialogs.cpp:251-265`: `PVII->Info1`, `Info2` and the image comment are set with
   `SetDlgItemTextA`; the comment's encoding was not followed (the engine's own strings are
   ASCII).
6. `render1.cpp:4183-4184` (before the change): `errBuff[164]` could overflow - fixed with the row.
7. Core, seen from here: `plugins3.cpp:533-534` cuts the name for the subject line with
   `lstrcpyn(tmpFileName, fileName, MAX_PATH)` (no trim of a torn character; display only).
