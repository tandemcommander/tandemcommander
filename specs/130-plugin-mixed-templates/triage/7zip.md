# Triage: 7zip (feature 130)

Read: every `LoadStr(` use in `7zip.cpp`, `7zclient.cpp`, `7zthreads.cpp`, `dialogs.cpp`,
`extract.cpp`, `FStreams.cpp`, `update.cpp` (85 uses) and every caller of the helpers `Error`,
`Warning`, `SysError`, `CExtractCallbackImp::Error`, `ShowRetryAbortBox`. The matches in
`7za/CPP/Windows/ResourceString.*` are 7-Zip's own `MyLoadString`, not the plug-in's `LoadStr`
(not read further). Not built, not run.

## 1. Encoding of the names where they meet the texts

- 7-Zip's library works in UTF-16 (`UString`); the plug-in converts at its boundary with
  `UStringToU8` / `U8ToUString` (`structs.h:17-30`, `CP_UTF8`). Every narrow name the messages use
  is **UTF-8**: `CArchiveItemInfo::NameInArchive` (`7zclient.h:53`, a `CSysString` filled from the
  core's `const char*`), `ProcessedFileInfo.Name = aii->NameInArchive` (`extract.cpp:475`),
  `CurrentItemName = UStringToU8(path.bstrVal)` (`extract.cpp:424`), `TargetFileName`
  (`extract.cpp:479-488`), the archive path `fileName` / `archiveName` / `tmpName` from the core.
- The Windows reason is `SalamanderGeneral->GetErrorText()`: **UTF-8**.

## 2. Compositions

Sinks verified in the core: `ShowMessageBox` / `SalMessageBox` / `SalMessageBoxEx` (reached through
`WM_7ZIP_SHOWMBOXEX`, `7zthreads.cpp:59`); `ProgressDialogAddText` -> `CStaticText::SetText` (UTF-8,
else code page); `DialogError` (see `checksum.md`). `ExpandPluralString` splits only at the ASCII
characters `{ | } \ :` (`src/salamdr4.cpp:412-482`), so it is safe for a UTF-8 template.

| Site | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `7zip.cpp:214-229` `Error(resID, quiet, ...)` | any | a UTF-8 archive path at `7zclient.cpp:443`, `519` (`IDS_CANT_OPEN_ARCHIVE[_PWD]`), `1276`, `1819` (`IDS_CANT_UPDATE_ARCHIVE`), and at `454` / `519` for `IDS_UNSUPPORTED_ARCHIVE`, whose text has no `%s` (the argument is ignored); a number at `7zclient.cpp:1864`, `7zthreads.cpp:176`; nothing elsewhere | `ShowMessageBox` | **FIXED** - `LoadStrU8`, tail trim |
| `7zip.cpp:264-282` `SysError(resID, err, quiet, ...)` | any | optional UTF-8 path (`7zclient.cpp:1270`, `1295`, `1828`, `1871`, `7zip.cpp:1135`) + `"\n\n"` + `GetErrorText` (UTF-8) - mixed at **every** call (11 callers) | `ShowMessageBox` | **FIXED** - `LoadStrU8`, tail trim |
| `7zip.cpp:1534` `TestArchive` | `IDS_TESTING_ARCHIVE_NAME` | `cfd->Name` UTF-8 | `ProgressDialogAddText` | **FIXED** |
| `7zip.cpp:1546`, `1553` | `IDS_TESTARCHIVEOK`, `IDS_TESTARCHIVECORRUPTED` | `fileName` UTF-8 full path | `SalMessageBox` | **FIXED** |
| `extract.cpp:568` | `IDS_NAMEISTOOLONG` | `NameInArchive`, `TargetFileName` - both UTF-8 | `ShowMessageBox` | **FIXED** |
| `extract.cpp:654-657` `OnDataError` | `IDS_ERROR_PROCESSING_FILE[_PWD]` | `ProcessedFileInfo.Name` UTF-8 | `SalMessageBoxEx` text | **FIXED** |
| `extract.cpp:720-737` `CExtractCallbackImp::Error` | `IDS_DATA_ERROR[_PWD]` with `CurrentItemName` / `ProcessedFileInfo.Name` (`extract.cpp:854`, `883`, `913`); no argument elsewhere | UTF-8 names | `SalMessageBoxEx` text | **FIXED** |
| `FStreams.cpp:35-45` `ShowRetryAbortBox` | `IDS_CANT_WRITE` (plural form), `IDS_CANT_READ`, `IDS_CANT_READ_ARCHIVE` | a number, then `"\n\n"` + `GetErrorText` (UTF-8) | `SalMessageBoxEx` text | **FIXED** - `LoadStrU8` |
| `7zip.cpp:198-212` `Warning()`, `232-246` `Error(HWND, ...)` | any | - | - | RIGHT AS IT IS - no caller in the plug-in (unreachable) |
| `7zclient.cpp:927` | `IDS_LINKS_SKIPPED` | a number | `SalMessageBox` | RIGHT AS IT IS |
| `extract.cpp:641`, `FStreams.cpp:58` | `"%d\t%s\t%d\t%s"` | numbers + button texts (`LoadStr`) only | `MSGBOXEX_PARAMS::AliasBtnNames` | RIGHT AS IT IS (all code page; the core's reading of button names was not examined) |
| `7zip.cpp:436`, `472`, `1255`; `7zthreads.cpp:66-67` | title only | `GetErrorText` alone as the error text, name separate | `DialogError` | RIGHT AS IT IS |
| `7zip.cpp:1467` | `IDS_UNISO` | - | - | RIGHT AS IT IS - inside a block that is not compiled |
| `7zip.cpp` About, column names, menu items, progress texts, dialog titles | a resource text alone or with literals | | | RIGHT AS IT IS |

## 3. How to reach the FIXED sites

- **`7zip.cpp:1546` / `1553` (easiest)**: Hungarian (`"A(z) '%s' archívum jó."`) or Czech for a
  damaged archive (`"Archiv '%s' je poškozený."`; the Czech OK text is ASCII); focus a `.7z` in a
  folder or with a name with accented letters, Plugins > 7-Zip > Test Archive: the box names the
  full path. Before: the path garbled.
- **`7zip.cpp:1534` (easy)**: the same command in Slovak (`"Testujem archív '%s'..."`) or Hungarian;
  the line in the progress dialog while a large archive is tested.
- **`Error(IDS_CANT_OPEN_ARCHIVE, quiet, fileName)` (easy)**: Czech (`"Nelze otevřít archiv '%s'."`),
  a `.7z` with an accented name that cannot be opened for reading (held by another program without
  sharing, or no permission), Enter on it. Before: the name garbled.
- `SysError`: e.g. pack into a `.7z` in a read-only folder (`7zip.cpp:1111` /
  `7zclient.cpp:1170`): template, empty line, Windows reason - the reason was garbled whenever the
  template had an accented letter.
- `extract.cpp:654` / `720`: a damaged or wrongly-passworded member with an accented name (needs a
  prepared archive). `extract.cpp:568`: extract into a target whose full path is too long.
  `FStreams.cpp:35`: a write error during extraction (a full target volume).

## 4. Other defects seen (not fixed)

- `dialogs.cpp:599`: `SetWindowText` (A) of the archive path (`Archive`, UTF-8 from the core,
  `7zip.cpp:1151`) into the static `IDC_NA_ARCHIVE` of the pack options dialog - a code-page sink:
  an archive path with letters outside ASCII is garbled there in every language; and
  `dialogs.h:118` `SetArchiveName` cuts the path with `lstrcpyn(Archive, archiveName, MAX_PATH)`
  (display only, but it can cut inside a character). Not a resource-text composition; the fix is
  `SetWindowTextW` + `SplU8ToWAlloc`.
- `FStreams.cpp:39`: `((int*)&err)[1]` reads the first variable argument through the address of the
  `err` parameter (works on x64 only by the layout of the home area) - the plural form of
  `IDS_CANT_WRITE` depends on it.
- `7zip.cpp:274-281`: `msg[1024]` cut by `_TRUNCATE` and then joined - a long path shortens the
  message (never a name used as such); a tail trim was added for the cut.
- `7zip.cpp:206`, `240` (`Warning`, `Error(HWND, ...)`): still `LoadStr`; when a caller with a name
  is ever added, they need `LoadStrU8` like `Error(resID, ...)`.
