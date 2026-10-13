# Feature 130 triage: `filecomp` (File Comparator)

Read: every `LoadStr(` / `LoadStrU8(` / `LoadStrW(` use in `src/plugins/filecomp/` (108 hits in
13 files, `fcremote/fcremote.cpp` included) and every `FormatMessage`, `CException`, `Raise(`,
`ErrorU8(`, `Error(`, `DialogError`, `SalMessageBox`, `SetWindowText*`, `SetDlgItemText*`,
`WM_SETTEXT`, `->SetText(` in the directory. Not built, not run.

**Nothing was changed in this plug-in.** Feature 102 already moved every sentence that holds a
file name to the plug-in's own `LoadStrU8` (`filecomp.cpp:34-67`, kept as it is); what still
uses `LoadStr` is a text alone or a sentence whose other pieces are code page.

## 1. Encodings where names meet texts

| Text | Encoding | Evidence |
|---|---|---|
| the compared files' names (`Path1`, `Path2`, `Files[i].Name`) | UTF-8 | `filecomp.h:113-136` (the feature 102 note), `mainwnd.cpp:922-929`, `dialogs.cpp:166-169` |
| `LoadStr(id)` | code page | the core's `LoadStr` |
| `LoadStrU8(id)` | UTF-8 | `filecomp.cpp:34-67` (from `SG->LoadStrW`) |
| the system's error text in the plug-in's sentences | UTF-8 (`AppendSystemErrorU8`, `FormatMessageW`) | `filecomp.cpp:116-125` |
| the system's error text in the hex view's error | code page (`FormatMessage` A) | `viewwnd3.cpp:1197` |
| `fcremote.exe` texts | English constants | `fcremote/fcremote.cpp:50-...` (its own `LoadStr` is a `switch`) |

## 2. Compositions

| Where | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `filecomp.cpp:183-195` `ErrorU8` (`mainwnd.cpp:1651, 1663`, `viewwnd3.cpp:176`) | `LoadStrU8(resID)` | name UTF-8, `AppendSystemErrorU8` UTF-8 | `SalMessageBox` | RIGHT AS IS (done in 102) |
| `worker.cpp:160-177` `CException::Raise` (callers in `textio.cpp`, `worker.cpp`, `worker2.cpp`, `cwbase.cpp`, `cwoptim.cpp`) | `LoadStrU8(error)` | name UTF-8, system text UTF-8 | thrown text -> `WN_ERROR` -> `mainwnd.cpp:1902-2206` -> `SalMessageBox`, joined with `LoadStrU8(IDS_CLOSEDIFF)` | RIGHT AS IS (done in 102) |
| `dialogs.cpp:168-169` file does not exist | `LoadStrU8(IDS_FILEDOESNOTEXIST)` | name UTF-8 | `SalMessageBox` | RIGHT AS IS (done in 102) |
| `mainwnd.cpp:773-801` the list of differences | `LoadStrU8(IDS_CHANGEFROM* / CHANGETO* / DELETE* / ADD*)` | names UTF-8, numbers | `CB_ADDSTRING` (W) | RIGHT AS IS (done in 102) |
| `mainwnd.cpp:925-929, 2114-2121, 2224-2242`, `worker2.cpp:96-103` window titles | `LoadStrU8(IDS_MAINWNDHEADER*)` (through `ExpandPluralString` where plural) | names UTF-8, encoding labels through `LabelToU8` | `SetWindowTitleU8` / wide | RIGHT AS IS (done in 102) |
| `mainwnd.cpp:976, 991, 1036, 1951, 1960, 1966, 2002, 2022, 2202` message assembled in `message` | `LoadStrU8` | - | `SalMessageBox` (`mainwnd.cpp:2206`) | RIGHT AS IS |
| `viewwnd3.cpp:1193-1200` hex view cannot read the file | `LoadStr(IDS_ACCESFILE2)` ("Unable to access the file. ") | `FormatMessage` (A) - code page; **the file name is a separate argument** of `DialogError` | `DialogError`'s error text (`SalSetWindowTextU8`: UTF-8 when valid, else code page - `src/dialogs.cpp:1597`) | RIGHT AS IS (template and system text both code page) |
| `mainwnd.cpp:474-477` | `LoadStr(IDS_BINREPORT2)` through `ExpandPluralString` | numbers | `WM_SETTEXT` (A) | RIGHT AS IS |
| `worker2.cpp:70-74, 308-311` | `LoadStr(IDS_BINREPORT1)` through `ExpandPluralString` | numbers | `CB_ADDSTRING` (A) | RIGHT AS IS |
| `dialogs3.cpp:265-305, 453-492` encoding label | `"ASCII-8"` + `", "` + `ASCII8InputEncTableName` **or** + `LoadStr(IDS_AUTOINPUTENC / IDS_NOINPUTENC)` | never a resource text and the table name in one text | `SetDlgItemText` (A) | RIGHT AS IS (the table name is the core's text; alone with ASCII) |
| `dialogs4.cpp:101-104` font description | `LoadStr(IDS_FONTDESCRIPTION)` | size, `LogFont.lfFaceName` (`LOGFONTA`, code page) | `SetWindowText` (A) | RIGHT AS IS (the scanner's hit: the "name" is a font face) |
| `filecomp.cpp:307-313` About | `"%s " VERSINFO_VERSION ...` | two `LoadStr` + literals | `SalMessageBox` | RIGHT AS IS (all code page) |

Everything else is a text alone: captions, `SalMessageBox(LoadStr(x), LoadStr(caption))`
(`dialogs.cpp:161`, `dialogs4.cpp:38, 45`, `mainwnd.cpp:1301, 1343, 1490, 1939, 2293, 2325`,
`viewwnd3.cpp:867-877`), menu texts (`mainwnd.cpp:605-606, 1163-1164`), tooltips
(`mainwnd.cpp:1752-1767`), rebar text (`mainwnd.cpp:230`), titles `SetWindowText(HWindow,
LoadStr(IDS_PLUGINNAME))` (`mainwnd.cpp:1346, 1486, 2246, 2328`), combo and static texts
(`dialogs2.cpp:128, 290, 608`), `SetWinLibStrings` (`dlg_com.cpp:433`), `fcremote`'s
`MessageBox` calls with constants.

## 3. Fixed sites

None.

## 4. Other things seen (not changed)

- `viewwnd3.cpp:1193`: `strcpy` + `FormatMessage(..., 1024 - l)` into `char buf[1024]` - fits,
  noted only as an unbounded `strcpy` of a resource text.
- `dialogs4.cpp:101`: `sprintf(logFont.lfFaceName, LoadStr(IDS_FONTDESCRIPTION), size,
  LogFont.lfFaceName)` - the target is the 32-byte (`LF_FACESIZE`) last member of a local
  `LOGFONT`, the template is `"%d pt. %s"` (`lang/lang.rc2:72`) and the inserted face name alone
  can be 31 bytes: the text **overflows the field by up to about 10 bytes** (more with a longer
  translated template) into the stack frame, for any font whose name is longer than about 22
  characters. Old code, reachable in Configuration > File Comparator > General with such a
  font chosen. Read, not run.
- `dialogs3.cpp:251, 449`: `char buffer[200]` filled with `strcpy` / `strcat`; the table name is
  at most 100 bytes (`worker.h:56`), so it fits - only the translated resource texts are unbounded.
- `mainwnd.cpp:475`, `worker2.cpp:71, 309`: `sprintf` / `_stprintf` into `report[200]` with an
  expanded plural template (`fmt[128]`) - bounded by the template in practice, not by the call.
- `filecomp.cpp:66`: with low memory `LoadStrU8` returns the code-page text (documented there);
  the sentence is then a mix again - by design of 102.
