# Feature 130 triage: `dbviewer` (Database Viewer)

Read: every `LoadStr(` use in `src/plugins/dbviewer/` (55 hits in `dbviewer.cpp`, `data.cpp`,
`dialogs.cpp`, `parser.cpp`, `renmain.cpp`, `const.h`), plus every `sprintf` / `strcat` /
`SetWindowText` / `WM_SETTEXT` / `SalMessageBox` in the directory. Not built, not run.
Line numbers are those after the change.

## 1. Encodings where names meet texts

| Text | Encoding | Evidence |
|---|---|---|
| the viewed file's name (`Database.GetFileName()`) | UTF-8 | `renmain.cpp:217` (`char file[3 * MAX_PATH]; // UTF-8 path from the Open dialog`), `renmain.cpp:240` `SplGetFileNameU8`, `renmain.cpp:281-283` (the old comment "file name is UTF-8") |
| `LoadStr(id)` | code page | `dbviewer.cpp:246-249` -> `SalGeneral->LoadStr` |
| `SalGeneral->GetErrorText(status)` | UTF-8 | core `src/zip.cpp:1589-1606` (feature 010) |
| the text typed in Find (`FindDialog.Text`) | code page | `dialogs.cpp:33-52` `HistoryComboBox` reads with `SendMessage(WM_GETTEXT)` (A); it is compared with cell text converted with `CP_ACP` (`renmain.cpp:572`) |
| `Coding` (name of the conversion) | the core's text, encoding not established (ASCII in practice: "UTF-8", "CP852 - CP1250") | `renmain.cpp:342, 406, 459, 492`; comes from `EnumConversionTables` / `RecognizeFileType` / `GetWindowsCodePage` |
| column names from the file | code page or UTF-16, set with the matching list-view message | `dialogs.cpp:510-514` |

Sinks: `SalMessageBox` (UTF-8 when valid, else code page); the viewer's title -
`SplU8ToWAlloc` + `SplSetWindowTitleW`, **and `SetWindowTextA` when the text is not valid
UTF-8** (`renmain.cpp:305-311`); the File Info edit - `EM_REPLACESEL` through `SendMessage` (A,
code page).

## 2. Compositions

| Where | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `renmain.cpp:292-302` `SetViewerTitle` | `"%s - %s"` + `IDS_PLUGINNAME` (+ `" - [%s]"` `Coding`) | file name UTF-8; plug-in name was `LoadStr` = code page (cs `Prohlížeč databází`, de `Datenbank Betrachter`, fr, es, hu, sk all translated; 5 of them with accented letters); `Coding` unknown | wide title when the whole is valid UTF-8, else `SetWindowTextA` | **FIXED** - `LoadStrU8(IDS_PLUGINNAME)`; `Coding` through `SplLegacyToU8`; the two `sprintf` are bounded by the heap buffer's size (the buffer is `strlen(fileName) + 400`, so nothing is cut). Before: in Czech every title was invalid UTF-8 and went through `SetWindowTextA` - a file name with a letter above ASCII was garbled |
| `renmain.cpp:656-659` `Find` | `IDS_FIND_NOMATCH` / `IDS_FIND_NOREGEXPMATCH` | pattern = code page (see 1) | `SalMessageBox` | RIGHT AS IS (all code page) |
| `parser.cpp:146-156` `ShowParserError` | none - either `LoadStr(strID)` or `GetErrorText()` alone | - | `SalMessageBox` | RIGHT AS IS (never combined) |
| `parser.cpp:299-353`, `1030-1041` File Info | `"%s:\t%s\r\n"` + `IDS_FINFO_*` | `GetDateFormat` / `GetTimeFormat` (A), `PrintDiskSize` (ASCII digits + unit from the core), numbers, `LoadStr(verStrID)` | `EM_REPLACESEL` (A) | RIGHT AS IS (all code page; `PrintDiskSize`'s unit text is the core's - not checked whether it can be UTF-8 with a non-ASCII unit, see 4) |
| `dialogs.cpp:402-406` font description | `IDS_FONTDESCRIPTION` | `logFont.lfFaceName` (`LOGFONTA`, code page), `LoadStr(IDS_CUSTOMFONT / IDS_DEFAULTFONT)` | `SetWindowText` (A) | RIGHT AS IS |
| `dbviewer.cpp:391-397` About | `"%s " VERSINFO_VERSION ... "%s"` | two `LoadStr` texts + string literals (the copyright literal holds `©`) | `SalMessageBox` | RIGHT AS IS (all code page - the literal is compiled into the build machine's code page; no `/utf-8` in `plugin_base.props`) |
| `dbviewer.cpp:997` regular expression error | none (`regexp->GetLastErrorText()` alone) | - | `SalMessageBox` | RIGHT AS IS (no composition in the plug-in) |

All other `LoadStr` uses are a text alone: message box texts and captions (`dbviewer.cpp:414, 575`,
`data.cpp:159, 177`, `dialogs.cpp:585`, `renmain.cpp:1286`), menu items (`dialogs.cpp:441-442`),
list-view column headers (`dialogs.cpp:676-695`), the open dialog's filter (`renmain.cpp:223`),
tooltip (`dbviewer.cpp:1417`), cell texts `IDS_TRUE` / `IDS_FALSE` / field types
(`parser.cpp:409, 480, 625, 629, 1117`), window class title (`dbviewer.cpp:663`),
`SetBasicPluginData` (`dbviewer.cpp:371, 376`).

Added: `LoadStrU8` in `dbviewer.cpp:252-256`, declared in `const.h:14`; `renmain.cpp` includes
`splloadstru8.h` (for `SplLegacyToU8`).

## 3. How to reach the fixed site

- **Easiest (mark 1)**: Czech (or German / French / Spanish / Hungarian / Slovak) language; a
  `.dbf` or `.csv` file named with a letter above ASCII, e.g. `Příliš žluťoučký kůň.csv`; F3
  (Database Viewer is the viewer for `*.dbf;*.csv`). The window title must read
  `<full path> - Prohlížeč databází`. Before the fix the path part is garbled. Compare with
  `InternalGetWindowText` (the viewer window is a code-page window, feature 100).
- With a conversion chosen (menu *Convert*): the title ends with ` - [<conversion>]`.

## 4. Other things seen (not changed)

- `renmain.cpp:656/658`: `sprintf` into `char text[1000]` with the search pattern - bounded only
  by `FIND_TEXT_LEN` (`dialogs.h:159`); not checked that template + pattern always fit.
- `dialogs.cpp:45-52`: the Find text is read and set with code-page `WM_GETTEXT` / `WM_SETTEXT`,
  so a search text outside the code page becomes `?` (best fit) - a feature 104 kind of defect,
  not a template one.
- `parser.cpp:296-298, 1027-1029`: `GetDateFormat` (A) into `buff2`, then `strcat` and
  `GetTimeFormat` with a fixed 100 for the rest - the size passed to `GetTimeFormat` ignores
  what is already in the buffer (did not check the buffer's declared size).
- `PrintDiskSize` returns the core's text; whether its unit can hold a letter above ASCII as
  UTF-8 (then the File Info line would be a mix shown through the code page) was not checked.
- `dbviewer.cpp:1417`: `lstrcpy(tt->Buffer, LoadStr(...))` - the tooltip buffer's size is the
  core's, not checked.
