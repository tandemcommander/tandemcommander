# Feature 130 - triage of the ZIP plug-in (`src/plugins/zip`)

> **Correction after the triage (2026-10-13, the maintainer's session):** the core's progress
> dialog now sets its title wide from UTF-8 text (`src/zip.cpp`, `CZIPUnpackProgress`,
> `WM_INITDIALOG`; a text that is not valid UTF-8 is read as code page, as before). Where this
> record calls that title "code page only", or describes a second, wide title set by the
> plug-in, it describes the state before that change: the plug-in composes the title as UTF-8
> (`LoadStrU8`) and passes it to `OpenProgressDialog`.

> `OpenProgressDialogU8` (`common.cpp`) is the simple form.


Read-only work plus edits; **nothing was built or run**. Line numbers are those of the tree
after the edits. `LoadStr(` occurs 257 times in 12 files of the plug-in proper (the brief's 311
counts the separate programs too, see section 5).

## 1. How names are encoded where they meet the texts

- Everything that crosses the plug-in interface is UTF-8: `common.h:18-21` (comment and
  `U8_MAX_PATH`), the wrappers `CreateFileU8`, `SetDlgItemTextU8`, ... `common.h:27-50`.
  `ZipName`, `CFileInfo::Name`, `FileNameDisp` (`extract.cpp:1554` = a pointer into
  `fileInfo->Name`), the names of the packed files (`next->Name`) are UTF-8; names inside the
  archive are converted to UTF-8 at listing (`common.cpp:1658-1664`).
- Paths in the plug-in's own directory are UTF-8: `GetModuleFileNameU8` + `FindDataNameU8`
  (`add_del.cpp:378-382`, `dialogs3.cpp:522-565`).
- **Not** UTF-8 by construction: the names of *favourite settings* of the self-extractor. They
  are typed through `GetDlgItemTextA` (`dialogs.cpp:2046`, code page) and stored and loaded with
  the core's registry service, which is UTF-8 (`src/regwork.cpp:118` `SalRegQueryValueExW8`,
  `:218` `SalRegSetValueExW8`; the write keeps valid UTF-8 and converts anything else from the
  code page, `src/common/salunicode.cpp:360-371`). So a name is code page in the session it was
  typed in and UTF-8 after a restart.
- Texts of the self-extractor settings (`CSfxSettings`: title, text, button, vendor, message
  box) are code page end to end (`A` controls, binary blob in the registry, written into the
  stub) - no resource template is composed with them except `SfxFile` (a package file name).

### The core services the texts go to (read in `src/`)

| Service | What the core does with the text | Verdict |
|---|---|---|
| `SalMessageBox` / `ShowMessageBox` / `SalMessageBoxEx` | `src/zip.cpp:472-529` -> `src/msgbox.cpp:1241-1276` -> `CMessageBox`, `msgbox.cpp:454/457` `SalSetWindowTextU8`: valid UTF-8 -> UTF-16, anything else `SetWindowTextA` (`src/common/winlib.cpp:1111-1123`) | UTF-8 or code page, never a mix |
| `DialogError` (`error` text) | `src/zip.cpp:540-616` -> `CFileErrorDlg`, `src/dialogs.cpp:1597` `SalSetWindowTextU8` | UTF-8 or code page |
| `DialogError` (`fileName`) | `src/dialogs.cpp:1589-1590` `CStaticText::SetTextToDblQuotesIfNeeded` -> `SetText`, `src/gui.cpp:626-629` (UTF-8, else `CP_ACP`) | UTF-8 or code page |
| `OpenProgressDialog(title)` | `src/zip.cpp:5469-5502` -> `CZIPUnpackProgress::Set` keeps the pointer (`zip.cpp:98-119`), used once in `WM_INITDIALOG`: **`SetWindowText(HWindow, Title)`**, `src/zip.cpp:394` - the `A` call of a code-page build | **code page only** |
| `ProgressDialogAddText(txt)` | `src/zip.cpp:5550-5564` -> `NewLine`, `zip.cpp:248-292`: copied **byte-wise into a 300-byte line cache** (`zip.cpp:269-287`), shown with `CStaticText::SetText` (`zip.cpp:341`, `gui.cpp:626-629`) | UTF-8 or code page; a line over 299 bytes is cut inside a character |
| `CheckAndCreateDirectory(..., errBuf, 128)` (gives the `extText` of `ProcessError`) | `src/zip.cpp:784-789` -> `src/salamdr3.cpp:1123`: `LoadStrU8` + path at `:1151`, `:1196` (UTF-8); **`LoadStr` + path at `:1217`, `:1264`** (mixed); `LoadStr` alone at `:1137`; all copied with `strncpy_s(..., _TRUNCATE)` into the caller's 128 bytes without a tail trim | mostly UTF-8, can be mixed or torn (core) |
| `GetErrorText` | not used by this plug-in (it calls `FormatMessageA` itself) | - |
| `SplGetFileNameU8` | `src/plugins/shared/splfiledlg.h:304`, `:328-329`: filter and title are code-page texts by contract | code page (texts) |

## 2. Every composition of a resource text with a non-constant text

`FIXED` = changed in this feature; `RIGHT` = right as it is; `RECORDED` = wrong or doubtful, not
changed.

| # | Where | Template | Pieces and their encodings | Sink and its encoding | Verdict |
|---|---|---|---|---|---|
| 1 | `main.cpp:735` | `IDS_TESTOK` / `IDS_TESTKO` | template (was code page) + `zipFile` UTF-8 full path | `ShowMessageBox` (UTF-8 or cp) | **FIXED**: `LoadStrU8` + `SplU8TrimTornTail` (the buffer was bounded already) |
| 2 | `dialogs3.cpp:193` | `IDS_COMMENTDLGTITLE` | template (was code page) + `PackObject->ZipName` UTF-8 | `SplU8ToWAlloc` (strict UTF-8) -> `SplSetWindowTitleW` | **FIXED**: `LoadStrU8` + tail trim. Before: with a translated template that has a letter outside ASCII the text was not UTF-8, `SplU8ToWAlloc` gave NULL and **no title was set at all**, whatever the archive's name |
| 3 | `add.cpp:83`, `:282`, `:641` | `IDS_ADDPROGTITLE` | template + archive file name UTF-8 | `OpenProgressDialog` -> `SetWindowTextA` in the core (`src/zip.cpp:394`), code page only | **FIXED** through the new `OpenProgressDialogU8` (`common.cpp:98-119`), see below |
| 4 | `add_del.cpp:207` | `IDS_DELPROGTITLE` | the same | the same | **FIXED** (the same helper) |
| 5 | `add_del.cpp:541` | `IDS_SFXPROGTITLE` | template + `.exe` file name UTF-8 | the same | **FIXED** (the same helper) |
| 6 | `extract.cpp:70` | `IDS_EXTRPROGTITLE` | template + archive file name UTF-8 | the same | **FIXED** (the same helper) |
| 7 | `extract.cpp:222` | `IDS_TESTPROGTITLE` / `IDS_EXTRPROGTITLE` | the same | the same | **FIXED** (the same helper) |
| 8 | `add.cpp:1670` (+ `:1687-1688`) | `IDS_ADDING` prefix, then `lstrcpyn` of the name behind it | prefix (was code page) + packed file's relative name UTF-8 | `ProgressDialogAddText` (UTF-8 or cp) | **FIXED**: `LoadStrU8` (`sour` became `const char*`) |
| 9 | `del.cpp:111`, `:113` (+ `:142-143`) | `IDS_REMOVING` / `IDS_DELETING` prefix | prefix (was code page) + member name UTF-8 | `ProgressDialogAddText` | **FIXED**: `LoadStrU8` (`sour` became `const char*`) |
| 10 | `extract.cpp:2004` (+ `:2038-2039`) | `IDS_TESTING` / `IDS_EXTRACTING` prefix | prefix (was code page) + member name UTF-8 | `ProgressDialogAddText` | **FIXED**: `LoadStrU8` |
| 11 | `common.cpp:914-955` in `CZipCommon::ProcessError` (`:901`, the plug-in's error helper; 43 calls in `add.cpp`, `add_del.cpp`, `common.cpp`, `extract.cpp`) | `LoadStr(errorID)` + `"\n"` + `FormatMessageA(lastError)` + `"\n"` + `extText` | template code page; system text code page; `extText` = the core's `errBuf` of `CheckAndCreateDirectory` (`add.cpp:2593`, `extract.cpp:1493`, `:1530` - the only three calls that pass it), UTF-8 with a path | `DialogError` `error` text (UTF-8 or cp) | **FIXED**: the whole text is UTF-8 now - `LoadStrU8`, `FormatMessageW` -> UTF-8, `extText` through `SplDisplayTextToWAlloc` (UTF-8, UTF-8 with a torn tail, or code page) -> UTF-8; `_snprintf_s(_TRUNCATE)` + tail trim instead of three unbounded `sprintf` into 1,024 bytes (the system text alone could be 1,023). The rows without `extText` were all code page and right; they changed with the helper because it is one composition |
| 12 | `add_del.cpp:384` | `IDS_UNABLEREADSFX2` | template (was code page) + `file` UTF-8 path of the default `.sfx` | `ShowMessageBox` | **FIXED**: `LoadStrU8`, bounded (`err[512]` against a path of up to 1,040 bytes - it could overflow), tail trim |
| 13 | `dialogs3.cpp:586` | `LoadStr(r)`, `r` = `IDS_UNABLEREADSFX` / `IDS_CORRUPTSFX2` / `IDS_BADSFXVER` (`common.cpp` `LoadSfxFileData`) | template (was code page) + `file` UTF-8 name of a `.sfx` | `SalMessageBox` | **FIXED**: `LoadStrU8`, bounded (`err[512]`, the name can be 780 bytes), tail trim |
| 14 | `dialogs2.cpp:1076`, `:1625` | `IDS_NOLANGFILE` | template + `SfxFile`: a package file name read from a `.set` file or from a favourite's blob - bytes of unknown encoding (UTF-8 when it came from `FindDataNameU8`, anything when the file was written by hand) | `SalMessageBox` | **FIXED**: `LoadStrU8` + `SplLegacyToU8` of the name, bounded, tail trim. With the shipped packages (ASCII names) the old code showed the same text |
| 15 | `dialogs2.cpp:2143` | `IDS_REMOVEWARN` | template + favourite's name: code page in the session it was typed, UTF-8 after a restart (section 1) | `SalMessageBox` | **FIXED**: `LoadStrU8` + `SplLegacyToU8` of the name, bounded, tail trim |
| 16 | `common.cpp:2760-2769` `FormatMessage(buffer, errorID, lastError)` (the plug-in's second error helper); callers `add_del.cpp:428`, `dialogs2.cpp:605`, `:1261`, `:1423`, `:1705` | `LoadStr(errorID)` + `FormatMessageA` text appended | both code page, no name | `ShowMessageBox` / `SalMessageBox` | RIGHT |
| 17 | `dialogs3.cpp:541-545`, `:602-606` | `IDS_UNABLEREADSFXDIR` + `FormatMessageA` text | both code page | `SalMessageBox` | RIGHT |
| 18 | `add.cpp:412`, `:2881`, `:2883`, `:3502`, `:3551`; `dialogs.cpp:1597` | `IDS_CHDISKTEXT`, `IDS_CHDISKTEXT3`, `IDS_CHDISKTEXT2` | template + numbers | `WM_SETTEXT` `A` (`dialogs.cpp:1348`, `:1598`) | RIGHT |
| 19 | `dialogs.cpp:324-325` | `"%s %s"` | `VolSizeCache` (typed digits, code page) + `IDS_SIZE_KB/MB` | `CB_ADDSTRING` `A` | RIGHT |
| 20 | `dialogs.cpp:1259-1269`, `dialogs3.cpp:623-651` `FormatNumber` | digits + `IDS_BYTES` | ASCII digits and spaces + code-page text | `WM_SETTEXT` `A` | RIGHT |
| 21 | `add.cpp:2624-2655` -> `dialogs.cpp:1255` | `IDS_TOOLOWSPACE` / `IDS_LOWSPACE` / `IDS_LOWSPACE2` alone (the path goes to its own control with `SetDlgItemTextU8`, `dialogs.cpp:1257`) | one text | `WM_SETTEXT` `A` | RIGHT |
| 22 | `dialogs.cpp:1449-1452`, `:1689-1692` | filter `IDS_ZIPARCHIVES` ... | code-page texts | `SplGetFileNameU8` (texts are code page by contract) | RIGHT |
| 23 | `dialogs2.cpp:990-993`, `:1176` | filter `IDS_SETTINGSFILE`, `IDS_ALLFILES` | code-page texts | `SafeGetOpenFileName` / `SafeGetSaveFileName` (`A`) | RIGHT |
| 24 | `main.cpp:191-196` (About) | `"%s " VERSINFO_VERSION "\n\n" VERSINFO_COPYRIGHT "\n\n%s"` | `IDS_PLUGINNAME`, `IDS_PLUGIN_DESCRIPTION` code page + a source literal with `©` (`versinfo.rh2:18`) | `SalMessageBox` | RECORDED - no name in it; whether it is consistent depends on the bytes the compiler emits for `©` (no `/utf-8` or `/execution-charset` in `plugin_base.props` or `zip.vcxproj`; not determined without a build). The same text is in every plug-in |
| 25 | `iosfxset.cpp:820-922` `WriteSFXComment`, `:940-1139` | `IDS_SFX_COMMENT_*` chained with `strcat`; `"%s=\"%s\"\r\n"` with the settings' values | code-page comments + the values as they are in memory | written to the exported `.set` **file** | RECORDED - a text written to a file, the reader (`ImportSFXSettings`, `zip2sfx.exe`) takes the bytes as they are; not touched |
| 26 | `add.cpp:3340-3349` | `IDS_UNABLEREADSFX2` + `file` | - | - | not reachable: inside a `/* ... */` block (`add.cpp:3318-3375`) |
| 27 | `repair.cpp:107-108` | `IDS_EXTRPROGTITLE` | - | - | not reachable: the whole body of the file is commented out (from `repair.cpp:5`) |
| 28 | `add_del.cpp:387-390` | `IDS_DEFAULTTEXT`, `IDS_DEFSFXTITLE`, `IDS_DEFEXTRBUTTON` copied into the settings | one text each, code page | settings (code page, section 1) | RIGHT |

All other uses of `LoadStr(` are a single resource text handed to one sink (a message box text
or caption, `ProgressDialogAddText(LoadStr(...))`, a menu item, a combo box item, a window
text, `SetBasicPluginData`, a panel column name): 257 uses in all were read, none of the rest
composes the text with anything.

### Rows 3-7: the progress dialog's title

The core sets this title with `SetWindowTextA` (`src/zip.cpp:394`), so the archive's name in it
is wrong **in every language, English too**, as soon as it has a letter outside ASCII - and a
UTF-8 template alone would have made it worse (the translated template garbled as well). The
change stays inside the plug-in: `OpenProgressDialogU8` (`common.cpp:98-119`, declared
`common.h:337-341`)

1. composes the title as before (code-page template + name, now bounded) and opens the dialog
   with it - the core's `A` call sees what it saw before;
2. if the dialog was not open before the call and is open now (`ProgressGetHWND`,
   `spl_com.h:880`), composes the title again from `LoadStrU8` + name, trims a torn tail and
   sets it with `SplSetWindowTitleW`.

If the second step fails (no memory, text not UTF-8) the title is the one of the old code.
**A fix in the core (`SalSetWindowTextU8` at `src/zip.cpp:394`) would serve all plug-ins** and
make step 2 a no-op; it is recorded in section 4.

## 3. How a person reaches the fixed rows

Translated user interface whose template has a letter outside ASCII (Czech, German, French,
...) and a name with a letter outside ASCII, e.g. `Žluťoučký kůň.zip`. For rows 3-7 English is
enough.

| Row | Steps | Before | After |
|---|---|---|---|
| **1 (easiest)** | focus `Žluťoučký kůň.zip` in a disk panel, *Plugins > ZIP > Test Archive* | the final box "Archive '...' is OK." shows the path garbled | readable |
| **2 (easiest)** | focus any `.zip`, *Plugins > ZIP > Archive Comment* | the dialog keeps the title of its resource ("ZIP Archive Comment" without the archive) when the translated template has an accented letter; in English the title was right | "... - full path" |
| **6 / 7 (easy)** | open `Žluťoučký kůň.zip` in a panel and copy a file out of it (row 6, `CZipUnpack::UnpackArchive`); *Plugins > ZIP > Test Archive* or unpacking the whole archive from the disk panel (row 7, `CZipUnpack::UnpackWholeArchive` - which command of the core calls which of the two was taken from the function names, not followed into the core) | title of the progress dialog: the name garbled (also in English) | readable; needs an archive large enough to see the dialog, or a row in a probe that reads the title while it is open |
| 3 | Alt+F5 pack into `Žluťoučký kůň.zip` (`:83` existing or new plain archive, `:282` multi-volume, `:641` self-extracting) | the same | readable |
| 4 | open the archive in a panel, F8 on a member | the same | readable |
| 5 | focus a `.zip`, *Plugins > ZIP > Create Self-Extractor* (the `.exe` name is in the title) | the same | readable |
| 8, 9, 10 | the same operations as rows 3, 4, 6 with a **member** named `žluťoučký.txt`: the lines "adding: ...", "deleting: ...", "extracting: ..." in the progress dialog | the member's name garbled when the translated prefix has an accented letter | readable (names over about 290 bytes: see section 4) |
| 11 | unpack to a target that cannot be created: type a target path on a drive that does not exist (`Q:\čeština\`) in the Unpack dialog -> the error dialog "Cannot create directory." with the core's sentence below it | the core's sentence with the path garbled | readable. (With a target below an existing *file* the core's own sentence is mixed, `src/salamdr3.cpp:1217` - still wrong, section 4) |
| 12 | rename or remove the default package (`sfx\english.sfx` in the plug-in's directory) and install the program into a folder with an accented name; then any pack | path garbled | readable - hard to reach |
| 13 | put a damaged `x.sfx` with an accented name into the plug-in's `sfx` directory, open *Pack > self-extracting > Advanced* | name garbled | readable - hard to reach |
| 14 | Advanced self-extractor options > *Import*, a `.set` file whose `package` names a package that is not installed and has an accented name | name garbled | readable - hard to reach |
| 15 | Advanced self-extractor options > Favorites > *Manage*, select a favourite named `Výchozí`, *Remove* | before a restart right; after a restart (name read back as UTF-8) the name garbled | readable both times. NOT DRIVEN without a keyboard: the name must be typed |

## 4. Other defects seen on the way (not fixed)

In the core (`src/`, outside this work):

- `src/zip.cpp:394` - the progress dialog's title goes through `SetWindowTextA`: every plug-in's
  title with a UTF-8 name is wrong. One line (`SalSetWindowTextU8`) fixes all of them.
- `src/zip.cpp:269-287` - a progress line is cut byte-wise at 299 bytes; a UTF-8 name cut
  inside a character makes the whole line invalid UTF-8 and `CStaticText::SetText` shows it
  through the code page (`src/gui.cpp:626-629`). Reachable with a member path of about 100
  Czech or 150 CJK characters.
- `src/salamdr3.cpp:1217` (`IDS_NAMEUSEDFORFILE`) and `:1264` (`IDS_CREATEDIRFAILED`) compose
  `LoadStr` with a UTF-8 path into `errBuf` (the same template is `LoadStrU8` at `:1151`,
  `:1196`); `:1153`, `:1198`, `:1219`, `:1266` copy into `errBuf` with `_TRUNCATE` and no tail
  trim, and the callers here give 128 bytes - so the path in `extText` is cut, possibly inside a
  character (the plug-in's side now survives a torn tail, row 11).

In the plug-in:

- Favourite names (section 1): code page in the session, UTF-8 after a restart. The list box
  (`dialogs2.cpp:2066`, `:2118`, `LB_ADDSTRING` `A`), the rename dialog (`dialogs.cpp:2034`,
  `WM_SETTEXT` `A`) and the favourites menu show a reloaded name with an accented letter
  garbled; `CompareMenuItems` (`dialogs.cpp:2055`) compares the two encodings. The buffer for
  the reloaded name is `MAX_FAVNAME` = 50 bytes (`main.cpp:350`) while the UTF-8 form of a
  49-letter name can be 98 - the read then fails and the favourite is not loaded.
- `extract.cpp:1970` - the progress line buffer is `maxNameLen + 128` and the prefix is copied
  without a bound (`:2005-2006`); `add.cpp:1672-1673`, `del.cpp:115-116` the same into 1,072
  bytes. Fine for any real translation of "extracting: ", not checked by the code.
- `add.cpp:1687`, `del.cpp:142` - `lstrcpyn` of the name into the line buffer cuts byte-wise
  (only for relative names over about 1,050 bytes; the core cuts at 299 anyway).
- `dialogs3.cpp:185` - the archive comment goes to its edit control with `SetDlgItemTextA`; the
  comment's encoding (OEM / code page of the archive) was not followed.
- `prevsfx.cpp:128-146` - the self-extractor preview sets all texts with `A` calls; they are
  code-page settings, right as long as the settings stay code page.
- `add_del.cpp:391` - the default vendor line holds `©` from a source literal, the same doubt
  as row 24.
- `common.cpp:2760-2769` `FormatMessage()` assumes a buffer of at least 512 bytes and copies
  the resource text with `lstrcpy`; every caller gives 1,024.
- No `%ls` in a narrow `printf` and no `GetErrorText` use was found in the plug-in.

## 5. Not part of the plug-in (recorded only, not read line by line)

`selfextr/` (the self-extractor stub), `zip2sfx/` and `sfxmake/` are separate programs built
without the plug-in interface (their own `StringTable`, `/execution-charset` per language in
`vcxproj/selfextr/selfextr.vcxproj:96`); `sfxmake.cpp` is not in `zip.vcxproj`. They contain no
`LoadStr(` of the plug-in and were not changed. Their texts are code page (`SetWindowTextA`,
`SetDlgItemTextA` throughout `selfextr/dialog.cpp`).

## 6. What was changed (9 files)

- `common.h` - `#include "splloadstru8.h"`, declarations of `LoadStrU8` and
  `OpenProgressDialogU8`.
- `common.cpp` - `LoadStrU8`, `OpenProgressDialogU8`, `ProcessError` (row 11).
- `add.cpp`, `add_del.cpp`, `extract.cpp`, `del.cpp`, `main.cpp`, `dialogs2.cpp`,
  `dialogs3.cpp` - the rows above.

BOM and line endings kept (`dialogs2.cpp` and `dialogs3.cpp` have no BOM and still have none;
all files CRLF).

## 7. Not sure about

- **Nothing was compiled.** The points most worth a look at the first build:
  `splloadstru8.h` included from `common.h` (every source of the plug-in sees it);
  `_snprintf_s(array, _TRUNCATE, ...)` in the array form at the new places;
  `const char* sour` in `add.cpp:1644` and `del.cpp:104`.
- `OpenProgressDialogU8`: that `SplSetWindowTitleW` right after `OpenProgressDialog` gives the
  exact title on the core's code-page dialog is what feature 100 says of such windows; it was
  not seen on a screen. The first, `A`-set title may be visible for an instant.
- Row 11 changes the text of all 43 `ProcessError` calls from code page to UTF-8. The sink was
  read (`src/dialogs.cpp:1597`), the result was not seen.
- Row 24 (About) and the `©` literal: not judged.
- Rows 14 and 15: the piece is of unknown encoding and is taken as UTF-8 when it is valid UTF-8,
  else as code page (`SplLegacyToU8`); a code-page name that happens to be valid UTF-8 would be
  read wrongly.
