# Feature 134 - package A: control connection, sockets, SSL, data connections, the log

2026-10-13. **Nothing was built, run or probed** - every line below is from reading and editing.
Line numbers are today's (after the edits) unless the column says "triage".

Files changed: `ctrlcon.h`, `ctrlcon1.cpp`, `ctrlcon2.cpp`, `ctrlcon3.cpp`, `ctrlcon4.cpp`,
`ctrlcon5.cpp`, `sockets.cpp`, `ssl.cpp`, `datacon1.cpp`, `datacon2.cpp`. Not changed:
`sockets.h`, `ssl.h`, `datacon.h` (no declaration changed). BOM and CRLF kept (checked by bytes).
`tools/check_encoding.py` run read-only afterwards: `TOTAL: 0`.

Read completely: `ctrlcon1.cpp` 360-2260, `ctrlcon2.cpp` 1-620 and 1330-end, `ctrlcon3.cpp` 28-840
and 1085-1400, `ctrlcon4.cpp` 92-196, 470-755, 1300-1335, `ctrlcon5.cpp` 296-480, 796-818,
918-1030, `sockets.cpp` 870-1058, `ssl.cpp` 190-380, 530-690, 855-985. The rest of these files and
`datacon1.cpp` / `datacon2.cpp` were searched (`LoadStr`, `sprintf`, `strcat`, `SetText`,
`MessageBox`), not read line by line - same limit as the triage.

## 0. What was added

- `ctrlcon.h`: `struct CFTPU8Piece` (2,100 bytes) and `struct CFTPU8Name` (603 bytes): a piece of
  unknown encoding as UTF-8 for one `printf` argument - `CFTPU8Piece(replyBuf).Text` - through
  `FTPTextToU8`. Used for every server reply, `FTPGetErrorText` text, `GetFatalErrorTxt` /
  `GetOperationFatalErrorTxt` result, and for host / user / proxy names (an older version may have
  stored them in the code page - FR-003).
- `CLogs::GetLogItemName` (the name of a log as the Logs dialog lists it, UTF-8) and
  `CLogs::GetLogItemNameForQuestion` (`ctrlcon2.cpp:1462`, `1519`, declared in `ctrlcon.h`).
- Used from package B's `ftputils.h`: `FTPLogMsgCutKeepLineEnd`, `FTPSendListTextMsg`.

## 1. Step 8 - the log

| What | Where | Verdict |
|---|---|---|
| Every appended message UTF-8 on its own | `CLogs::LogMessage` `ctrlcon2.cpp:1897`, helper `LogMessageToU8Alloc` `1856` | FIXED. ASCII: no allocation, appended as before. Valid UTF-8: kept. A UTF-8 text cut inside a character before its line end (evidence rule of `SplDisplayTextToWAlloc`): the torn character is dropped, `\r\n` kept. Anything else: `SplLegacyToU8Alloc`. **Kept raw**: low memory, or a zero byte inside the message |
| Size limit `LogMaxSize` | `ctrlcon2.cpp` (same function) | RIGHT AS IT IS after the change: the conversion runs before the limit is computed, so `len` is the stored byte count. `SkipBeginning` cuts at line ends only, so the log stays valid UTF-8. A single message longer than the limit stays whole, as before |
| The log window | `CLogs::SetLogToEdit` | RIGHT AS IT IS: it already sets the text wide when the whole log is valid UTF-8 - which it now is. The `A` fallback stays for a raw message |
| Save log | `CLogs::SaveLog` `ctrlcon2.cpp:2146-2160` | FIXED: the bytes are UTF-8 by the sink; **a UTF-8 BOM is written** - the whole file is written in this one function into a `CREATE_ALWAYS` file (read completely). Save all logs goes the same way: one BOM, logs joined by the ASCII separator |
| Copy to clipboard | `CopyLog` `2240`, `CopyAllLogs` `2367` | FIXED: `CopyTextToClipboardW` of `SplDisplayTextToWAlloc(log)`. Read in the core: the interface's `CopyTextToClipboard` is code page (`src/consts.h:731-735` "keeps CP_ACP semantics forever (plugin ABI)", `salamdr4.cpp:1332` puts the bytes as they are) |
| Composed log messages in my files | see tables below (headers, changing path, unexpected reply, data connection error) | FIXED |
| Plain `LoadStr` texts into the log (about 40 in my files) | - | RIGHT AS IT IS (the sink converts) |

Behaviour notes for the fix log: a log that was never written to now copies as an empty text
(before: the core refused a NULL text and the error box came). The position kept in the log window
while it updates (`SetLogToEdit`, `SkippedChars`) mixes bytes with characters - as before, now
more often visible because Czech sentences are two-byte; not touched.

## 2. Rows of part A (triage lines 285-485)

| triage file:line | today | template | verdict | pieces converted, sink |
|---|---|---|---|---|
| ctrlcon1.cpp:678, 740 | 701, 765 | IDS_GETIPERROR | FIXED | `MakeConnectErrorFormat` (`468`): host -> UTF-8 -> `%` doubled (131 kept); cut: torn character, then half directive. Sinks: wait window, `SalMessageBox` |
| ctrlcon1.cpp:906, 932 | 950, 976 | IDS_OPENCONERROR | FIXED | same; `formatBuf` enlarged to `300 + 2 * HOST_MAX_SIZE` |
| sockets.cpp:998-1007 | 1005-1024 | IDS_GETIPERROR, IDS_PROXY*ERROR ... (format) | FIXED | all nine templates `LoadStrU8`, host through `CFTPU8Name` then `FTPDoublePercents`; `errBuf` = error text as UTF-8 |
| ctrlcon1.cpp:1021, 1026 | 1067, 1072 | IDS_WAITINGTORETRY, ...2 | FIXED | host `CFTPU8Name`, `GetFatalErrorTxt` text `CFTPU8Piece`; wait window |
| ctrlcon1.cpp:1037-1040 | 1083-1091 | `opFatalErrorTextID` or `formatBuf` | FIXED (triage: right when a resource id) | always `LoadStrU8` + `CFTPU8Piece(error text)` - uniform, and a UTF-8 reply is now right too |
| ctrlcon1.cpp:1061, 1080 | 1112, 1132 | IDS_WAITINGTORETRYSUF | FIXED | `buf` is UTF-8; `retryBuf` enlarged |
| ctrlcon1.cpp:1981-1985 | 2040-2049 | same ids, or `formatBuf` | FIXED | as 1083; `SalMessageBox` |
| ctrlcon1.cpp:956/962, 1948, 1971 | - | text alone | RIGHT AS IT IS | one text, log sink / message box take either encoding |
| ctrlcon1.cpp:685 | 709 | IDS_GETTINGIPOFSERVER | FIXED | host; wait window; bounded |
| ctrlcon1.cpp:846, 848 | 889, 891 | IDS_OPENINGCONTOSERVER, ...2 | FIXED | host; bounded |
| ctrlcon1.cpp:1523 | 1582 | IDS_SENDINGLOGINCMD | FIXED | `CFTPU8Piece(tmpCmdBuf)` |
| ctrlcon2.cpp:350 | 340-353 | IDS_CLOSINGCONNECTION | FIXED | host as UTF-8, shortened at a whole character (was byte 20) |
| ctrlcon3.cpp:74 | 79 | IDS_SENDINGCOMMAND | FIXED | `CFTPU8Piece(command as sent)`; torn tail of the 300-byte copy dropped; `buf` enlarged |
| ctrlcon1.cpp:822, 1394, 1435, 1457 | 863, 1447, 1490, 1513 | IDS_CONNECTINGTOAS2 | FIXED | names `CFTPU8Name`; sink `dialogs8.cpp:1148` is wide now (package C, seen) |
| ctrlcon1.cpp:1415 | 1469 | IDS_CONNECTINGTOAS1 | FIXED | same |
| ctrlcon1.cpp:1646 | 1706 | IDS_CONNECTINGTOAS1 | FIXED | sink `dialogs8.cpp:1253` wide (package C, seen) |
| ctrlcon1.cpp:1647 | - | reply alone | RIGHT AS IT IS | sink is package C's |
| ctrlcon1.cpp:824 ... (titles) | - | plain | RIGHT AS IT IS | - |
| ssl.cpp:228-304 + 883 | 228-306, 884-897 | IDS_SSL_ERR_NOTYETVALID / EXPIRED | FIXED | `LoadStrU8`; all five copies `SplU8CopyTrunc`; dialog text set with `SetDlgItemTextW` (`SplDisplayTextToWAlloc`, `A` fallback) |
| ctrlcon1.cpp:786, 805 | 819, 841 | IDS_LOGHEADER, IDS_RECONLOGHEADER | FIXED | host, date/time (`A` API) through `CFTPU8Name`; cut keeps `\r\n` |
| ctrlcon1.cpp:779, 798 | 810, 832 | IDS_PRXSRV(RECON)LOGHEADER | FIXED | + user, proxy name, `GetProxyTypeName` (code page, as package B says), proxy host and user |
| ctrlcon2.cpp:1472-1513 | 1462-1517, 1565 | IDS_FTPIN*PANEL ... | FIXED | item UTF-8, added wide (`FTPSendListTextMsg`) |
| ctrlcon2.cpp:2124, 2153 | 2268-2271, 2300-2303 | IDS_CLEARLOGQUESTION, IDS_REMOVELOGQUESTION | FIXED | the name is composed again from the log by its UID (not taken from the combo); `itemName` only when the log is gone, through `FTPTextToU8` |
| ctrlcon2.cpp:2067, 2081 | 2202, 2217 | IDS_SAVELOGERROR | FIXED | `GetErrorText` is UTF-8; bounded |
| ctrlcon3.cpp:1126 | 1138 | IDS_LOGMSGCHANGINGPATH / REFRESHINGPATH | FIXED | path UTF-8; cut keeps `\r\n` |
| ctrlcon3.cpp:100-110 | 100-117 | IDS_LOGMSGUNEXPREPLY | FIXED (triage: right, reply) | reply `CFTPU8Piece`, prefix `LoadStrU8`; a message without a line end gets one |
| datacon1.cpp:151/156, datacon2.cpp:268/273 | same | IDS_LOGMSGUNABLETO* | RIGHT AS IT IS | all code page, the log sink converts |
| datacon1.cpp:377, datacon2.cpp:426 | 379, 428 | IDS_LOGMSGDATCONERROR | FIXED | `CFTPU8Piece(errBuf)` (UTF-8 proxy text or `FormatMessage`) |
| ssl.cpp:550, 598, 666 | same | IDS_SSL_LOG_* | RIGHT AS IT IS | code page + ASCII, log sink |
| ssl.cpp:558, 561 | same | IDS_SSL_LOG_SUBJECT / ISSUER | RIGHT AS IT IS (was UNCLEAR) | whatever `X509_NAME_oneline` gives, the log sink makes the message UTF-8 or reads it as code page - not worse than before. Not verified what OpenSSL gives |
| ssl.cpp:673 | same | IDS_SSL_ERR_CONNECT_ERR | RIGHT AS IT IS | code page + ASCII; where it joins a sentence in `ctrlcon1.cpp` it goes through `CFTPU8Piece` |
| sockets.cpp:952-953, 986 | 960-961, 994 | IDS_PROXYERRGETIP, IDS_PROXYUNEXPECTEDREPLY, IDS_PROXYERROPENCON | FIXED | `GetProxyError` output UTF-8 (contract) |
| sockets.cpp:960-961, 967 | 968-975 | IDS_PROXYERRSENDREQ ... | FIXED (triage: right) | part of the same contract: all one-line texts are `LoadStrU8` now |
| sockets.cpp:899, 936 | 905, 944 | pieces | FIXED | `LoadStrU8`; `FTPGetErrorTextU8`; the HTTP proxy's reply through `FTPTextToU8` |
| ctrlcon2.cpp:534-536, 570 | 575 | IDS_*CONLOSTFORMATERROR | FIXED (triage: right, reply) | `CFTPU8Piece(errBuf)`; was an unbounded `sprintf`; `buf` enlarged |
| ctrlcon3.cpp:688 | 692-698 | `opFatalErrorTextID` | FIXED (triage: right, reply) | own buffer `msg`, bounded |
| ctrlcon3.cpp:646-695 | - | text alone | RIGHT AS IT IS | - |
| ctrlcon3.cpp:817 | 827 | IDS_GETCURWORKPATHERROR | FIXED (triage: right, reply) | bounded |
| ctrlcon3.cpp:1242, 1281 | 1256, 1296 | IDS_CHANGEWORKPATHERROR | FIXED | reply `CFTPU8Piece` |
| sockets.cpp:35 | same | IDS_WINSOCKETSERROR | RIGHT AS IT IS | all code page into `MessageBox` A |
| ctrlcon1.cpp:1115-1118 | same | AliasBtnNames | RIGHT AS IT IS | not to be touched |
| ctrlcon1.cpp:650 | 665 | IDS_PROXYSRVADREMPTY | RIGHT AS IT IS | dead text |

"FIXED (triage: right, reply)": the triage called a code-page template with a reply right because
no name is in it. With a server that answers in UTF-8 the sentence was mixed all the same; the task
names "any `IDS_*ERROR` sentence with a reply", so these were done with the same pattern.

## 3. Rows of part B in ctrlcon4/5

| triage row | today | template | verdict | notes |
|---|---|---|---|---|
| G1 ctrlcon4.cpp:689 | 698 | IDS_CHANGEWORKPATHERROR | FIXED | reply `CFTPU8Piece` |
| G1 ctrlcon5.cpp:114, 535, 711 | 115, 551, 731 | IDS_CHANGEWORKPATHERROR | FIXED x3 | same |
| B1, B2 ctrlcon4.cpp:107/109 | 109, 111 | IDS_LISTWNDDOWNLOADING(FILE) | FIXED | host `CFTPU8Name`; `buf` + `MAX_PATH` |
| B3 ctrlcon4.cpp:184 | 186 | IDS_LOGMSGDATCONERROR | RIGHT AS IT IS | all resource text (`GetProxyTimeoutDescr` unchanged) |
| B4 ctrlcon4.cpp:506 | 510 | IDS_LISTPATHERROR | FIXED | |
| B5 ctrlcon4.cpp:556-600 | 564-606 | IDS_UNABLETOREADLIST + SUFFIX..4 | FIXED (triage: right) | needed: `replyBuf` may now be the UTF-8 text of `GetProxyError`; both templates `LoadStrU8`, piece `CFTPU8Piece` |
| B6 ctrlcon4.cpp:740-744 | 749-753 | same + IDS_ERRDATACONDECOMPRERROR | RIGHT AS IT IS | templates only |
| B7 ctrlcon4.cpp:1322 | 1334 | IDS_LOGMSGDATCONERROR | FIXED | proxy text is UTF-8; cut keeps `\r\n` |
| B8 ctrlcon5.cpp:320-369 | 326-375 | IDS_DOWNLOADFILEERROR + SUFIX1/2/3 | FIXED | the `LoadStr` pieces put into `replyBuf` stay `LoadStr` - the one `CFTPU8Piece(replyBuf)` at 374 converts whatever is there |
| B9 ctrlcon5.cpp:440-448 | 449-457 | + SUFIX3 | FIXED | |
| B10 ctrlcon5.cpp:471-475 | 484-488 | + SUFIX4 | FIXED | suffix printed with `"%s"` (was used as a format) |
| B11 ctrlcon5.cpp:590 | 608 | IDS_CREATEDIRERROR | FIXED | |
| B12 ctrlcon5.cpp:752, 779 | 774, 802 | IDS_QUICKRENAMEERROR | FIXED x2 | |
| B12b ctrlcon5.cpp:810-814 | 835-840 | IDS_QUICKRENAMEFILEERR + SUF1/2 | FIXED | suffix with `"%s"` |
| B15 ctrlcon5.cpp:930-934 | same area | plain | RIGHT AS IT IS | |
| B16 ctrlcon5.cpp:950 | 979 | IDS_LOGMSGDATCONERROR | FIXED | as B7 |
| B17 ctrlcon5.cpp:995-997 | same area | IDS_OPENACTDATACONERROR | RIGHT AS IT IS | all code page into the message box |
| B18 ctrlcon5.cpp:1013, 1016 | same area | IDS_LOGMSGUNABLETOCONPRX(2) | RIGHT AS IT IS | all code page, log sink |

## 4. Sites the triage does not have

- `CopyLog` on a log never written to (see section 1).
- `SetLogToEdit`: caret and scroll positions in bytes against a wide edit control (left).
- `ctrlcon1.cpp:957` the "simple error" copy of `formatBuf` into `errBuf` is shown as a text although
  it is a format (`%%` of a host would show doubled) - left, only the copy is whole-character now.

## 5. How to reach the easiest FIXED rows

1. **MKD refused** (`ctrlcon5.cpp:608`, measured failing before by the coordinator): F7 with
   `Žluťoučký` on the FTP panel; the server answers `550 <name>: File exists` once in ASCII, once
   in UTF-8, once in code page 1250. Message box: sentence, name and reply readable in all three.
2. **The log** (`ctrlcon2.cpp:1897`, `ctrlcon3.cpp:1138`): enter a directory with an accented name
   on a server that lists in UTF-8; Logs window: `Změna cesty na "<name>"` and the `CWD <name>`
   line both readable (the copy of the command is code-page bytes, converted at the sink). Then
   Save log: the file starts with `EF BB BF` and is valid UTF-8.
3. **Change path refused** (`ctrlcon3.cpp:1256/1296`): Shift+F7 to `/neexistující`; the server
   refuses CWD with `550` in each of the three encodings.
4. **No server at all**: connect to host `žluťoučký.test` - wait window "Getting IP address"
   (`ctrlcon1.cpp:709`, appears only after the delay) and the error box / retry window
   (`701/765`, `1083`, `2040`); host with a `%` (`a%sb`) as the 131 regression row.
5. Logs window with a user `jiří`: the combo item (read with `CB_GETLBTEXT` W) and the Clear log
   question (`ctrlcon2.cpp:2270`). Needs a server that accepts that user.

Not drivable on the hidden desktop: the clipboard rows; the wait windows of step 3 need a slow
server (delay before USER, before CWD, before the LIST data).

## 6. Needed from other packages, and what may not compile

Needed: nothing open. Seen done while I worked: package C's `dialogs8.cpp:1148`, `1249-1253` (wide
sinks) and `dialogs2.cpp` (combo item read wide, handed on as UTF-8); package B's helpers in
`ftputils.h`. For the callers of `GetProxyError` in packages B / D (`operats3.cpp:2242`,
`operats7.cpp:146`, `969`, `operats8.cpp:877`, `operatsb.cpp:1629`, `1884`): the text is UTF-8,
may be longer than before by the host's and the Windows text's growth, and is cut at a whole
character.

Not compiled - places to look at first if the build fails:

- `ctrlcon.h` (the two structs): `explicit` constructors used as temporaries in a variadic call
  (`CFTPU8Piece(x).Text`) - standard, but used about 60 times.
- `ctrlcon2.cpp:1565`: `i == FTPSendListTextMsg(...)` compares `int` with `LRESULT`.
- `ctrlcon2.cpp:2240`, `2367`: `SalamanderGeneral->CopyTextToClipboardW(textW, -1, FALSE, NULL)` -
  signature read in `spl_gen.h:1854`; that the length -1 is accepted was read in the core
  (`salamdr4.cpp:1202`), the interface wrapper between them was not read.
- `ctrlcon1.cpp:797`, `1082`, `2041`: objects declared inside `case` blocks (all three blocks have
  braces - checked) of a function with `goto RETRY_LABEL`.
- `ctrlcon1.cpp:810-843`: up to seven `CFTPU8Name` temporaries per statement (about 4 KB of stack
  each statement) in `StartControlConnection`; the function's frame grew by roughly 25 KB in all.
- `ssl.cpp:884-897`: a braced `case WM_INITDIALOG` block.

Not sure about (behaviour, not syntax):

- `SendMessageW(CB_ADDSTRING)` to a combo of a dialog created with the `A` API keeps characters
  outside the code page only if the control is not subclassed with an `A` procedure - the same
  pattern the plug-in uses for the bookmark list (`ftp3.cpp:304-319`); not measured here.
- `LogMessageToU8Alloc`'s torn-tail rule was not run against test data.
- The name in the Clear / Remove question is composed at the moment of the click, so it can differ
  from the combo item when the state of the connection changed in between.

## 7. Other defects seen and left

- `ctrlcon3.cpp:1118`, `1349` `lstrcpyn(cutFileName, newPath, MAX_PATH)` (a name cut, triage).
- `CopyStr` (`ctrlcon2.cpp:11`) cuts replies by bytes; such a reply, when UTF-8, is then read as
  code page by `CFTPU8Piece` (only replies of 300 / 700 bytes and more).
- `sockets.cpp:745` `gethostbyname` on the UTF-8 host; `ssl.cpp:258` `CP_ACP` on the host;
  `ssl.cpp:940-946` host widened byte by byte; `ssl.cpp:215`, `337` `%ls` in call-stack texts.
- `ssl.cpp:558/561/666` `wsprintf` / `sprintf` into `buffer[256]` with a translated template.
- `ctrlcon2.cpp` `SaveLog`: `fileName[MAX_PATH]` for the UTF-8 name.
- `sockets.cpp:980-989`: a resource text used as a `printf` format without arguments (a `%` in a
  translation); `ctrlcon1.cpp:665` dead `strcpy`.
