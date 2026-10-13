# Feature 134 - work package B (listing, file system interface, configuration, parser)

2026-10-13. Nothing was built or run; every changed line was read again. Files changed:
`fs2.cpp`, `fs3.cpp`, `fs4.cpp`, `fs5.cpp`, `ftp.cpp`, `ftp2.cpp`, `ftp3.cpp`, `ftp.h`,
`ftputils.h` (all in `src/plugins/ftp`; BOM and CRLF kept - checked). Not changed (nothing to
do there): `fs1.cpp`, `ftp4.cpp`, `ftputils.cpp`, `menu.cpp`, `parser1.cpp`, `parser2.cpp`,
`parser3.cpp`, `parser.h`.

**The first thing to know:** part B of the triage also covers `ctrlcon4.cpp` and `ctrlcon5.cpp`
(21 of its 42 rows). Those two files are **not** in package B's file list and were not touched.
At the time of writing they still hold the old code (`LoadStr(IDS_CHANGEWORKPATHERROR)` at
`ctrlcon4.cpp:689`, `ctrlcon5.cpp:114`, `535`, `711`; `IDS_LISTPATHERROR` `ctrlcon4.cpp:506`;
`IDS_CREATEDIRERROR` `ctrlcon5.cpp:590`; `IDS_QUICKRENAMEERROR` `ctrlcon5.cpp:752`, `779`;
`IDS_DOWNLOADFILEERROR` `ctrlcon5.cpp:320-369`, `440-448`, `471-475`; the wait window
`ctrlcon4.cpp:107/109`; `IDS_QUICKRENAMEFILEERR` `ctrlcon5.cpp:810-814`). The session must check
that another package owns them - otherwise the easiest probe rows of step 2 (F7 on an existing
name, a refused CWD during a listing) stay wrong.

## New helpers (in `ftputils.h`, usable by every package)

- `FTPLogMsgCutKeepLineEnd(char* buf, int bufSize)` - for a log message that
  `_snprintf_s(buf, _TRUNCATE, ...)` had to cut (negative result): drops the torn character and
  puts `\r\n` back. Used as `if (_snprintf_s(...) < 0) FTPLogMsgCutKeepLineEnd(buf, sizeof(buf));`.
  (`operats2.cpp:386`, `833` of another package already call it with this signature.)
- `FTPSendListTextMsg(HWND ctrl, UINT msg, WPARAM wParam, const char* text)` - `LB_ADDSTRING` /
  `LB_INSERTSTRING` / `CB_ADDSTRING` / `CB_INSERTSTRING` sent wide for a text that is UTF-8 or
  code page (`SplDisplayTextToWAlloc`); the A message only when memory is low. Returns the
  message's result.

## 1. Every row of part B

Line numbers: "triage" = as in the triage, "today" = after this package's edits.

### Rows in package B's files

| Row | triage line | today | template | verdict | pieces converted, sink |
|---|---|---|---|---|---|
| G1 | `fs2.cpp:224` | `fs2.cpp:226-230` | IDS_CHANGEWORKPATHERROR | FIXED | `LoadStrU8`; `path` UTF-8; `replyBuf` -> `FTPTextToU8` into `replyU8[2100]`; `_TRUNCATE` + `SplU8TrimTornTail`. Sink: core `SalMessageBox` (UTF-8 or code page) |
| G1 | `fs3.cpp:808` | `fs3.cpp:812-817` | same | FIXED | same; `ftpReplyBuf` (700 bytes filled for this call) -> `FTPTextToU8`. Sink `SalMessageBox` |
| G1 | `fs5.cpp:999` (really `1006`) | `fs5.cpp:1014-1019` | same | FIXED | same; `replyBuf` -> `FTPTextToU8`. Sink `ShowMessageBox` |
| B19 | `fs2.cpp:203` | `fs2.cpp:203-205` | IDS_LOGMSGCHANGINGPATH | FIXED | `LoadStrU8`; `path` UTF-8; cut keeps `\r\n`. Sink: log (package A makes each message UTF-8) |
| B20 | `fs2.cpp:1078` | `fs2.cpp:1084-1086` | IDS_LOGMSGLISTINGCACHEDPATH / IDS_LOGMSGLISTINGPATH | FIXED | `LoadStrU8`; `Path` UTF-8; cut keeps `\r\n`. Log |
| B21 | `fs2.cpp:1264` | `fs2.cpp:1272-1277` | IDS_LOGMSGPARSEDBYSRVTYPE | FIXED | `LoadStrU8`; `LastServerType` -> `FTPTextToU8` (a name stored by an older version may be code page). Log |
| B22 | `fs3.cpp:50-52` | `fs3.cpp:50-52` | `"%d\t%s\t%d\t%s"` + two button texts | RIGHT AS IT IS | `AliasBtnNames`, templates and numbers only - the brief says it stays |
| B23 | `fs3.cpp:758-760` | `fs3.cpp:758-764` | IDS_LOGMSGSENDINGUSRCMD (+ IDS_SECRETFTPCOMMAND) | FIXED | both `LoadStrU8`; the typed command is UTF-8. `logBuf` (the shown copy of the command) is now UTF-8 in both cases; it also goes to `SendFTPCommand` as the log copy (log sink) and to `CWelcomeMsgDlg` (`dialogs2.cpp`, package C - already reads it through `FTPTextToU8`). What is **sent** is `cmdBuf` - unchanged |
| B24 | `fs4.cpp:327-328` | `fs4.cpp:336-340` | IDS_PLSTR_BLOCKSINSELFILES | **TRIAGE WRONG**, FIXED | the triage says "numbers only, right". The numbers come from the core's `NumberToStr`, whose thousands separator is UTF-8 (`src/salamdr1.cpp:998`, `SalGetLocaleInfoU8`) - in Czech, French, ... a no-break space = two UTF-8 bytes next to a code-page template: mixed for every count >= 1000. `LoadStrU8` (the core's `ExpandPluralString` parses ASCII marks byte-wise, `src/salamdr4.cpp:412-` - UTF-8 safe) + trim. Sink: core information line (`SalU8ToWDisplayAlloc`, `src/stswnd.cpp:165`: either encoding) |
| B13 | `fs4.cpp:336-524` | `fs4.cpp:345-540` | IDS_SRVTYPE_SIZEISDIR + date / time texts | FIXED | `LoadStrU8(IDS_SRVTYPE_SIZEISDIR)`; the three `GetDateFormat` / `GetTimeFormat` (A) texts through the new `AddLegacyStrAux` (`FTPTextToU8`); the cut of the full line trims a torn character (`fs4.cpp:537`). Name, listing columns and `NumberToStr` texts are UTF-8 already. Sink: information line |
| B14 | `fs4.cpp:650` | `fs4.cpp:665-667` | IDS_DELETEFROMFTP | FIXED | `LoadStrU8`; `subjectSrc` is UTF-8 from the core now; `sprintf` -> `_snprintf_s(_TRUNCATE)` + trim. Sink `IDT_DELSUBJECT`, `dialogs4.cpp:1400-1407` read: `SplU8ToWAlloc` -> `SetDlgItemTextW`, else A - takes it |
| B25 | `fs4.cpp:929` | `fs4.cpp:946-948` | IDS_COPYFROMFTP / IDS_MOVEFROMFTP | FIXED | same. Sink `IDT_TGTPATHSUBJECT`, `dialogs4.cpp:1361-1368` read - takes it |
| B26 | `fs5.cpp:41` | `fs5.cpp:41-43` | IDS_CHANGEATTRSONFTP | FIXED | same. Sink `IDT_CHATTRSUBJECT`, `dialogs4.cpp:1596-1603` read - takes it |
| B27 | `fs5.cpp:404` | `fs5.cpp:406-408` | IDS_LOGMSGVIEWCACHEDFILE / IDS_LOGMSGVIEWFILE | FIXED | `LoadStrU8`; `file.Name` UTF-8; cut keeps `\r\n`. Log |
| B28 | `fs5.cpp:489` | `fs5.cpp:493-495` | IDS_LOGMSGCREATEDIR | FIXED | same with `newName` |
| B29 | `fs5.cpp:540` | `fs5.cpp:546-548` (logged at `613`) | IDS_LOGMSGQUICKRENAME | FIXED | same with `file.Name`, `newName` |
| B30 | `ftp.cpp:374-379` | `ftp.cpp:381-385` | About text | RIGHT AS IT IS | templates and compiled constants only; not touched |
| B31 | `ftp2.cpp:799`, `ftp.cpp:318` | `ftp2.cpp:794-808`, `ftp.cpp:323-324` | `"%s %s"` + IDS_SRVTYPEUSERDEF | FIXED | `UserDefinedSuffix` filled from `LoadStrU8` (`SplU8CopyTrunc`); the name through `FTPTextToU8` (so the result is UTF-8 also for a name of an older version); trim. Sinks in package B: `ftp3.cpp:65-67` (`CB_ADDSTRING`) and `ftp3.cpp:81` (`LB_ADDSTRING`) through `FTPSendListTextMsg` = wide. The combo is read back by index only (`dialogs8.cpp:566-570`), no text read-back exists (`CB_GETLBTEXT` only for the Logs combo) |
| B32 | `ftp2.cpp:1696` | `ftp2.cpp:1701` | IDS_HIDDENPASSWORD | FIXED | `LoadStrU8`; `value` is used after that line only for `logTxt` (the sent text was copied at `1692-1699` before) - what is sent is unchanged |
| B33 | `ftp2.cpp:2866` | `ftp2.cpp:2871-2875` | IDS_WANTDELPRXSRV | FIXED | `LoadStrU8`; `ProxyName` -> `FTPTextToU8` (`nameU8[600]`); `sprintf` -> `_snprintf_s(_TRUNCATE)` + trim. Sink `SalMessageBox` |
| B34 | `parser3.cpp:325` | same | IDS_STPAR_ERR_INVALREGEXP | RIGHT AS IT IS | checked: the core treats the regular-expression error text as code page itself (`SalLegacyToU8Alloc(RegExp.GetLastErrorText())`, `src/finddlg1.cpp:2114`, `src/viewer3.cpp:1368`), so this is code page + code page; the wrapper `dialogs3.cpp:667` (package C) is still `LoadStr` + `LoadStr` - consistent. If C makes that wrapper UTF-8, `errBuf` must go through `FTPTextToU8` there |

### Rows of part B that lie in files not given to package B

RECORDED (not package B's file; not read beyond the grep above, not changed):

| Row | file:line | template |
|---|---|---|
| G1 x4 | `ctrlcon4.cpp:689`, `ctrlcon5.cpp:114`, `535`, `711` | IDS_CHANGEWORKPATHERROR |
| B1, B2 | `ctrlcon4.cpp:107`, `109` | IDS_LISTWNDDOWNLOADING / ...FILE |
| B3 | `ctrlcon4.cpp:184` | IDS_LOGMSGDATCONERROR |
| B4 | `ctrlcon4.cpp:506` | IDS_LISTPATHERROR |
| B5, B6, B7 | `ctrlcon4.cpp:556-600`, `740-744`, `1322` | IDS_UNABLETOREADLIST..., IDS_LOGMSGDATCONERROR |
| B8, B9, B10 | `ctrlcon5.cpp:320-369`, `440-448`, `471-475` | IDS_DOWNLOADFILEERROR + suffixes |
| B11 | `ctrlcon5.cpp:590` | IDS_CREATEDIRERROR |
| B12 x2, B12b | `ctrlcon5.cpp:752`, `779`, `810-814` | IDS_QUICKRENAMEERROR, IDS_QUICKRENAMEFILEERR |
| B15-B18 | `ctrlcon5.cpp:930-934`, `950`, `995-997`, `1013/1016` | (right as it is by the triage) |

### Step 7 / step 8 items of the task that are not rows

| What | today | verdict |
|---|---|---|
| proxy combos `ftp2.cpp:2692`, `2815`, `2847`, `2898`, `2921` | `ftp2.cpp:2697`, `2820`, `2852`, `2907`, `2930` | FIXED: `FTPSendListTextMsg` (wide). The two resource items (`ftp2.cpp:2687`, `2689`) stay `LoadStr` + A (code page to a code-page sink). The combo is read by index only |
| `GetProxyName`, the "not used" text, `ftp2.cpp:2939` | `ftp2.cpp:2948-2950` | FIXED: `LoadStrU8` + `SplU8CopyTrunc`. Its one caller (`dialogs1.cpp`, the summary of the Connect dialog, package C) puts it into a UTF-8 sentence and expects "the name (UTF-8) or the not-used text" |
| `GetProxyTypeName` `ftp2.cpp:2173-2203` | unchanged | RIGHT AS IT IS: returns a `LoadStr` text; `dialogs8.cpp:1672` adds it to an A combo. Callers that compose it with a name convert at the place of use (see section 4) |
| `errDescrBuf`, `ftp2.cpp:2010` | `ftp2.cpp:2015` | RIGHT AS IT IS: one plain `LoadStr` text handed to other packages; the caller in this package (`ftp2.cpp:2471`) only traces it |
| plain log texts `fs2.cpp:1258`, `fs3.cpp:120`, `146` | - | RIGHT AS IT IS: plain resource text, the log sink converts |

Counts for the rows of part B: **FIXED 17** (G1 x3, B13, B14, B19, B20, B21, B23, B25, B26, B27,
B28, B29, B31, B32, B33), **TRIAGE WRONG and fixed 1** (B24), **RIGHT AS IT IS 3** (B22, B30,
B34), **RECORDED 21** (all in `ctrlcon4.cpp` / `ctrlcon5.cpp`, not package B's files). Outside
the rows: 2 more fixes (proxy combos - 5 sends; the "not used" text).

## 2. Sites the triage does not have

- B24 as a defect (above).
- `fs3.cpp:761`: the placeholder of a secret command in `logBuf` (a piece of B23, but it also
  reaches the reply window's title) - now UTF-8.
- `fs4.cpp:537`: the information line cut at 1000 bytes could end inside a character - trimmed.
- `ftp2.cpp:2948`: the "not used" text of `GetProxyName` (the triage names it only as a piece).

## 3. How to reach the fixed rows - the easiest first

1. **B25 / B14 / B26, no error needed.** Czech; FTP panel with a file `Žluťoučký kůň.txt`:
   F5 -> the label above the target path (`IDT_TGTPATHSUBJECT`, `GetDlgItemTextW`) must read
   `Kopírovat soubor "Žluťoučký kůň.txt" z FTP serveru do`; F8 with delete confirmation on ->
   `IDT_DELSUBJECT`; Ctrl+F2 on a Unix listing -> `IDT_CHATTRSUBJECT`. Server: only a listing
   with the accented name (UTF-8) and Unix rights. Use a directory for F8 too (core word
   `adresář`).
2. **B20 / B28 / B29 / B27, the log.** Enter a directory `Příloha` (log line `Výpis cesty
   "/Příloha"...`), F7 `Nový adresář`, F2 to another accented name, F3 on an accented file; then
   read the log window's text. Server: CWD / PWD / LIST / MKD / RNFR / RNTO / RETR accepted.
   Needs package A's log sink to be in.
3. **G1 `fs2.cpp:226`, a refused CWD in a message box.** Connected in the panel, *Change
   directory* (Shift+F7) with a path `/Neexistující` - the core calls `GetFullFSPath`. Server:
   refuse `CWD` to that path with `550 <text>`, once ASCII, once UTF-8 with the name, once
   code page 1250 with the name (`550 Neexistuj\xedc\xed: adres\xe1\xf8 nenalezen`). All three:
   sentence, path and reply readable. (The exact way the core reaches `GetFullFSPath` was not
   tried.)
4. **G1 `fs5.cpp:1014`.** From a disk panel F5 a file to the typed target
   `ftp://user@127.0.0.1:port/Neexistující/x.txt` while the other panel is connected. Server:
   refuse every `CWD` below the root with 550.
5. No server: **B33** - Connect to FTP Server -> Advanced / proxy servers -> a proxy named
   `Žluťoučký` -> the combo shows the name (was wrong in English too) -> *Delete*: the question
   (Czech template is ASCII - readable before too; German / French show the difference).
   **B31** - Configuration -> Servers: a user-defined type `Můj server`: the list item
   `Můj server (definováno uživatelem)` (`LB_GETTEXT` wide), and the *Server type* combo of a
   bookmark (`ftp3.cpp:66`).
6. **B24**: Czech, a listing parsed with a blocks column and no bytes column (VMS-like type),
   select files whose blocks sum to >= 1000: the information line's number separator.
7. **B32**: any login; the log line `PASS (skrytý)` with a user name `uživatel`.

## 4. Needed from other packages; things not sure to compile

### Needed

- **Owner of `ctrlcon4.cpp` / `ctrlcon5.cpp` (not package B)**: the 21 rows listed above -
  14 of them defects by the triage (G1 x4, B1, B2, B4, B8, B9, B10, B11, B12 x2, B12b).
- **Package C** (already done there as far as the working tree shows - to be checked after the
  build): `GetTypeNameForUser` now returns UTF-8. Callers outside package B:
  `dialogs1.cpp:1148`, `dialogs3.cpp:132` (now `130-141`), `290`, `433`, `477` (today's numbers
  in C's edited files differ; search `GetTypeNameForUser`). `dialogs3.cpp:477` hands it to
  `CRenameDlg` (the "copy data from" text, `dialogs8.cpp:1046`) - that sentence must be UTF-8.
- **Package C**: `GetProxyName` (`dialogs1.cpp`, summary) gives UTF-8 in both branches now; no
  conversion of the "not used" text needed there.
- **Package C**: `CWelcomeMsgDlg`'s `SentCommand` (`dialogs2.cpp:90`) is UTF-8 in both cases
  now; C's `FTPTextToU8` there is harmless.
- **Packages A and D**: `GetProxyTypeName` is still a code-page `LoadStr` text. Where it joins a
  UTF-8 sentence it must go through `FTPTextToU8`: `ctrlcon1.cpp:795`, `814` (A - not seen
  converted at the time of writing); `operats2.cpp:803` (D) already does.
- **Package C**, only if it changes `dialogs3.cpp:667`, `704`, `1643` to UTF-8: the parser's
  `errBuf` (`parser3.cpp:325`, code page) through `FTPTextToU8`.

### Not sure it compiles (not built)

- `ftputils.h:179-190` `FTPSendListTextMsg`: uses `SplDisplayTextToWAlloc`, `SendMessageA` /
  `SendMessageW`, `free` - the header is included in `precomp.h` after `splunicode.h` and
  `windows.h`, so it should; `LRESULT` compared with `int` at `ftp2.cpp:2852`, `2907`, `2930`
  (as before with `SendMessage`).
- `ftputils.h:156-173` `FTPLogMsgCutKeepLineEnd`: plain C; another package calls it with
  `_countof(buf)` and with `bufSize` - matches.
- `fs4.cpp:291-298` `static void AddLegacyStrAux(char*& s, char* end, const char* text)` placed
  after `AddStrAux` (non-static, same file) - if `AddStrAux` is declared `extern` somewhere with
  another signature nothing changes; the new one is file-local.
- `fs2.cpp:226-230`, `fs3.cpp:812-817`, `fs5.cpp:1014-1019`: a declaration (`char replyU8[...]`)
  inside an `if` block that had none before - blocks, so fine; 2,100 bytes more stack each.
- `fs3.cpp:761`: `strcpy(logBuf, cond ? LoadStrU8(...) : cmdBuf)` - `const char*` vs `char[]` in
  a conditional gives `const char*`, accepted by `strcpy`'s source.
- `ftp2.cpp:1701`: `value` is `const char*` (`ftp2.cpp:1605`) - `LoadStrU8` fits.
- `ftp.cpp:324`: `LoadStrU8` is defined above in the same file (`ftp.cpp:269`), and
  `SalamanderGeneral` / `HLanguage` are set before this line (`307`, `312`).
- `sizeof(errBuf)` / `sizeof(logBuf)` / `sizeof(txtBuf)` at the log sites: all are local arrays
  (the lines used the array form of `_snprintf_s` before).

## 5. Other defects seen and left

- `ftp2.cpp:1692-1711` (`ExpandText`): both the sent text and the log copy are clamped
  byte-wise at the buffer end (a cut inside a character; for the sent command also a cut
  command). Not touched - it is the send path.
- `fs4.cpp:38`, `60` (`GetText` of the date / time columns): `GetDateFormat` /
  `GetTimeFormat` A text into the core's transfer buffer - a cell of its own, code page; how
  the core shows it was not read. And `fs4.cpp:419-421`: the time column of the information
  line is formatted with `GetDateFormat` (the triage's "old slip") - left.
- `fs4.cpp:367-368`: `char formatedFileName[MAX_PATH]` for `AlterFileName` without a size (the
  triage has it).
- `fs3.cpp:50`: unbounded `sprintf` into `buffer[100]` (two translated button texts).
- `fs3.cpp:758` (now `757`): `lstrcpyn(cmdBuf, dlg.Command, FTPCOMMAND_MAX_SIZE)` can cut a
  typed command inside a character before it is sent.
- `ftp2.cpp:2952-2957` `GetProxyName`: `lstrcpyn` of the name into a
  `PROXYSRVNAME_MAX_SIZE` (101) buffer although the dialog stores up to 199 bytes - a cut inside
  a character makes C's summary code page again (the triage has the cut; the line was not
  changed because the caller's buffer size is C's).
- The callers' buffers for `GetTypeNameForUser` are `SERVERTYPE_MAX_SIZE + 101` = 202 bytes:
  name (100) + space + suffix (up to 99 bytes of UTF-8) fits; only a name of an older version in
  the code page that grows in UTF-8 can be cut - at a whole character.
- Path and name cuts of the triage's list B.6c (`fs2.cpp:466`, `623`, `724`, `fs5.cpp:841`,
  `MakeUserPart`) - untouched.
- A server reply of exactly 699 bytes that was cut by the 700-byte reply buffer inside a UTF-8
  character is then read through the code page by `FTPTextToU8` (the whole reply) - readable
  sentence and path, garbled reply; not handled.
