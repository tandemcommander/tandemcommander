# Feature 134 - work package C (dialogs): record

Files edited: `src/plugins/ftp/dialogs1.cpp`, `dialogs2.cpp`, `dialogs3.cpp`, `dialogs4.cpp`,
`dialogs5.cpp`, `dialogs8.cpp`. Not edited: `dialogs6.cpp`, `dialogs7.cpp`, `dialogs.h` (no
declaration changed; two file-local `static` helpers were added instead).

Nothing was built or run, no GUI. Read-only checks done: BOM and line endings of the six files
(UTF-8 BOM, CRLF only, no lone LF), and `python tools/check_encoding.py --strict` on the tree as
it was at that moment (`TOTAL: 0`).

Line numbers: "triage" = the number in `specs/130-plugin-mixed-templates/triage/ftp.md`;
"now" = the working tree after this package's edits.

What was read for this record: the triage's Part C and step table; in the code every site
changed, with its function, completely; `dialogs2.cpp` 40-920 completely; `dialogs3.cpp` 90-520,
610-690, 800-935, 1490-1610; `dialogs4.cpp` 700-840, 885-1000, 1290-1415, 1580-1610;
`dialogs5.cpp` 262-321, 655-725, 1280-1400; `dialogs8.cpp` 1-135, 960-1250; `dialogs1.cpp`
862-1300, 1630-1850. Rows marked "(triage, not re-read)" were NOT read again by this package.

## 1. Every row of Part C

### 1a. Compositions (table C.2)

| Row | file:line (triage -> now) | Template | Verdict | Pieces converted, sink |
|---|---|---|---|---|
| C-1 | `dialogs1.cpp:1045-1161` -> `1076-1175`, helper `AddCutToAdvancedStr` `1006-1024` | the 18 `IDS_ADVSTR*` templates + `IDS_ADVSTRNONE` | FIXED | All templates `LoadStrU8`. The five pieces with a value (proxy name, server type, target path, list command, init commands) go through the new helper: the value through `FTPTextToU8` (so the code-page `ListCommand`, a "not used" text of either encoding and a value stored by an older version join as UTF-8), `_snprintf_s(.., 38, _TRUNCATE)`, cut at byte 36 **at a whole character** (`SplU8TrimTornTail`) before `"..."`. The three number pieces get `SplU8TrimTornTail`. `GetTypeNameForUser` is taken as UTF-8 (contract; `ftp.cpp:324` already loads the suffix with `LoadStrU8`). Sink unchanged: `ti.EditLine(IDE_ADVANCEDINFO)`, wide when the whole text is valid UTF-8. `IDS_ADVSTRNONE` is `LoadStrU8` too (alone in the field; either encoding was right). Stored values are not touched - only the copies shown. |
| C-2 | `dialogs1.cpp:1708` -> `1728-1733` | `IDS_REMOVECONFIRM` | FIXED | `LoadStrU8`; `s->ItemName` through `FTPTextToU8` (UTF-8 kept; a name an older version stored in the code page converted); `_snprintf_s(_TRUNCATE)` + `SplU8TrimTornTail`. Sink `SalMessageBoxEx`. Caption untouched. |
| C-3 | `dialogs2.cpp:90` -> `90-96` | `IDS_SERVERREPLYTITLE` | FIXED | `LoadStrU8`; `SentCommand` through `FTPTextToU8` into `commandU8[300]` (the typed command is UTF-8; the secret placeholder is taken in either encoding - `fs3.cpp:761` already loads it with `LoadStrU8`); `SplU8TrimTornTail(buf)`. Sink unchanged (`SplSetWindowTitleW`, A fallback). |
| C-4 | `dialogs2.cpp:355`, `365` -> `360-362`, `372-373` | `IDS_RAWLISTSAVEERROR` | FIXED | `LoadStrU8` + `GetErrorText` (UTF-8); bounded + tail trim. Sink `SalMessageBox`. |
| C-5 | `dialogs2.cpp:1577-1592` | `IDS_LISTWND*` | RIGHT AS IT IS | numbers and core size / time texts only (triage, not re-read) |
| C-6 | `dialogs3.cpp:212`, `222` -> `221-223`, `233-234` | `IDS_SRVTYPEEXPORTERROR` | FIXED | as C-4 |
| C-7 | `dialogs3.cpp:289-290` -> `301-308` | `IDS_SRVTYPEOVERWRITE` | FIXED | `LoadStrU8`; the result of `GetTypeNameForUser` (UTF-8 by contract) through `FTPTextToU8` into `typeNameU8` (a name from an imported file may be in any encoding); bounded + tail trim. Sink `SalMessageBox`. |
| C-8 | `dialogs3.cpp:319` -> `339` | `IDS_SRVTYPEIMPORTERROR` + `LoadStr(errResID)` | FIXED (reverse rule of C-9) | the template is shared with C-9, so both are `LoadStrU8` now: `LoadStrU8(IDS_SRVTYPEIMPORTERROR)`, `LoadStrU8(errResID)` |
| C-9 | `dialogs3.cpp:322`, `332` -> `342`, `353-354` | `IDS_SRVTYPEIMPORTERROR` | FIXED | as C-4 |
| C-10a | `dialogs3.cpp:432-433` -> `454-460` | `IDS_SRVTYPEREMOVECONF` | FIXED | as C-7. Sink `SalMessageBoxEx`. |
| C-10b | `dialogs3.cpp:486` -> `513-515` | `IDS_SRVTYPENOTUNIQUE` | FIXED | `LoadStrU8`; `name + 1` is the text just read by `ti.EditLine` (UTF-8); bounded + tail trim. |
| C-10c | `dialogs3.cpp:638` | `IDS_STPAR_UNABLECOMPAUTODCOND` | RIGHT AS IT IS | both pieces code page (`LoadStr(errorResID)` or `errBuf` from `parser3.cpp` - not followed, as in the triage). Read here: the composition line only. |
| C-10d | `dialogs3.cpp:675`, `1602` | `IDS_STPAR_UNABLECOMPPARSER` | RIGHT AS IT IS | template + `LoadStr(errorResID)`, both code page (read) |
| C-10e | `dialogs3.cpp:1502` | `IDS_SRVTYPECOL_REMOVECONF` | RIGHT AS IT IS | column ID is ASCII (triage's inference, not re-read) |
| C-10f | `dialogs4.cpp:984`, `996` -> `984-986`, `998-999` | `IDS_SRVTYPE_READRAWLISTERR` | FIXED | as C-4 |
| C-10 | `dialogs5.cpp:285-290`, `688-696` -> `276-301`, `694-711` | `IDS_OPERDLGTITLE_ERRORS / _DONE / _STOPPED / _WAITING / _PAUSED` + `TitleText` | FIXED (this file's half) | See section 1c. |
| C-11 | `dialogs5.cpp:417`, `434-455`, `513-616`; `dialogs6.cpp:381`, `714` | status texts | RIGHT AS IT IS | numbers only (triage; the `LoadStr` lines of `dialogs5.cpp` and `dialogs6.cpp` were listed again by a search, not read line by line) |
| C-11b | `dialogs7.cpp:598-601` | none | RIGHT AS IT IS | ASCII (triage, not re-read) |
| C-12 | `dialogs8.cpp:1028` -> `1028-1041` | `IDS_RENAMESRVTO` | FIXED | `LoadStrU8`; `Name` through `FTPTextToU8`; bounded + tail trim. Sink unchanged (`SetDlgItemTextW`, A fallback). |
| C-13 | `dialogs8.cpp:1043-1047` -> `1047-1067` | `IDS_COPYDATAFROM` / `IDS_SRVTYPECOPYFROM`, `IDS_QUICKCONNECT` | FIXED | Both templates and `IDS_QUICKCONNECT` `LoadStrU8`. The name (bookmark name, or `CopyFromName` = `GetTypeNameForUser`, UTF-8) through `FTPTextToU8`. **The 100-byte cut of the name is gone**: it could tear a character, cut the suffix of a long type name, and `DuplicateAmpersands` drops the last byte when the buffer is full (`src/salamdr3.cpp:1530-1536`); the name and the text now have buffers that take the whole name with every `&` doubled (`checkboxName`, `text`). Sink unchanged. Visible change in English: a server-type name longer than about 85 bytes shows its whole suffix. |
| C-14 | `dialogs1.cpp:2198-2213` | `IDS_PASSWORDIS` | RIGHT AS IT IS | wide (feature 116), not touched |

### 1b. Sinks (table C.1) - the rows with a verdict other than "RIGHT AS IT IS" in the triage, and the contract rows

| Sink | file:line (triage -> now) | Verdict | What was done |
|---|---|---|---|
| CConnectDlg: address written back on OK (Quick Connect) | `dialogs1.cpp:970` -> `970-981` | FIXED | See section 1d. |
| CConnectDlg: advanced summary | `dialogs1.cpp:1161` | FIXED | row C-1 |
| CRenameDlg: subject, check box | `dialogs8.cpp:1029-1036`, `1048-1055` | FIXED | rows C-12, C-13 (sinks were wide already) |
| CEnterStrDlg `IDT_CONNECTINGTOAS` | `dialogs8.cpp:1120` -> `1147-1148`, helper `FTPSetDlgItemTextU8` `1083-1097` | FIXED (sink) | wide: `SplDisplayTextToWAlloc` + `SetDlgItemTextW` (valid UTF-8 as UTF-8, else code page), `SetDlgItemTextA` only on low memory. The five composing lines are in `ctrlcon1.cpp` (package A) and use `LoadStrU8` already (`ctrlcon1.cpp:863`, `1438`, `1460`, `1481`, `1504`, as seen by a search at the end of this work). |
| CLoginErrorDlg `IDE_SERVERREPLY` | `dialogs8.cpp:1218` -> `1246-1251` | FIXED (sink) | the same helper: a reply (or a worker's error text, or a `GetProxyError` text - UTF-8 by contract) that is valid UTF-8 is shown wide, anything else through the code page as before. A NULL reply keeps the old call. |
| CLoginErrorDlg `IDT_CONNECTINGTO` | `dialogs8.cpp:1220` -> `1252-1253` | FIXED (sink) | the same helper. Callers: `ctrlcon1.cpp` (package A, `LoadStrU8` at `1694`) and `dialogs5.cpp:1384` (`LoadStr(IDS_SOLVEERRSUBJECT)` alone - code page, shown through the code page by the helper; left). |
| CEnterStrDlg title / `IDT_STRING`; CLoginErrorDlg title, `IDC_RETRYWITHOUTASK`, `IDT_ERRORTITLE` | `dialogs8.cpp:1116`, `1118`, `1216`, `1222`, `1224` | RIGHT AS IT IS | plain resource texts from the callers, A calls kept. If a caller of another package starts to pass a UTF-8 text here, these are code page only - see section 4. |
| CLogsDlg: reader of the Logs combo | `dialogs2.cpp:688-690` -> `692-706` | FIXED | read wide (`CB_GETLBTEXTLEN` / `CB_GETLBTEXT` through `SendMessageW`), converted to UTF-8 (`SplWToU8`) into `buf[3 * LOGSCOMBOITEM_MAX_SIZE]`. The text is the `itemName` of `CLogs::SaveLog / CopyLog / ClearLog / RemoveLog`; two of them print it into a question (`ctrlcon2.cpp`, `IDS_CLEARLOGQUESTION`, `IDS_REMOVELOGQUESTION`), so bytes are needed and they are UTF-8. The guard of feature 131 is kept, now in units: an item of `LOGSCOMBOITEM_MAX_SIZE` units or more is not acted on; a shorter one always fits three times as many bytes. |
| CConfigPageServers list: re-insert on Move Up / Down | `dialogs3.cpp:131` -> `130-141` | FIXED | `SplDisplayTextToWAlloc` + `LB_INSERTSTRING` through `SendMessageW`; A message on low memory. (The filling of the list is `ftp3.cpp`, package B.) |
| CEditServerTypeDlg: "empty value" cell | `dialogs3.cpp:895` -> `923-936` | FIXED | that one cell wide (`LVM_SETITEMTEXTW`, `SplDisplayTextToWAlloc`: a typed value is UTF-8, the standard text of a type from `GetColumnEmptyValueForType` is code page). The other cells stay A (code-page values). |
| CWelcomeMsgDlg title | `dialogs2.cpp:91-98` | FIXED | row C-3 |
| COperationDlg title | `dialogs5.cpp:296-313` | FIXED | row C-10 |
| CCopyMoveDlg / CConfirmDeleteDlg / CChangeAttrsDlg subject | `dialogs4.cpp:1361-1368`, `1400-1407`, `1596-1603` -> `1364-1371`, `1403-1410`, `1599-1606` | RIGHT AS IT IS | verified by reading: `SplU8ToWAlloc(Subject)` -> `SetDlgItemTextW`, A call only when the text is not valid UTF-8. A subject that is UTF-8 as a whole is shown as UTF-8. Not changed. (A subject cut inside a character by its composer would fall back to the code page - the composer, package B, must trim.) |
| CConnectAdvancedDlg `IDC_SERVERTYPE`, `IDC_PROXYSERVER` combos | `ftp3.cpp`, `ftp2.cpp` | not this package | the filling is in package B's files; no reader of an item text exists in `dialogs*.cpp` (searched for `GETLBTEXT`, `LB_GETTEXT`, `FINDSTRING`, `SELECTSTRING`: only the Logs combo) |
| all other rows of C.1 | - | RIGHT AS IT IS | as the triage says; not re-read except where they lie in the ranges listed at the top |

### 1c. The operation window title (`dialogs5.cpp`) - the decision

- `SetDlgTitle` (`dialogs5.cpp:276-301`): the state word passes through `FTPTextToU8` into
  `stateU8[200]` before it joins `TitleText`; `SplU8TrimTornTail(txt)` after both `_TRUNCATE`
  compositions. `FTPTextToU8` keeps a UTF-8 word and converts a code-page one, so the third
  caller - the size text of the core's `PrintDiskSize` (`dialogs5.cpp:672-674`, encoding of its
  unit word not read) - is right either way.
- `UpdateDataInDialog` (`dialogs5.cpp:694-711`): the triage is right, a second load is needed.
  The core's progress bar draws its text with `GetTextExtentPoint32A` / `ExtTextOutA`
  (`src/gui.cpp:244`, `261`, `269` - read), so it must keep the code-page text. The three
  nested `SetDlgTitle(-1, (progressTxt = LoadStr(..)))` were replaced by: choose `stateResID`,
  `SetDlgTitle(-1, LoadStrU8(stateResID))`, `const char* progressTxt = LoadStr(stateResID)`.
  Same texts, same order of the two sinks.
- `TitleText` itself is composed in `operats2.cpp:680` (package D); it is right only when D
  loads its template with `LoadStrU8` and the core's subject is UTF-8 (both are the brief's
  contract). `TitleText` is not converted here: it is also compared with the stored title on
  every update.
- The fallback when the whole title is not valid UTF-8 (the A compare and `SetWindowTextA`)
  is unchanged.

### 1d. Quick Connect address (`dialogs1.cpp:970`) - what was stored, what is stored

Code read completely: `CConnectDlg::Transfer` (`dialogs1.cpp:921-992`), `HistoryComboBox`
(`dialogs8.cpp:9-132`), the `CBN_KILLFOCUS` handler that fills `LastRawHostAddress`
(`dialogs1.cpp:1755-1867` now, the read at `1761`), `ConnectFieldFits` (`882-915`).

- `LastRawHostAddress` is the text of the address field read **wide and converted to UTF-8**
  by `ti.EditLine` when the field loses focus - the text as typed, password included.
- On OK / Close with Quick Connect selected (`ti.IsGood() && ttDataFromWindow &&
  Config.LastBookmark == 0`): a copy without the password (`FTPStripAddressPassword`, feature
  085) is written back into the field, and the following `HistoryComboBox` reads the field
  **wide**, converts to UTF-8 and - Quick Connect only - puts that text at the head of
  `Config.HostAddressHistory` (saved to the registry with the configuration).
- **Before**: the copy was written with `SetWindowTextA`. Windows read its UTF-8 bytes as
  code-page text. For a typed `ftp://jiří@server/přílohy` the field then held, on code page
  1250, `ftp://jiĹ™Ă­@server/pĹ™Ă­lohy`; that text, as UTF-8, is what went into the history
  (each accented letter stored as two wrong characters, 4-5 bytes instead of 2). Two further
  effects of the same line: a long address could grow past `HOST_MAX_SIZE` and was then
  refused with the "name too long" message on OK although the typed text fitted; and bytes that
  the code page does not define (0x81, 0x83, 0x88, 0x90, 0x98 on 1250) became control
  characters. An ASCII address was stored unchanged.
- **Now**: the copy is written wide (`SplU8ToWAlloc` + `SendMessageW(WM_SETTEXT)`, the same
  call `HistoryComboBox` uses for this control), so the field holds the typed text and the
  history gets **the typed text without the password**, byte for byte the content of
  `LastRawHostAddress` after the strip. The A call remains only when the text is not valid
  UTF-8 (cannot come from `EditLine`) or memory is low.
- Unchanged: when it is stored (Quick Connect only), the password strip, the format (UTF-8),
  the place. Entries that an earlier version stored garbled stay in the history as they are -
  nothing repairs them.
- Not measured (no build): the mojibake itself is a conclusion from the A call.

## 2. Sites the triage does not have

| file:line (now) | What | Verdict |
|---|---|---|
| `dialogs5.cpp:1384` | `CLoginErrorDlg(.., errBuf, .., LoadStr(IDS_SOLVEERRSUBJECT), ..)`: the worker's error text (`WorkersList->GetErrorDescr`, package D's content) goes to `IDE_SERVERREPLY` | covered by the wide sink of `dialogs8.cpp:1246-1251`; no composition here |
| `dialogs8.cpp:1617` | `SalMessageBox(errDescr)` - the text of `ProcessProxyScript` (`ftp2.cpp`, package B) | RECORDED: no composition in this file; right when B's text is one encoding |
| `dialogs7.cpp:189` | `FTPGetErrorText` alone into `ti.EditLine` | RIGHT AS IT IS (code page alone; the triage has it inside a C.1 row) |
| `dialogs6.cpp:580`, `718` | `TitleText` as a message-box caption | not touched (caption); it is UTF-8 when package D makes it so, and the core shows a caption either way (brief) |

## 3. How a person reaches the easiest FIXED rows

No server is needed for the first four. Language: Czech (the templates have accented letters).

1. **C-2 Remove** - plug-in menu *Connect to FTP Server*, a bookmark named `Žluťoučký kůň`,
   button *Remove*: the question `Opravdu chcete odstranit záložku "Žluťoučký kůň"?` - message
   box text. Before: the name garbled.
2. **C-12 Rename** - the same bookmark, *Rename*: the static text `IDT_SUBJECT` above the edit
   line (`Přejmenovat "Žluťoučký kůň" na`), readable with `GetWindowTextW` of the control.
3. **C-13 New** - the same bookmark focused, *New*: the text of the check box
   `IDC_COPYFOCUSEDSRV` (`&Kopírovat data ze záložky "Žluťoučký kůň"`). With *Quick Connect*
   focused the same check box shows the Quick Connect text (the reverse-rule piece).
4. **C-1 Advanced summary** - a bookmark whose *Advanced* settings have a target panel path
   with an accented folder (e.g. `C:\Přílohy`); select the bookmark: the read-only field
   `IDE_ADVANCEDINFO`. English variant (the torn character): a target path whose text
   `Target path: ...` reaches byte 36 inside an accented letter - before, the whole line was
   shown through the code page; now the letter is left out before `...`.
5. **Quick Connect address** (English too) - *Quick Connect*, address
   `ftp://jiří@127.0.0.1/přílohy`, leave the field (Tab), press *Close* (the comment at
   `dialogs1.cpp:949` says the transfer from the window runs for Connect and for Close; the
   Close handler itself was not read - if Close does not store, use Connect against the test
   server); open the dialog again and read the
   address field / the first item of its drop-down, or the registry value of the address
   history. The server is not involved.
6. With the test server: **password prompt** (English too) - connect as user `jiří` with no
   stored password: `IDT_CONNECTINGTOAS` of the prompt. The server only has to answer `331`
   to `USER`. **Send FTP Command** (C-3): `MKD žluťoučký` answered with any `257` - the title
   of the reply window. **Login error reply**: `530` with a UTF-8 text to `PASS` -
   `IDE_SERVERREPLY` of the login error dialog; with a code-page-1250 text the same field must
   read as before.
7. **Operation title** (C-10): copy one file with an accented name; title while it runs
   (`(12 %) ...`) and at the end (`(Hotovo) ...`), `InternalGetWindowText` of the window.
   Needs package D's template and the core's UTF-8 subject.

## 4. Needed from other packages, and what may not compile

Needed (nothing blocks the compile; these decide whether the row is right on the screen):

- **Package A**: nothing new. `CLogs::AddLogsToCombo` adds the items wide already
  (`ctrlcon2.cpp:1562-1573` as seen at the end). The item `IDS_NOLOGS` is added with the A
  message (`ctrlcon2.cpp:1583`) - fine, the menu commands are disabled then. Note for A:
  `CLogs::ClearLog` / `RemoveLog` now receive the item name as **UTF-8** (`dialogs2.cpp:692-706`),
  so their two questions need `LoadStrU8` templates if they do not have them yet.
- **Package B**: `GetTypeNameForUser` UTF-8 (the suffix is `LoadStrU8` at `ftp.cpp:324` already).
  A subject handed to the three confirmation dialogs must be trimmed at a whole character by
  its composer (`fs4.cpp`, `fs5.cpp`): the sinks fall back to the code page for a text with a
  torn tail.
- **Package D**: `operats2.cpp:680` (`TitleText`) with a `LoadStrU8` template - without it the
  operation title stays mixed whatever `dialogs5.cpp` does.
- **Any caller** of `CEnterStrDlg` (title, text) and `CLoginErrorDlg` (title, retry text,
  error title): these five sinks are still code page only; they must keep receiving `LoadStr`
  texts. Only `ConnectingToAs`, `ConnectingTo` and `ServerReply` take UTF-8.

Not sure it compiles (not built) - the places to look at first:

- `dialogs1.cpp:1016`: `_snprintf_s(piece, 38, _TRUNCATE, format, valueU8)` with a
  non-literal `format` parameter (same form as the lines it replaces, but now inside a
  `static` helper taking `const char* format`).
- `dialogs2.cpp:696-704`: `WCHAR bufW[LOGSCOMBOITEM_MAX_SIZE]`, `SplWToU8(bufW, buf, sizeof(buf))`
  (a `size_t` constant to an `int` parameter - the same form is used in `ftputils.h:148`).
- `dialogs8.cpp:1052-1058`: `const int nameU8Size`, `sizeof(checkboxName)` passed to
  `DuplicateAmpersands(char*, int)`, a local named `text`.
- `dialogs3.cpp:926-934`: `LVITEMW lviW` with only `iSubItem` and `pszText` set, sent with
  `LVM_SETITEMTEXTW` (copied from the existing `dialogs4.cpp:822-830`).
- `dialogs5.cpp:697-711`: `stateResID` is assigned on every path (three branches).
- `LoadStrU8` results are only passed as format or `%s` arguments or to `const char*`
  parameters (`AddToAdvancedStr`, `SetDlgTitle`, `lstrcpyn` source); none is modified. The one
  `char* str` that received them (`dialogs1.cpp`, transfer mode) is `const char*` now.

Behaviour to check in the review / probe rather than in the compile:

- `FTPTextToU8` is applied to names (bookmark, server type, advanced values). A name cut
  inside a character by an earlier `lstrcpyn` (`dialogs1.cpp:1670` now, into 101 bytes) is not
  valid UTF-8 and is then read through the code page - garbled as before, not worse.
- `SetDlgTitle` now allocates (through `FTPTextToU8`) on each update that has a state text;
  the percent path does not.
- `SplDisplayTextToWAlloc` on a code-page text that happens to be valid UTF-8 shows it as
  UTF-8 - the same rule as every other "wide when valid UTF-8" sink of the plug-in.

## 5. Other defects seen and left

- `dialogs1.cpp:1670` (was 1650): `lstrcpyn(name, s->ItemName, BOOKMARKNAME_MAX_SIZE)` - a
  stored bookmark name longer than 100 bytes is cut, possibly inside a character, and the cut
  name is the default of Rename / Copy To.
- `ftp2.cpp:2959` (package B's file): `GetProxyName` copies the proxy name with `lstrcpyn` into
  `PROXYSRVNAME_MAX_SIZE` (101) bytes while the proxy dialog accepts a longer name - a cut
  inside a character makes that piece of the advanced summary code page.
- `AddToAdvancedStr` (`dialogs1.cpp:994-1004`): when a piece does not fit the 300 bytes it is
  left out, but the `", "` before it stays.
- Unbounded `sprintf` left (not on a line this feature changes): `dialogs3.cpp:638` now `667`
  (`buf[300]`, `errBuf[200]` + a translated template), `675`/`1602` now `704`/`1643`,
  `1502` now `1543`; `dialogs6.cpp:714`.
- `dialogs3.cpp:156-158`: the export file name is made from the type name with
  `lstrcpyn(.., MAX_PATH - 4)` - a cut inside a character for a very long name.
- `dialogs8.cpp:618`, `625` and `dialogs4.cpp:176-187`: A reads (best fit) of the list command
  and of the column name / description - values that are stored or sent (triage list 3).
- `dialogs3.cpp:1585` now `1626`: `GetDlgItemText` A of the parsing rules for *Test Parser*
  while *Validate* reads them as UTF-8.
- `dialogs4.cpp:567`, `589`, `971`: the raw listing of the parser test goes through A calls
  both ways.
- Byte offsets used as character positions for `EM_SETSEL` (`dialogs8.cpp:1620`,
  `dialogs3.cpp:643` / `679` / `1606` in the triage's numbering, `dialogs4.cpp:883-885`).
- `dialogs2.cpp:287-291`, `dialogs3.cpp:149-158`, `dialogs4.cpp:893-897`: `MAX_PATH` byte
  buffers for the UTF-8 paths of the file dialogs.
- The history entries garbled by the old `dialogs1.cpp:970` stay in the registry; no clean-up
  was added (it would change stored data beyond FR-002).
