# Feature 130 triage: `renamer` (Batch Rename)

Read: every `LoadStr(` use in `src/plugins/renamer/` (68 hits in 9 files) and every call of the
plug-in's message helpers (`Error`, `ErrorL`, `FileError`, `FileOverwrite`, `SalPrintf`),
`FormatMessage`, `GetErrorText`, `SetWindowText*`, `SetDlgItemText*`. Not built, not run.
Line numbers are those after the change.

## 1. Encodings where names meet texts

| Text | Encoding | Evidence |
|---|---|---|
| source names / paths (`CSourceFile::FullName`, `Name`), new names | UTF-8 | `rendlg.cpp:1337` ("'path' is UTF-8 since plugin interface 104"), `utils.cpp:102-136` (`CreateFileU8` ... convert with `SplU8ToWExtAlloc`), `preview.cpp:203` (`GetEditLineU8`) |
| `LoadStr(id)` | code page | `renamer.cpp:71-74` |
| `SG->GetErrorText(err, buf, size)` | UTF-8 | core `src/zip.cpp:1589-1606` |
| `FormatMessage` (A) | code page | `renamer.cpp:93`, `utils.cpp:222` |

Sinks (read in the core):
`SG->SalMessageBox` - UTF-8 when valid, else code page;
`SG->DialogError` -> `CFileErrorDlg` (`src/zip.cpp:540-602`, `src/dialogs.cpp:1578-1599`): the
name through `CStaticText`, **the error text through `SalSetWindowTextU8`** (UTF-8 when valid,
else `SetWindowText` A - `src/common/winlib.cpp:1111-1123`), the caption through `SetWindowText` (A);
`SG->DialogQuestion` -> `CHiddenOrSystemDlg` (`src/dialogs.cpp:1749-1765`): the same three;
`SG->DialogOverwrite` -> `COverwriteDlg` (`src/dialogs.cpp:1694-1713`): the two attribute texts
through `SalSetDlgItemTextU8`;
the preview list (`preview.cpp:139-147`): `MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS)`,
else `CP_ACP` - UTF-8 when valid, else code page.

## 2. Compositions

| Where | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `utils.cpp:38-54` `FileError` (28 call sites: `rendlg.cpp:1330, 1348, 1430, 1446`, `rendlg2.cpp:266-702`, `rendlg3.cpp:56-508`, `utils.cpp:716`) | `error` id copied, then `SG->GetErrorText()` appended (`IDS_MOVEERROR` "Unable to rename file: ", `IDS_OVERWRITEERROR`, `IDS_DELETEERROR`, `IDS_WRITEERROR`, `IDS_READERROR`, `IDS_OPENFILEERROR`, `IDS_DIRCASEERROR`, `IDS_CREATEDIR`, `IDS_REMOVEDIR`, `IDS_ERRREADDIR`, ... ) | template was code page; Windows error text UTF-8 | `DialogError`'s error text (UTF-8 or code page) | **FIXED** - `LoadStrU8(error)`, bounded copy (`SplU8CopyTrunc`), tail trimmed after `GetErrorText`. The file name is a separate field of the dialog and was right before; what was garbled is the Windows error text (cs: `Přístup byl odepřen.`) whenever the template or the error text held an accented letter. The caption stays `LoadStr(title)` |
| `renamer.cpp:84-109` `ErrorHelper` (`Error(int, ...)`, `Error(HWND, int, ...)`, `ErrorL`) | `vsprintf(buf, LoadStr(error), args)` + `FormatMessage` (A) | every caller passes **no** argument after the id (`editor.cpp:481-510`, `menu.cpp:40`, `rendlg.cpp:1488, 1495, 2330`, `rendlg2.cpp:215`, `rendlg4.cpp:13-365`) - no name, no pattern; the system text is code page | `SalMessageBox` | RIGHT AS IS (all code page) |
| `rendlg2.cpp:215` `Error(error)` for a bad mask / regular expression / replace pattern | the reason's own id (`IDS_REE*`, `IDS_EXP_*` from `GetRegExpErrorID`, `utils.cpp:571-619`) | none - the pattern is not put into the text | `SalMessageBox` | RIGHT AS IS |
| `preview.cpp:205, 222, 253` the *New name* column when the name cannot be made | `IDS_GENERICERR` / `IDS_NEWNAMEERR` / `IDS_REGEXPERR` / `IDS_BMERR` / `IDS_REPLACEERR` ("<Error: %s>") | `LoadStr(error)` / `LoadStr(IDS_EXP_SMALLBUFFER)` - code page | the preview list (UTF-8 or code page) | RIGHT AS IS (both code page). Two `LoadStr` in one expression: relies on the core's rotating buffer, as before |
| `preview.cpp:214` | `IDS_TRANSFERERROR` alone | - | preview list | RIGHT AS IS |
| `utils.cpp:212-251` `GetFileData` -> `FileOverwrite` -> `DialogOverwrite` | `"%s, %s, %s"` | `LoadStr(IDS_DIRTEXT)` or `NumberToStr`, `GetDateFormat` / `GetTimeFormat` (A); or `FormatMessage` (A) alone | `SalSetDlgItemTextU8` | RIGHT AS IS (all code page, shown through the code-page fallback) |
| `utils.cpp:329-331` `DialogQuestion(fileName1, LoadStr(shquestion), LoadStr(shtitle))` | question alone, name in its own field | - | `CHiddenOrSystemDlg` | RIGHT AS IS (never combined) |
| `rendlg3.cpp:79-84` file left under the temporary name | `"%s\n\n%s"` - no resource text | `GetErrorText` UTF-8, path UTF-8 | `SalMessageBox` | RIGHT AS IS (all UTF-8) |
| `renamer.cpp:246-252` About | `"%s " VERSINFO_VERSION ...` | two `LoadStr` + literals | `SalMessageBox` | RIGHT AS IS (all code page) |
| `rendlg.cpp:1273-1275` count of files | `ExpandPluralFilesDirs` (the core's text) | - | `SetDlgItemText` (A) | RECORDED - the core composes it; whether its text can be UTF-8 with accented letters (then the A sink shows it garbled) was not checked, and it holds no name |

All other `LoadStr` uses are a text alone (message box texts and captions, combo and list
headers `dialogs.cpp:322`, `preview.cpp:46`, menu items `utils.cpp:416`, `renamer.cpp:468`,
progress texts `rendlg2.cpp:254, 540, 605` through `SetDlgItemText` (A), the empty-list static
`preview.cpp:657, 671`, the open dialog filter `dialogs.cpp:1051`, wait window
`renamer.cpp:274`).

Added: `LoadStrU8` in `renamer.cpp:77-82` (+ `#include "splloadstru8.h"`), declared in
`renamer.h:119`.

## 3. How to reach the fixed site

Language Czech (also German, French, Hungarian, Slovak, Spanish - the templates and / or the
Windows error text hold accented letters). Plugins > Batch Rename (Ctrl+Shift+R) on selected
files, then *Rename*:

- **Easiest (mark 1)**: select one file that another program holds open without sharing (or a
  file in a folder where renaming is denied), type a new name, *Rename*. The error dialog's
  text line must read `Nelze přejmenovat soubor: (32) <the Windows text>` (cs string 1227 +
  `GetErrorText`), both parts readable. Before: the whole line goes through the code page and
  the Windows text is garbled. Code: `rendlg3.cpp:133` (`IDS_MOVEERROR`).
- **Mark 2**: rename `a.txt` to the name of an existing file that cannot be deleted (held
  open by another program), answer *Yes* to the overwrite question: `rendlg3.cpp:126`
  (`IDS_OVERWRITEERROR`, cs `Nelze přepsat soubor: ` + the Windows text).
- *Include subdirectories* on a folder that cannot be read (access denied):
  `rendlg.cpp:1348 / 1446` (`IDS_ERRREADDIR`, cs `Nelze číst adresář.` + the Windows text).
- Not a good row: the logical errors (`IDS_DUPLICATENAME`, ...) - they get an error text only
  when a stale `GetLastError()` value is left (see 4).

## 4. Other things seen (not changed)

- `utils.cpp:42` `FileError` takes `GetLastError()` at entry for **every** caller, also for
  those that report a logical error (`IDS_DUPLICATENAME`, `IDS_DEPENDENCE`, `IDS_DIRNOTSAMEROOT`,
  `IDS_NOTVALID_*`, `IDS_EXP_SMALLBUFFER`, `IDS_TOOLONGPATH`): a stale error code of an earlier
  call is appended to the sentence.
- `renamer.cpp:89` `vsprintf` into `char buf[1024]` unbounded, and `FormatMessage` gets
  `1024 - l` (no argument today, so only the template's length matters).
- `rendlg2.cpp:194` `char newName[MAX_PATH]`, `preview.cpp:203-253` `NewNameCache` used with
  `MAX_PATH` **bytes** for a UTF-8 name: a new name over 259 bytes (86 three-byte letters) is
  refused with "Expanded string is too large" (refused, not cut - but the limit is bytes).
- `preview.cpp:267-272` the *Path* column: `lstrcpyn(TextBuffer, item->FullName, ...)` cuts a
  long path at a byte (display only; a cut inside a character makes the cell go through the
  code page).
- `utils.cpp:15-17` histories are stored and read with `registry->GetValue/SetValue(REG_SZ)` -
  the encoding in the registry is the core's service's; not checked here.
- `dialogs.cpp:823` `SetDlgItemText(HWindow, IDE_STDERR, StdError)` (A): the output of an
  external command is shown through the code page (console programs write OEM or UTF-8).
- `utils.cpp:108, 117, 125, 133, 207`: the `A` API fallback when the UTF-8 conversion fails
  (`CreateFileA(fileName)` ...) passes a non-UTF-8 name to an `A` API - best fit can name
  another file; reachable only with a name that is not valid WTF-8.
