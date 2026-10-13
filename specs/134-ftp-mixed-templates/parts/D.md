# Feature 134 - work package D: operations, queue, workers

Files: `src/plugins/ftp/operats1.cpp` ... `operatsb.cpp`, `operats.h`. Written 2026-10-13.
**Nothing was built or run**; every changed line was read again, none was compiled. Edited:
`operats1.cpp`, `operats2.cpp`, `operats3.cpp`, `operats4.cpp`, `operats6.cpp`, `operats7.cpp`,
`operats8.cpp`, `operatsa.cpp`, `operatsb.cpp`. Not edited: `operats5.cpp`, `operats9.cpp`,
`operats.h` (no declaration changed, no new shared helper).

Line numbers in the tables are **today's of the triage** (before this change); the changed code
is a few lines lower now.

## 0. Facts measured by reading (the triage left them open)

| Thing | Encoding | Evidence |
|---|---|---|
| `SalamanderGeneral->NumberToStr` | **UTF-8** - digits and the thousands separator of the locale, which the core keeps as UTF-8 (Czech: a no-break space, `C2 A0`) | `src/salamdr1.cpp:2955-2970`, `998-1009`, `src/consts.h:1733-1739` |
| `SalamanderGeneral->PrintDiskSize(buf, size, 0)` (plug-ins get `u8 = FALSE`) | number ASCII with the decimal separator in **UTF-8**, the unit (`IDS_SIZE_*`) in the **code page** | `src/zip.cpp:1453-1456`, `src/salamdr6.cpp:416-536` (`loadStr = u8 ? LoadStrU8 : LoadStr`) |
| `PrintDiskSize(buf, size, 2)` ("1 234 bytes") | the plural word in the **code page** around `NumberToStr` = **UTF-8** separator: **mixed in itself** wherever the separator is not ASCII and the word has an accented letter (Czech) | `src/salamdr6.cpp:426-432` |
| `SalamanderGeneral->PrintTimeLeft` | **code page** (`ProgDlgHoursStr` etc. are `DupStr(LoadStr(...))`) | `src/salamdr6.cpp:543-577`, `src/salamdr1.cpp:924-926` |
| `GetProxyTypeName` | `LoadStr` = code page today (package B's file) | `ftp2.cpp:2168-2199` |
| `GetCommonFSOperSourceDescr` | UTF-8 as a whole (both branches) | `src/zip.cpp:4030-4051` |
| `GetDateFormat` / `GetTimeFormat` (A) | code page | `operats2.cpp:373-377`, `operats6.cpp:750-754` |
| `GetProblemDescr` - callers | only `operats1.cpp:1346`, `1353`, `1364` | grep of the plug-in |
| `CFTPWorker::ErrorDescr` - readers | the status cell (`operats3.cpp:509-518`), `GetErrorDescr` (`operats3.cpp:737` -> `dialogs5.cpp:1285` -> `CLoginErrorDlg`, `dialogs8.cpp:1218`), the log (`operats7.cpp:221`, `operatsb.cpp:1702`) | grep of the plug-in |
| `GetWorkerErrorTxt` (`operats3.cpp:7-15`) | unchanged: `FTPGetErrorText` or `LoadStr(IDS_UNKNOWNERROR)` = code page; all callers are in `operats3.cpp` / `operats6.cpp` | - |

## 1. Every row of part D of the triage

Sinks: **LV-O** = Operations list of the operation window (`dialogs6.cpp:786-813`, per cell: wide
when the cell is valid UTF-8, else A), **LV-C** = Connections list (`dialogs6.cpp:865-889`, same
rule), **LOG** = `Logs.LogMessage` (package A: every message made UTF-8 on its own).

| # | file:line (triage) | template id | verdict | pieces converted / sink |
|---|---|---|---|---|
| 1 | operats1.cpp:1164, 1170, 1176, 1182, 1188, 1196, 1265, 1271, 1321 | `IDS_OPERDOPDS_DELLINK`, `_DELFILE`, `_DELDIR`, `_DELEXPLDIR`, `_CHATTREXPLDIR`, `_RESLINK`, `_MOVEDELDIR`, `_MOVEDELDIRLNK`, `_CHATTREXPLDIRLNK` | **FIXED** | `LoadStrU8`; names and paths are UTF-8 already; one `SplU8TrimTornTail(buf)` after the `switch` of the description column covers all 18 sites. Sink LV-O + tool tip |
| 2 | operats1.cpp:1205-1232 | `IDS_OPERDOPDS_COPY1/MOVE1/COPY2/MOVE2`, `_ASCIITRMODE/_BINARYTRMODE`, `_SIZEINBLOCKS` | **FIXED** | all three `LoadStrU8`; the size text: `PrintDiskSize` into a local buffer and through `FTPTextToU8` (unit in the code page), `NumberToStr` is UTF-8 as it is; the `strcpy`/`strcat` chain into `size[110]` is now a bounded `_snprintf_s` + tail trim. LV-O |
| 3 | operats1.cpp:1239-1258 | same ids (upload) | **FIXED** | as row 2 (`PrintDiskSize` through `FTPTextToU8`). LV-O |
| 4 | operats1.cpp:1278, 1287, 1295 | `IDS_OPERDOPDS_COPYEXPLDIR`, `_MOVEEXPLDIR`, `_MOVEEXPLDIRLNK` | **FIXED** | `LoadStrU8`. LV-O |
| 5 | operats1.cpp:1303-1306, 1312-1315 | `IDS_OPERDOPDS_CHATTRFILE`, `_CHATTRDIR` | **FIXED** | `LoadStrU8`; `unixRights` is ASCII (digits + `GetUNIXRightsStr`, not re-read - taken from the triage). LV-O |
| 6 | operats1.cpp:1346-1347, 1353-1354, 1364-1365 (G2) | `IDS_OPERDLGOPSTS_SKIPPED`, `_FAILED`, `_WAITUSER` | **FIXED** (the triage: right as it is) | `LoadStrU8` + tail trim; `reason` is UTF-8 now (rows 7-11). Reason for the change: the reason may end with a server reply that quotes a name in UTF-8 - with a code-page template the cell was neither encoding and the reply was garbled. LV-O. The five plain state texts (1341, 1359, 1370, 1373, 1376) stay `LoadStr` (a cell of their own, resource text only) |
| 7 | operats2.cpp:2161-2200 (G3) | `IDS_OPERDOPPR_CANTCRTGTFILE` ... `_UPLCANTDELSRCDISKFILE`, `IDS_UNKNOWNERROR` | **FIXED** (as a function) | `GetProblemDescr` gives **UTF-8**: the text built by the `switch` (resource text + `FTPGetErrorText`, all code page, loaded with `LoadStr` as before) is converted once at the end of the `switch` (`SplLegacyToU8Alloc` + `SplU8CopyTrunc`); no template of this row was touched |
| 8 | operats2.cpp:2277-2285 (G3) | `IDS_OPERDOPPR_LISTENFAILURE` | **FIXED** (as row 7) | - |
| 9 | operats2.cpp:2304-2322 (G3) | `IDS_OPERDOPPR_INCOMPLLISTING1` ... | **FIXED** (as row 7) | - |
| 10 | operats2.cpp:2222-2244 (G4) | `IDS_OPERDOPPR_UNKNOWNATTRS`, `_UNKEXISTATTR` | **FIXED** | both `LoadStrU8` (`OrigRights` is a listing column = UTF-8); the conversion of row 7 keeps a valid UTF-8 text |
| 11 | operats2.cpp:2259 ... 2420 + the append 2458-2468 (G5) | `IDS_OPERDOPPR_UNABLETOCWD` ... `_UPLCANTCRTGTFILE` | **FIXED** | the template half as row 7; the first line of `ErrAllocDescr` (a server reply / a resource text / the proxy error text, UTF-8 after package A) is copied to a local buffer, made UTF-8 with `FTPTextToU8` and appended with `SplU8CopyTrunc`. The reply itself (`ErrAllocDescr`) is not changed |
| 12 | operats1.cpp:1656-2002 (G6) | none composed | **RIGHT AS IT IS** | one piece per field of the Solve Error dialogs (`ti.EditLine`: UTF-8 or code page); the proxy text being UTF-8 now is fine there |
| 13 | operats3.cpp:455 (G7) | `IDS_OPERDLGCOACT_DELFILE`, `_COPY`, `_MOVE`, `_CHATTR`, `_DELLINK`, `_DELDIR`, `_EXPLDIR`, `_RESLINK` | **FIXED** | `LoadStrU8(strResID)` + tail trim. LV-C column Action + tool tip |
| 14 | operats3.cpp:509-511, 518 (G8) | `IDS_OPERDLGCOACT_WAITRECON`, `_CONERROR` | **FIXED** (the triage: right as it is) | `LoadStrU8`; `ErrorDescr` through the new static `WorkerErrDescrToU8` (`operats3.cpp`, top: a text that fills the 200-byte buffer gets its torn end dropped, then `FTPTextToU8`); tail trim. LV-C column Status |
| 15 | operats3.cpp:531-670 (G8) | `IDS_OPERDLGCOACT_PAUSED`, `_WAITFORLIST`, `IDS_LISTWNDDOWNLOADSPEED`, `IDS_LISTWNDCONNECTIONIDLE`, `IDS_LISTWNDSTATUS1/2`, `IDS_OPERDLGSTATUS2`, `IDS_OPERDLGCOACT_TIMELEFT`, `IDS_OPERDLGCONNECTIONSIDLE` | **RIGHT AS IT IS** | code-page templates + `PrintDiskSize` mode 0 (code-page unit) + `PrintTimeLeft` (code page) + numbers; never a name. Only where the locale's **decimal** separator is not ASCII the core's size text is mixed in itself (see "other defects" 1) |
| 16 | operats3.cpp:2245 (G9) | `IDS_WORKEROPENCONERR` | **FIXED** | `LoadStrU8`; `errBuf` (the proxy error text = UTF-8 by the contract, or `GetWorkerErrorTxt` = code page) through `FTPTextToU8`; tail trim. -> `ErrorDescr` |
| 17 | operats3.cpp:2225-2226; operats6.cpp:671-672, 787-788 (G9) | `IDS_WORKERGETIPERROR`, `IDS_WORKEROPENCONERR` | **RIGHT AS IT IS** | code-page template + `GetWorkerErrorTxt` (code page); the whole `ErrorDescr` is made UTF-8 where it is shown (row 14) |
| 18 | operats7.cpp:72-83; operatsb.cpp:1557-1568 (G9) | `IDS_PROXYERRUNABLETOCON2`, `IDS_PROXYERRUNABLETOCON`, `IDS_LOGMSGDATCONERROR` | **RIGHT AS IT IS** | all code page (`FTPGetErrorText`); to `ErrorDescr` and to the LOG as one code-page message |
| 19 | operats7.cpp:176-179, 207-210, 221-222; operatsb.cpp:1658-1661, 1688-1691, 1702-1703 (G9) | `IDS_LOGMSGDATCONERROR` (+ plain `IDS_PROXYERROPENACTDATA`, `IDS_PREPACTDATACONTIMEOUT`) | **FIXED** (4 sites: operats7.cpp:179, 210; operatsb.cpp:1661, 1691) | `LoadStrU8`; the text of `GetProxyError` (UTF-8 after package A) / `GetProxyTimeoutDescr` through `FTPTextToU8`; tail trim. -> `ErrorDescr` -> LV-C and `"%s\r\n"` to the LOG (cannot be cut: 200 bytes into 351). The two plain branches stay `LoadStr` |
| 20 | operats3.cpp:2402-2406 (G9) | `IDS_LOGMSGDATCONERROR` | **FIXED** | the unbounded `sprintf` into `errBuf[300]` is `_snprintf_s(_TRUNCATE)`; `LoadStrU8`; the timeout text through `FTPTextToU8`; after a cut `FTPLogMsgCutKeepLineEnd`. LOG |
| 21 | operats6.cpp:889-890, 1219-1220; 982-983; 1191-1192 (G10) | `IDS_NOTFTPSERVERERROR`, `IDS_INCOMPLETEPRXSCR3`, `IDS_WORKERLOGINERR` | **FIXED** (the triage: right as it is (reply)) | `LoadStrU8`; the reply (`CopyStr` into `errBuf` as before) through `FTPTextToU8` into a local buffer; tail trim before `CorrectErrorDescr`. -> `ErrorDescr` (UTF-8 as a whole). The bare replies (operats6.cpp:873-874, operats3.cpp:2204) are stored as they came and made UTF-8 where shown (row 14) |
| 22 | operats6.cpp:998-1001 (G11) | `IDS_ERRINPROXYSCRIPT` | **FIXED** | `LoadStrU8`; `errDescrBuf` (a text of `ProcessProxyScript`, package B's file - either encoding) through `FTPTextToU8`; tail trim. The bare branch (`needUserInput`) is unchanged |
| 23 | operats6.cpp:1064-1067 (G11) | `LoadStr(errID)` of `EncryptSocket` | **FIXED** | `LoadStrU8(errID)`; the text of `EncryptSocket` (package A's file - either encoding) through `FTPTextToU8`; tail trim. The no-text branch (1065) stays `LoadStr` |
| 24 | operats2.cpp:367-369 (G12) | the six `IDS_OPERDLG*TITLE` | **FIXED** | `LoadStrU8`; `OperationSubject` is the core's UTF-8 text; `Host` through `FTPTextToU8` (typed = UTF-8, or a code-page value of an older version); tail trim before the `"\r\n"` is added. LOG |
| 25 | operats2.cpp:371-379 (G12) | `IDS_WORKERLOGHEADER` | **FIXED** | `LoadStrU8`; host as above; `timeBuf` (`GetDateFormat` / `GetTimeFormat` A) through `FTPTextToU8`; the unbounded `sprintf` into `buf[500]` is `_snprintf_s(_TRUNCATE)`; after a cut `FTPLogMsgCutKeepLineEnd`. LOG |
| 26 | operats2.cpp:679-681 (G13) | the six `IDS_OPERDLG*TITLE` | **FIXED** | `LoadStrU8`; subject UTF-8, host through `FTPTextToU8`; tail trim. Sink `dlg->TitleText` -> `COperationDlg::SetDlgTitle` (UTF-8 -> `SplSetWindowTitleW`), also a message-box caption (`dialogs6.cpp:580`, `718`) |
| 27 | operats2.cpp:775-779, 791-794 (G14) | `IDS_PRXSRVRECONLOGHEADER`, `IDS_PRXSRVWORKERCONLOGHDR` | **FIXED** | `LoadStrU8`; `Host`, `User`, `ProxyName`, `ProxyHost`, `ProxyUser`, `ConnectToHost`, `GetProxyTypeName(...)` and `dateTime` each through `FTPTextToU8`; after a cut `FTPLogMsgCutKeepLineEnd`. LOG (`operats6.cpp:743-744`, `755-756` - unchanged) |
| 28 | operats2.cpp:783-784, 798 (G14) | `IDS_RECONLOGHEADER`, `IDS_WORKERCONLOGHDR` | **FIXED** | as row 27 (`ConnectToHost`, `dateTime`). LOG |
| 29 | operats4.cpp:34-37 (G15) | `IDS_LOGMSGEXPLORINGDIR` | **FIXED** | `LoadStrU8`; after a cut `FTPLogMsgCutKeepLineEnd`. LOG |
| 30 | operats4.cpp:311-312; operatsa.cpp:125-126; operatsb.cpp:326-327 (G15) | `IDS_LOGMSGRESOLVINGLINK` | **FIXED** | as row 29 |
| 31 | operats4.cpp:520-558 (G15) | `IDS_LOGMSGDELETELINK`, `_DELETEFILE`, `_DELETEDIR`, `_DOWNLOADFILE`, `_DOWNLOADFILE2`, `_DELETEDIRLINK`, `_CHATTRSFILE`, `_CHATTRSDIR` | **FIXED** | `LoadStrU8(opDescrResID)`; as row 29 |
| 32 | operats7.cpp:496-497 (G15) | `IDS_LOGMSGLISTINGPATH` | **FIXED** | as row 29 |
| 33 | operats8.cpp:764-765 (G15) | `IDS_LOGMSGDWNLOADFORCRESUM` | **FIXED** | as row 29 |
| 34 | operatsa.cpp:209-210, 534-535 (G15) | `IDS_LOGMSGCREATEDIR` | **FIXED** | as row 29 |
| 35 | operatsb.cpp:213-214 (G15) | `IDS_LOGMSGUPLOADFILE` | **FIXED** | as row 29 |
| 36 | operatsb.cpp:1139-1144 (G15) | `IDS_LOGMSGUPLOADISCOMPL`, `_ISCOMPL2`, `_ISNOTCOMPL`, `_ISNOTCOMPL2` | **FIXED**, one piece **RECORDED** | `LoadStrU8`; `PrintDiskSize(..., 2)` through `FTPTextToU8`. RECORDED: in a locale whose thousands separator is not ASCII and whose word for "bytes" has an accented letter (Czech) the core's text is mixed in itself; it is then read as code page and the separator shows as two wrong characters (as before the change) - the sentence and the name are right. Cannot be repaired in the plug-in |
| 37 | operatsb.cpp:1787-1788 (G15) | `IDS_LOGMSGUPLOADRENFILE` | **FIXED** | as row 29 |
| 38 | operats7.cpp:1313-1316 (G16) | `IDS_LOGMSGPARSEDBYSRVTYPE` | **FIXED** | `LoadStrU8`; the type name through `FTPTextToU8`; after a cut `FTPLogMsgCutKeepLineEnd`. LOG |

Counts by row: **FIXED 34** (one of them with a RECORDED piece), **RIGHT AS IT IS 4** (12, 15,
17, 18), **RECORDED 0 whole rows**, **TRIAGE WRONG 1** (below; not a table row).
By site: 18 description sites, 3 state sites + `GetProblemDescr`, 1 action, 2 worker status,
11 `ErrorDescr` compositions, 2 title / header lines, 1 worker log header, 4 connect headers,
14 composed log messages (12 of G15, G16, operats3.cpp:2405).

Triage statements that did not hold:

- **TRIAGE WRONG** - "other defects" 1 (`operats2.cpp:2465`, the copy of the reply's first line
  stops at the first byte >= 0x80): `char` is unsigned in every plug-in (`/J`), the loop copied
  the whole line. The loop is rewritten for another reason (row 11) and keeps that behaviour.
- G2 and G8 "right as it is, must stay code page": true only while the inner text is code page;
  with a UTF-8 reply inside it was a defect of the same kind (rows 6, 14).
- G5 / section 0a "proxy error text = code page": UTF-8 after package A (contract).
- G9 `operats3.cpp:2405` "fits while the template is shorter than 100 bytes": now bounded.

### The whole-message rule for `ErrorDescr` (decision of this package)

`CFTPWorker::ErrorDescr` now holds **one encoding per text**: a bare server reply (as it came), a
plain resource text or `template + Windows error` (code page), or a **UTF-8 sentence** wherever
the sentence holds a reply, a proxy error text or a text of another file (rows 16, 19, 21-23).
It is never mixed inside. Where it is shown in my files (row 14) it is made UTF-8.

## 2. Sites the triage does not have

1. `operats1.cpp:1205-1215`, `1239-1241` - the `size` text was built with `strcpy` / `strcat` and
   `LoadStr` into `size[110]`; counted by the triage inside G1, now a bounded composition.
2. The plain state texts and the status texts of a working connection share the list-view
   **column** with the fixed cells but not the buffer text: nothing to do (checked: each call of
   `GetListViewDataFor` / `GetListViewData` fills one sub-item).
3. No further composition of a resource text with a name, path or reply was found in these
   files: every remaining `printf`-family line with `LoadStr(` was listed again after the change
   (`operats1.cpp` plain state texts, `operats2.cpp` `GetProblemDescr`, `operats3.cpp` status
   texts, rows 17 and 18).

## 3. How a person reaches the easiest FIXED rows

All in Czech (the translated templates were **not read** - whether a given template has an
accented letter decides whether the row fails on the build before).

1. **Rows 1-3, 13, 26 - no error needed.** FTP panel, one file `Žluťoučký kůň.txt`, F5 to the
   disk. The test server must **slow the transfer** (`RETR` sends the data in pieces over 20-30 s)
   so that the operation window stays open. Read: the window title (`Kopírování souboru "..." z
   <host>`), Operations list / column Description (`Kopírovat ... z ... do ... v ... režimu
   přenosu` with the size), Connections list / column Action (`Kopíruji ...`). The same with F8
   on the file (rows 1, 13 with `DELE` answered slowly) and with an upload (row 3).
2. **Rows 6 and 11 - a refusal.** F8 on the file; the server answers `DELE` with
   `550 Žluťoučký kůň.txt: Permission denied` - once in ASCII (`550 Permission denied`), once in
   UTF-8, once in code page 1250. The item fails and the window stays open; read Operations list /
   column State (`Selhalo: ... 550 ...`). All three replies must be readable together with the
   sentence. The same with `RETR` refused (`ITEMPR_INCOMPLETEDOWNLOAD`) or `MKD` on upload.
3. **Rows 14 and 21 - a worker that cannot log in.** The server accepts the first login (the
   panel) and refuses `PASS` on every further connection with `530 Přihlášení odmítnuto` (UTF-8 /
   1250 / ASCII). Start a copy of two large files and add a second connection in the operation
   window (button *Add*), or let the panel connection be busy: Connections list / column Status
   shows `Nelze se připojit: Chyba přihlášení: 530 ...`. Double click on the row opens the Solve
   Error dialog (package C's sink, `dialogs8.cpp:1218` - see section 4).
4. **Rows 24, 25, 28, 31 - the log.** After the copy of step 1: the FTP *Logs* window, the log of
   the operation's worker: the first two lines (title line and `Host: ..., time is ...`), the
   `Připojuji se ...` header and `Stahuji soubor "Žluťoučký kůň.txt"...`. Logging of workers must be
   on (`Config.EnableLogging && !Config.DisableLoggingOfWorkers`).

Harder: rows 19, 20, 27 need a proxy server; row 36 an upload error followed by `SIZE`; rows 30
a symbolic link in the listing; row 33 a server that sends all data and never confirms; rows 34
(second site) and 37 the collision answer *Autorename*; row 38 a listing parsed by a server type;
rows 22, 23 a broken login script / a TLS failure.

## 4. Needed from other packages; what may not compile

### Needed from package C

- **`dialogs8.cpp:1218`** `SetDlgItemText(HWindow, IDE_SERVERREPLY, ServerReply)` in
  `CLoginErrorDlg::DialogProc` must become "wide when the text is valid UTF-8, else A"
  (`SplDisplayTextToWAlloc` + `SetDlgItemTextW`) - the triage's step 5 names it. **This is a hard
  dependency**: `ErrorDescr` reaches it through `CFTPWorkersList::GetErrorDescr`
  (`dialogs5.cpp:1285`, `1379`) and is a UTF-8 sentence now in the most common case
  (`Chyba přihlášení: 530 ...`, row 21). With the A call left as it is, the Czech sentence in the
  Solve Error dialog of the operation window would be garbled where it was readable before. At the
  time of writing the line was still the A call. If C does not change it, rows 16, 19, 21, 22, 23
  must be taken back (the status cell of row 14 stays right either way).
- `dialogs5.cpp:688-696` (the triage: a second load of the title for the progress bar, which draws
  A): `dlg->TitleText` is UTF-8 as a whole now - any A user of it shows it wrong in Czech.
- `dialogs6.cpp:805`, `881`: if `SplU8ToW` returns 0 also when the text does not fit `cchTextMax`,
  a long valid UTF-8 cell would go through the code page (the triage's open point; not read here).

### Needed from package A

- `CSocket::GetProxyError` giving UTF-8 (contract) - rows 16 and 19 are written for either
  encoding (`FTPTextToU8`), so nothing breaks if it stays code page.
- `FTPLogMsgCutKeepLineEnd` is used from `ftputils.h` (it is there in the working tree). `ctrlcon.h`
  has a second helper of the same purpose (`FTPLogLineWasCut`); if the session keeps only one, the
  16 calls in `operats2.cpp` (2), `operats3.cpp` (1), `operats4.cpp` (3), `operats7.cpp` (2),
  `operats8.cpp` (1), `operatsa.cpp` (3), `operatsb.cpp` (4) must be renamed.

### Needed from package B

- Nothing. `GetProxyTypeName` (`ftp2.cpp:2168`) may stay `LoadStr` or become `LoadStrU8` - row 27
  converts it.

### Not sure it compiles (nothing was built)

- `operats1.cpp` description column: `_snprintf_s(size, _TRUNCATE, ...)` relies on `size` being
  the array `char size[110]` declared at the top of the text block (it is); the new locals `num`
  / `numU8` are declared inside the braces of their `case`.
- `operats2.cpp` `GetConnectLogMsg`: `int res;` is assigned on all four paths (a "potentially
  uninitialized" warning is possible, not an error).
- `operats2.cpp` `GetProblemDescr`: uses `SplLegacyToU8Alloc`, `SplU8CopyTrunc`, `free` - all
  through `precomp.h`.
- `operats3.cpp`: the new `static void WorkerErrDescrToU8` stands before `CFTPWorker` code and
  uses `FTPWORKER_ERRDESCR_BUFSIZE` (`operats.h`) and `lstrcpyn`.
- `operats6.cpp` / `operats7.cpp` / `operatsb.cpp`: local arrays declared inside nested blocks of
  large `switch` statements (no initializers, each inside its own braces).
- `HOST_MAX_SIZE`, `USER_MAX_SIZE`, `PROXYSRVNAME_MAX_SIZE`, `SERVERTYPE_MAX_SIZE` are used as
  array sizes (`3 * ...`); all are `#define`s of `ftp.h` except `SERVERTYPE_MAX_SIZE`, which is
  used the same way at `operats7.cpp:1144`.

### Behaviour that changed besides the encoding

- `Host`, `ConnectToHost`, `ProxyName` equal to `NULL` printed `(null)` in the log headers; they
  print an empty text now (`FTPTextToU8` of `NULL`).
- A log message cut by its buffer ends with `\r\n` again; the connect headers end with one line
  end after a cut, not two.
- The first line of a reply appended to an item's state is at most 299 bytes (it was limited only
  by the 500-byte state text).
- Stack: `CFTPOperation::GetConnectLogMsg` about 4 KB more, `CFTPQueueItem::GetProblemDescr` 1.2 KB,
  the worker event handlers 1 KB per converted reply.

## 5. Other defects seen and left

1. **Core** - `CSalamanderGeneral::PrintDiskSize` for plug-ins (`u8 = FALSE`) composes a UTF-8
   separator with code-page words: mode 1 / 2 with `NumberToStr` (Czech: no-break space + `bajtů`),
   mode 0 / 4 where the decimal separator is not ASCII. Every plug-in that shows the text gets a
   mixed text. Candidate for `specs/NEXT-WORK.md` (row 36 here; row 15 in exotic locales).
2. `operats3.cpp:590`, `598`, `617`, `679`, `695` - the status of a working connection is
   code-page text; with defect 1 in a locale with a non-ASCII decimal separator the cell is mixed.
3. A reply longer than the buffer of `CopyStr` (`50 + FTP_MAX_PATH`, `ErrorDescr` 200 bytes at
   `operats3.cpp:2204`) can be cut inside a UTF-8 character; `WorkerErrDescrToU8` repairs it for the
   status cell, the copies at `operats6.cpp` (row 21) do not check (a reply over 350 bytes).
4. The triage's "other defects" 2-4 (`targetPath[MAX_PATH]` at `operats6.cpp:1472-1479`,
   `sourcePath[MAX_PATH]` at `operatsa.cpp:810-814`, the `MAX_PATH` / 301-byte copies of
   `operats1.cpp:1558-1970`) were not touched - none of the lines was changed for this feature.
5. `operats6.cpp:750-754` - the date / time text is still built with `strcat` / `sprintf` into
   `errBuf` from two 50-byte A calls (fits; converted to UTF-8 inside `GetConnectLogMsg`).
6. `operats3.cpp:2243` - `GetWorkerErrorTxt(data1, errBuf, 300)` is called for its side effect of
   filling `errBuf`; with `NO_ERROR` it would return a `LoadStr` pointer and leave `errBuf`
   unfilled (not reachable there: `data1 != NO_ERROR`).
