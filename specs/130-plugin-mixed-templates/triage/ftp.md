# Triage: FTP plug-in (`src/plugins/ftp`) - feature 130

Read-only triage, 2026-10-13. **No source file was changed**, nothing was built or run, no GUI.
This record is the only file written.

How it was made: the facts of sections 1-4 were read by the triage agent itself (file:line given).
The compositions were then read by four reading agents, one per group of files, each with the same
written facts and rules; their tables are sections A-D below, unchanged. Six of their claims were
checked again against the code afterwards (`ctrlcon2.cpp:205-211`, `dialogs1.cpp:970`,
`operats2.cpp:2465`, `operats2.cpp:680`, `sockets.cpp:745`, `dialogs1.cpp:1708`) - all six held. The
rest of the tables is their reading, not re-read. Every part says at its top which line ranges were
read completely and which only through a search; "inferred" marks what was not read.

Number of `LoadStr(` lines by `grep`: 846 in the plug-in's `.cpp` and `.h` files; the four groups
cover all `.cpp` files and count A 157, B 241, C 233, D 211 (the task's "about 868" was not
reproduced). The scanner of feature 127 (`scan_mixed.py --plugins`) lists 86 rows for `plugins/ftp/`; this triage
finds about **104 defective sites**, because the scanner misses templates kept in a variable, texts
composed in one function and shown in another, and code-page-only sinks without any `LoadStr`.

## Summary

- The plug-in is **half way already** (features 010 and 104): names, paths, host, user and typed
  values are UTF-8 inside, local file calls are wide, and nearly every sink of a dynamic text is
  "wide when the whole text is valid UTF-8, else the `A` call". That is the same rule as the core's
  message box - so the defect of GitHub #7 applies unchanged: a code-page template around a UTF-8
  name makes the whole text invalid UTF-8, it is shown through the code page, the name is garbled.
- Three things are different from the other plug-ins and decide the plan:
  1. **The log** is one byte string per connection and is shown as UTF-8 only when *all of it* is
     valid UTF-8 (`ctrlcon2.cpp:1564-1573`, `1609-1616`). It receives code-page templates, UTF-8
     names, raw server replies and the commands *as sent* (code page when the name is representable,
     `ctrlcon2.cpp:205-211`, `ftputils.cpp:3513-3526`). One accented directory gives
     `CWD <code-page bytes>` and `Changing path to "<UTF-8>"` in the same log - so the name in the
     log is garbled **in English too** (deduced from the code, not measured). No per-site change
     repairs it; the sink must normalise each message.
  2. **The core hands over a mixed text**: the subject of Copy / Move / Delete / Change attributes
     comes from `GetCommonFSOperSourceDescr` (`src/zip.cpp:3996-4004`): a code-page core word around
     a UTF-8 name. The plug-in wraps it (three confirmation dialogs, the operation window title, the
     first line of every worker log). It cannot be repaired inside the plug-in directory.
  3. **Server replies** are bytes of unknown encoding and are a piece of about 25 sentences. Once a
     template is UTF-8, a reply in a code page would turn the sentence to code page again - the
     reverse rule: every reply (and every `FTPGetErrorText` text) that meets a UTF-8 template must go
     through `SplLegacyToU8`.
- A few sinks are code page only and show a UTF-8 name wrong **in every language, English
  included**: the "Connecting to ... as ..." line of the password prompt (`dialogs8.cpp:1120`), the
  combo of the Logs window (`ctrlcon2.cpp:1513`), the Quick Connect address written back on OK
  (`dialogs1.cpp:970` - the garbled text is then stored in the address history), the lists of
  server types and proxy servers, the certificate error text (`ssl.cpp:883`).

## Counts per verdict

The parts count rows or sites as their tables are cut, so the sum is an order of size, not an
exact number of source lines.

| Part | DEFECT | RIGHT AS IT IS | of them "(reply)" | UNCLEAR |
|---|---|---|---|---|
| A - control connection, sockets, SSL (rows) | 21 (4 latent) | 17 | 5 | 1 (`ssl.cpp:558/561`) |
| B - listing, file system, configuration, parser (rows) | 31 (6 latent) | 12 | 1 | 0 |
| C - dialogs, compositions (rows) | 13 | 8 | 0 | 0 |
| C - dialogs, sinks without a composition of their own | 2 new (`dialogs1.cpp:970`, `dialogs3.cpp:895`); 4 more are the sinks of rows of A / B | - | - | 1 (proxy combo - answered by part B: `CB_ADDSTRING` A, `ftp2.cpp:2692`, so a defect) |
| D - operations, queue, workers (sites) | 39 | 41 | 21 | 0 |
| **Sum** | **about 104 + 3 sinks** | **78** | **27** | **1** |

Of the defects: **30 go to the log only** (A 3, B 8, D 19); about 14 are latent (they need a host
name, a server-type name or a locale word outside ASCII); about 60 are on the screen in ordinary
use. Besides them about **85 plain resource texts** go into the log (A 35, B 15, C 1, D 34) - each
of them is code page and matters for the log as a whole.

"Latent" for a host name: `gethostbyname` gets the UTF-8 bytes (`sockets.cpp:745`), so a host name
with a letter outside ASCII cannot be resolved directly; the texts composed after the resolve are
reachable with such a host only through a proxy server (inferred, not tried).

## 1. Remote names and paths: UTF-8 inside, converted at the protocol edge

- There is **no per-server encoding setting and no conversion table** in this plug-in
  (`ftputils.h:312-316` says so; a search of the plug-in for conversion calls finds only the two
functions below). The conversion
  is a heuristic, the same for every server.
- In: every field of a listing goes through `FTPListingFieldToU8` (`parser2.cpp:640`; body
  `ftputils.cpp:3457-3511`): ASCII and valid UTF-8 are kept, other bytes are read in the system code
  page, bytes that fit neither are kept raw. The working path of a 257 reply is decoded the same way
  (`ftputils.cpp:1699-1709`, called at `1746`, `1773`).
- Out: names are encoded only when a command is built - `PrepareFTPCommand` (`ctrlcon2.cpp:44-213`,
  12 commands at lines 77-174) calls `FTPU8NameToServer` (`ftputils.cpp:3513-3526`): ASCII as it is;
  the system code page when the name is representable there; otherwise the UTF-8 bytes. The log copy
  of the command is the sent bytes (`ctrlcon2.cpp:205-211`).
- So UTF-8 are: the panel listing (`file->Name`, `parser2.cpp:652-663`, cut at `MAX_PATH - 5` bytes
  at a whole character), the queue items (`Name`, `Path`, `TgtName`, `TgtPath`, `RenamedName` -
  part D, section 0a, with the places that fill them), the current path and everything the core
  receives (current path, full name, change-drive item, window-title path: part B, table B.1 - no
  resource text in any of them).
- Host, user, bookmark, proxy and server-type names and the history values are UTF-8: they are typed
  into fields read wide (`winliblt.cpp:1296-1319`, `dialogs8.cpp:33-60`). A user name saved by 0.1.8
  may still be code-page bytes (comment `dialogs8.cpp:1168-1172`, `1702`) - such pieces should be
  passed through `SplLegacyToU8`, not assumed. Two values are **code page** by the way they are read
  and written: `Server->ListCommand` (`dialogs8.cpp:618`, `625`) and the column names / descriptions
  of a server type (`dialogs4.cpp:176-187`).

## 2. Local paths: UTF-8, wide file calls

Local paths are UTF-8 (interface 104). File work goes through `FTPCreateFileU8`, `FTPDeleteFileU8`,
`FTPSetFileAttributesU8`, `FTPCreateDirectoryU8`, `FTPRemoveDirectoryU8`, `FTPFindFirstFileU8`
(`ftputils.cpp:3361-3455`, extended-length wide paths); the disk enumeration of an upload is wide and
converted with `SplWToU8` (`operats5.cpp:2043-2062`). The file dialogs are `SplGetFileNameU8`
(`ctrlcon2.cpp:2001`, `dialogs2.cpp:315`, `dialogs3.cpp:183`, `261`, `dialogs4.cpp:917`).
They meet texts in: the item descriptions and the title of an operation (part D, G1, G13), the fields
of the solve-error dialogs (each path in a field of its own, part C), the advanced-settings summary
(`TargetPanelPath`, part C, C-1), the worker log messages (part D, G15). No sentence with a local path
is written to a file other than the log.

## 3. Error texts

| Source | Encoding | Evidence |
|---|---|---|
| `FTPGetErrorText(err, buf, size)` | `"(%d) "` + `FormatMessage` in an `A` build = **code page**, in the display language of Windows (not of the plug-in) | `ftputils.cpp:958-977` |
| `GetWorkerErrorTxt`, `GetOperationFatalErrorTxt`, `FTPGetErrorTextForLog` | wrappers of it, or `LoadStr(IDS_UNKNOWNERROR)` = code page | `operats3.cpp:7-15`, `ctrlcon1.cpp:444-457`, `ftputils.cpp:1549-1556` |
| `GetFatalErrorTxt` | a `LoadStr` text, or the caller's `errBuf` (a server reply or a composed text) | `ctrlcon1.cpp:439-442` |
| `SalamanderGeneral->GetErrorText(err)` | **UTF-8** (agent brief; used at 13 places: `ctrlcon2.cpp:2067/2081`, `dialogs2.cpp:355/365`, `dialogs3.cpp:212/222/322/332`, `dialogs4.cpp:984/996`, `ssl.cpp:228-368`) | - |
| `CSocket::GetProxyError` | code-page templates + `FTPGetErrorText` / a proxy's reply + the FTP host name | `sockets.cpp:883-1010` |
| OpenSSL texts | ASCII (`ERR_error_string`; `X509_NAME_oneline` for a subject outside ASCII not verified) | `ssl.cpp:558-673` |
| server reply | raw bytes of the server, encoding unknown | `CopyStr`, `ctrlcon2.cpp:11-18` |

So today "template + `FTPGetErrorText`" is right (all code page), and "template + `GetErrorText`" is
wrong (13 places, all message boxes or the certificate dialog).

## 4. Sinks

| Sink | How it shows a text | Evidence |
|---|---|---|
| core message box (`SalMessageBox`, `SalMessageBoxEx`, `ShowMessageBox`) | valid UTF-8 as UTF-8, else code page | agent brief |
| wait windows `CWaitWindow`, `CListWaitWindow` | wide when valid UTF-8, else `A` | `dialogs2.cpp:939-947`, `1010-1023`, `1200-1207`, `1295-1309` |
| core static texts (`...->SetText`) | `SalU8ToW`, else `CP_ACP` | `src/gui.cpp:626-629` (read by part C) |
| core progress bar text | `A` only | `src/gui.cpp:244-269` (read by part C) |
| fields set with `ti.EditLine` (all solve-error dialogs, Connect dialog) | wide when the whole text is valid UTF-8, else `A` | `src/plugins/shared/winliblt.cpp:1266-1293` (read by part C) |
| subjects of the Copy / Move, Delete, Change attributes dialogs | the same rule | `dialogs4.cpp:1361-1368`, `1400-1407`, `1596-1603` |
| operation window: title | the same rule, `SplSetWindowTitleW` | `dialogs5.cpp:294-313` |
| operation window: both list views and their tool tips | the same rule **per cell** | `dialogs6.cpp:786-813`, `865-889`, `dialogs7.cpp:1185-1200` |
| operation window: `IDT_OPERATIONSTEXT`, buttons | `A` only (resource text and numbers only) | `dialogs5.cpp:417-418` |
| **the log window** | the same rule, but for the **whole log** | `ctrlcon2.cpp:1564-1573`, `1609-1616` |
| log file, clipboard | the bytes as they are | `ctrlcon2.cpp:2034`, `2098`, `2216` |
| combo of the Logs window | `CB_ADDSTRING` **A only**; read back with `CB_GETLBTEXT` A | `ctrlcon2.cpp:1513`, `dialogs2.cpp:688-690` |
| password / user / account prompt `CEnterStrDlg`, login error `CLoginErrorDlg` | `SetWindowText` / `SetDlgItemText` **A only** | `dialogs8.cpp:1116-1120`, `1216-1224` |
| certificate error dialog | `SetDlgItemText` **A only** | `ssl.cpp:883` |
| Quick Connect address on OK | `SetWindowText` **A only**, then read back wide and stored | `dialogs1.cpp:970` |
| lists of server types, proxy servers | `LB_`/`CB_ADDSTRING` **A only** | `ftp3.cpp:65`, `80`, `dialogs3.cpp:131`, `ftp2.cpp:2692-2921` |
| bookmark list, history combos, raw listing / welcome window, parser test list | wide with `A` fallback | `dialogs1.cpp:1277-1284`, `ftp3.cpp:304-319`, `dialogs8.cpp:22-29`, `120-127`, `dialogs2.cpp:110-133`, `dialogs4.cpp:716-832` |
| texts for the core's panel (path, title, change-drive item) | UTF-8, no resource text | part B, table B.1 |

The complete list of dialog controls with a dynamic text is table C.1 of part C.

## 6. Proposal

### Steps (each one builds, can be probed and reviewed alone)

| Step | What | Sites | Risk |
|---|---|---|---|
| 0 | `LoadStrU8` next to `LoadStr` (`ftp.cpp:264`, `ftp.h:200`). Nothing else. | 2 lines | none |
| 1 | **Message boxes and static texts with a typed name or `GetErrorText`, no reply, no shared helper**: bookmark Remove / Rename / New (`dialogs1.cpp:1708`, `dialogs8.cpp:1028`, `1046` with `IDS_QUICKCONNECT`), proxy delete (`ftp2.cpp:2866`), type name not unique (`dialogs3.cpp:486`), the five save / export / import / read errors (`ctrlcon2.cpp:2067/2081`, `dialogs2.cpp:355/365`, `dialogs3.cpp:212/222`, `319/322/332`, `dialogs4.cpp:984/996`), the file-locked messages (`ctrlcon5.cpp:471-475`, `810-814`). | about 20 lines, all S | lowest; the pattern of the other plug-ins. Each unbounded `sprintf` becomes bounded + tail trim |
| 2 | **Sentences with a server reply or `FTPGetErrorText`**: `IDS_CHANGEWORKPATHERROR` (9 places: 7 of part B, `ctrlcon3.cpp:1242/1281`), `IDS_LISTPATHERROR`, `IDS_CREATEDIRERROR`, `IDS_QUICKRENAMEERROR`, `IDS_DOWNLOADFILEERROR` with its suffixes. Template `LoadStrU8`, the reply / error text through `SplLegacyToU8` first, the neighbouring `LoadStr` pieces to `LoadStrU8`. | about 17 places, M | the reverse rule; a reply converted to UTF-8 grows, so every one needs the tail trim. A small local helper "reply as UTF-8" keeps it uniform |
| 3 | **Wait windows**: `ctrlcon4.cpp:107/109`, `ctrlcon1.cpp:685/846/848/1523`, `ctrlcon2.cpp:350` (with the 20-byte host cut made whole-character), `ctrlcon3.cpp:74`. | 8 places, S-M | low; hard to see (the windows appear after a delay) |
| 4 | **Operation window lists**: item descriptions `IDS_OPERDOPDS_*` (`operats1.cpp:1164-1321`, 18 sites) and worker action (`operats3.cpp:455`). The state column and the worker status stay code page - they are separate cells, so this is safe alone. | 19 sites, S-M | low; the size text of the core must be checked or converted |
| 5 | **Code-page-only sinks made wide** (wrong in English too): `dialogs8.cpp:1120` + the five `IDS_CONNECTINGTOAS*` lines; `dialogs8.cpp:1220` + `ctrlcon1.cpp:1646`; `dialogs8.cpp:1218` (reply: wide with `A` fallback); `ssl.cpp:883` + `ssl.cpp:304`; `dialogs1.cpp:970`; the Logs combo `ctrlcon2.cpp:1472-1513` with its reader `dialogs2.cpp:688-690` and the two questions `ctrlcon2.cpp:2124/2153` (and its `buf[300]` overflow). | about 8 sinks, M | medium: sink and all its callers in one change. `dialogs1.cpp:970` changes what is **stored** in the address history (to the typed text) - PRIVACY.md is not touched (same data, same place) |
| 6 | **The connect error state machine** `ctrlcon1.cpp:640-1990` (`formatBuf` used as a second format, `GetFatalErrorTxt`, `IDS_WAITINGTORETRY*`) with `GetProxyError` (`sockets.cpp:883-1010`, eleven callers). | one function + one shared helper, L | highest of the screen work: a text returned through parameters into many callers; a format string that holds the host name (`%` in a host - not checked). Do it last and alone, with a review |
| 7 | **Server-type and proxy names**: `GetTypeNameForUser` / `UserDefinedSuffix` (`ftp2.cpp:794-803`, `ftp.cpp:318`) as UTF-8, its seven users (`dialogs3.cpp:289`, `432`, `477`, `dialogs1.cpp:1116`, A lists `ftp3.cpp:65/80`, `dialogs3.cpp:131`), the proxy combos (`ftp2.cpp:2692-2921`), the advanced-settings summary (`dialogs1.cpp:1045-1161`, 18 templates, the cut at byte 36), the empty-value cell (`dialogs3.cpp:895`). | L | medium; only users with their own server types or named proxies see it. The suffix is a stored global used by A sinks - all users in one change |
| 8 | **The log** - one decision, then mechanical: `CLogs::LogMessage` (`ctrlcon2.cpp:1799`) makes every appended message UTF-8 on its own (valid UTF-8 kept, anything else read as code page: `SplLegacyToU8Alloc`), and the 30 composed log templates with a name become `LoadStrU8` so that the message itself is not mixed (`IDS_LOGMSG*` in fs2 / fs5 / ctrlcon3 / operats4-b, the log headers `ctrlcon1.cpp:779-805`, `operats2.cpp:367-379`, `775-798`, `IDS_HIDDENPASSWORD` at `ftp2.cpp:1696`). The 85 plain texts need no change then. | 1 sink + 30 sites, L as a decision, S each | **changes the bytes of a saved log file and of the copied text** (today: mixed bytes; then: UTF-8, no BOM). The log limit `LogMaxSize` counts bytes (`ctrlcon2.cpp:1822-1828`) - a message grows. A message cut by `_TRUNCATE` loses its `\r\n`. Needs the maintainer's yes |
| - | **Not in this feature (core)**: `GetCommonFSOperSourceDescr` returns a mixed text - `fs4.cpp:650`, `929`, `fs5.cpp:41`, `operats2.cpp:367`, `680`, `dialogs5.cpp:285-290`. Already `specs/NEXT-WORK.md:280-283`. When the core's text is UTF-8: five `LoadStrU8` here, and in `dialogs5.cpp:688-696` a second load for the title (the progress bar draws `A`). | record | the three confirmation dialogs and the operation title - among the most visible defects - **stay wrong until the core changes** |

Steps 1-4 are the plain pattern (about 65 sites) and cover most of what a user sees with an ordinary
server. Steps 5-7 change sinks or shared helpers. Step 8 is the only way to a readable log.

### What must not be touched

- Everything sent to the server: `PrepareFTPCommand` and its `logBuf` copy (`ctrlcon2.cpp:44-213`),
  `FTPU8NameToServer`, the login script (`ProcessProxyScript` / `ExpandText` `ftp2.cpp:1688-1694`,
  `1921`, `1976` - only the `logBuf` side of `ftp2.cpp:1696` is display text), the user's command
  (`fs3.cpp:757-817`), `ListCommand`, the init commands, the constants `AUTH TLS` etc., the bytes for
  a proxy server.
- `FTPGetErrorText` itself and `FTPListingFieldToU8`: many callers rely on the encoding they return;
  convert at the place of use.
- Stored data: configuration and registry (`ftp.cpp:734-906`, `ftp2.cpp:725`, `2497`), the server-type
  export / import format (`ftp2.cpp:817-1432`), the histories, the raw listing saved to a file
  (`dialogs2.cpp:331-343`), stored replies that are parsed later (`ServerFirstReply`, `ServerSystem`,
  the welcome message).
- Identity keys compared byte-wise: the disk-cache names (`fs5.cpp:370-392`), the user part of the
  path (`MakeUserPart`, `fs2.cpp:80-149`), `strcmp(newPath, workPath)`.
- The log file and the clipboard text - until step 8 is decided.
- `ctrlcon2.cpp:1980-1987`: the filter text is modified in place - it stays `LoadStr`.
- Message-box captions (the operation title is also a caption at `dialogs6.cpp:580`, `718`),
  `AliasBtnNames` (`ctrlcon1.cpp:1115`, `fs3.cpp:50`), `TRACE` / call-stack texts.

### The three defects easiest to reach

1. **No server at all**: Connect to FTP Server, a bookmark named `Žluťoučký kůň`, button *Remove*
   (`dialogs1.cpp:1708`, Czech `Opravdu chcete odstranit záložku "%s"?`), *Rename*
   (`dialogs8.cpp:1028`, `Přejmenovat "%s" na` - a static text, window text readable by a probe),
   *New* (`dialogs8.cpp:1046`, the check box `&Kopírovat data ze záložky "%s"`). Step 1.
2. **Ordinary server, no error**: F5 on one file with an accented name from the FTP panel - the
   *Operations* list of the operation window, column Description (`operats1.cpp:1205-1232`, Czech
   `Kopírovat %s%s z %s do %s v %s režimu přenosu`) and the *Connections* list, column Action
   (`operats3.cpp:455`, `Kopíruji %s`). Step 4. The window must stay open (a large file, or the
   operation paused). Its title (`Kopírování %s z %s`) and the label of the F5 dialog
   (`Kopírovat %s z FTP serveru do`) are as visible but belong to the core item.
3. **Ordinary server, the simplest error**: F7 with an accented name that already exists
   (`ctrlcon5.cpp:590`, reply 550) - a message box. Step 2. In English already: connect with an
   accented user name and no password - the prompt `Connecting to "host" as "user"`
   (`dialogs8.cpp:1120`). Step 5.

### What an FTP probe needs

The Docker container `tandem-sftp` is SFTP only and Docker was not running at the time of the triage.
For FTP:

- A local server on 127.0.0.1 with an account, a writable folder with accented file and directory
  names, UTF-8 names, passive mode. Feature 099 drove the plug-in against `pyftpdlib`
  (`specs/099-move-into-archive-links/fix-log.md:134-140`); it is **not installed** now
  (`python -c "import pyftpdlib"` fails) - `pip install pyftpdlib`, or a server written with the
  standard library as in feature 116 (`specs/116-ftp-passwords/probe/ftplog_server.py`, today only
  USER / PASS / ACCT and a refusal).
- For step 2 and the reverse rule: a server whose **reply text can be chosen** - once ASCII, once
  UTF-8 with the name, once code-page bytes (1250) with the name - e.g. `550 <name>: file exists`. A
  small own server (or a `pyftpdlib` handler override) is needed; no ordinary server does the third.
- For the log (step 8): the same server in a "legacy" mode that lists names in code-page bytes, to see
  both forms of a logged command.
- For step 5: an account with an accented user name and a server that asks for the password
  (the prompt appears when no password is stored); for the certificate dialog an FTPS server with a
  self-signed certificate (`pyftpdlib` `TLS_FTPHandler` needs `pyOpenSSL`).
- For step 4: a large file or a speed limit so that the operation window stays open; the list-view
  cells can be read with `LVM_GETITEMTEXTW` from the probe, the title with `GetWindowTextW`.
- The plug-in's bookmarks are in the product's registry key - the probe must back it up and restore
  it (CLAUDE.md), and it shares the hidden desktop rules (no real keyboard or clipboard).
- Not drivable on the hidden desktop: the wait windows of step 3 (they appear after a delay and
  only on a slow server - the probe server needs a "slow answer" switch), Copy log to clipboard.

## Uncertainties

- **Not measured**: every verdict is from reading. In particular "garbled in English too" for the log
  and for the `A`-only sinks, and the stored mojibake of `dialogs1.cpp:970`.
- **Host name outside ASCII**: unreachable without a proxy is inferred from `sockets.cpp:745`; whether
  a host can hold `%` (format string from data, `ctrlcon1.cpp:1040`, `1984`) was not checked.
- **`User` / `Host` of an old bookmark** may be code-page bytes (0.1.8); the origin lines
  `fs2.cpp:535/632`, `fs5.cpp:795` were read by part B only as far as its table B.1 says.
- **Core texts not read**: the unit words of `PrintDiskSize` / `PrintTimeLeft` / `NumberToStr` (a piece
  of the item descriptions and of four log messages), the plural branch of
  `GetCommonFSOperSourceDescr`, the regular-expression error text (`parser3.cpp:325`), whether the
  information line falls back to the code page (`fs4.cpp:327-524`), what encoding `SplGetFileNameU8`
  expects for filter and title.
- **`SplU8ToW` in the list views** (`dialogs6.cpp:805`, `881`) gives 0 also when the text does not fit
  the cell buffer (`splunicode.h:241-254`: a failed conversion is not told apart from a small buffer) -
  a long valid UTF-8 cell text would then be shown through the code page. Read, not tried.
- **Grep-only ranges**: `ctrlcon2.cpp:610-780`, `842-1340`, most of `sockets.cpp`, `datacon1.cpp`,
  `datacon2.cpp`, parts of `dialogs1-4.cpp` were searched for `LoadStr` / `sprintf` / text calls, not
  read line by line; a composition without those tokens there would be missed.
- **`X509_NAME_oneline`** for a certificate subject outside ASCII (`ssl.cpp:558/561`): the one UNCLEAR
  row.
- The **translations** were sampled (Czech, about 40 templates), not read as a whole: whether a given
  template has a letter outside ASCII decides whether a defect shows in that language (Czech
  `Odstranit soubor %s z %s` is ASCII and works by accident; `Kopírovat ...` does not).
- The counts mix rows and sites and two parts name the same visible defect twice (the operation
  title: `dialogs5.cpp:285-290` and `operats2.cpp:680`; the type-name helper: `ftp2.cpp:799` and its
  users).

## Other defects seen (not fixed, candidates for `specs/NEXT-WORK.md`)

The full lists are at the end of each part. The ones that can lose or misdirect data:

- `operats6.cpp:1472-1479`: `targetPath[MAX_PATH]` filled with `lstrcpyn` and an unchecked
  `SalPathAppend`, then used as the **target directory** of new download items - a silently cut path.
- `fs2.cpp:466`, `623`, `724`, `fs5.cpp:841`: a typed remote path longer than `FTP_MAX_PATH` (301
  bytes) is cut silently, inside a character too; `MakeUserPart` clamps byte-wise and several callers
  ignore its FALSE (`fs3.cpp:276`, `752`, `fs5.cpp:505`, `614`, `fs4.cpp:700`, ...).
- `operatsa.cpp:810-814`: `sourcePath[MAX_PATH]` cut before use; `ctrlcon3.cpp:1104`, `1335`.
- `ctrlcon2.cpp:1472-1510`: unbounded `sprintf` chain into `buf[300]` (user 100 + host 200) -
  overflow; `ctrlcon1.cpp:678`, `740`, `906`, `932` into `formatBuf[300]`.
- `operats2.cpp:2465` and `sockets.cpp:914`: `*src >= ' '` on a signed `char` stops the copy of a
  reply at the first byte >= 0x80.
- `ssl.cpp:258` (`CP_ACP` on the UTF-8 host for the certificate's peer name), `ssl.cpp:926-932`
  (host widened byte by byte); `dialogs8.cpp:618/625`, `dialogs4.cpp:176-187` (`A` read = best fit on
  values that are stored or sent).
- `%ls` in a narrow format: only `ssl.cpp:215`, `337` (call-stack texts).

---

# 5. The tables (parts A-D, as written by the reading agents)


## Part A

### Scope: Part A - control connection, sockets, SSL

Files read: `ctrlcon1.cpp` 380-2248 (all `LoadStr` uses; lines 1-380 hold no `LoadStr`/`sprintf` - grep),
`ctrlcon2.cpp` 1-610, 780-842, 1340-2255 (610-780 and 842-1340: grep only - one plain log text at 1003,
`sprintf(ftpCmd, "%s\r\n", s)` at 1063), `ctrlcon3.cpp` 30-1604, `sockets.cpp` 15-45, 285-320, 730-760,
870-1051 (rest: grep only, no other `LoadStr`), `ssl.cpp` 150-985, `datacon1.cpp` 130-165, 350-380,
`datacon2.cpp` 250-280, 400-430 (rest of both: grep only - plain log texts and ASCII debug `sprintf`).
Outside the group, read for sinks/origins: `dialogs8.cpp` 20-59, 1070-1252, `dialogs2.cpp` 655-710, 930-1030,
`ftputils.cpp` 958-977, 3513-3526, `ftp2.cpp` 2168-2208, `fs5.cpp` 1250-1270, `operats6.cpp` 1035-1076,
`ctrlcon4.cpp` 596-645, `lang/lang.rc2` (the templates), `shared/splloadstru8.h`.

My grep finds 157 lines with `LoadStr(` in the seven files (the brief said about 190).

### Encodings met (additions / contradictions to the sub-brief)

- `Host`, `User` of the connection: copied from the caller in `SetConnectionParameters` (ctrlcon1.cpp:379-381);
  the origin (fs2.cpp:535/632, fs5.cpp:795) was **not read** - UTF-8 is *inferred* from dialogs8.cpp:33-44.
  The comment at dialogs8.cpp:1168-1172 says a user name saved by 0.1.8 may still be **code-page bytes** - so
  `User` (and probably `Host`, proxy fields) can be either encoding for an old bookmark. A fix should pass these
  pieces through `SplLegacyToU8` rather than assume UTF-8.
- A non-ASCII `host` cannot be resolved: `gethostbyname(Address)` gets the UTF-8 bytes (sockets.cpp:745). So
  every text composed **after** a successful resolve with the resolved `host` is in practice reachable only
  with an ASCII host (inferred, not proven); with a proxy the FTP host (`proxyScriptParams.Host`,
  `HostAddress`) is not resolved locally and stays reachable.
- `FTPGetErrorText` is in the **Windows display language** (FormatMessageA, ftputils.cpp:963), not the
  plug-in's: an English plug-in on a Czech/German Windows already has a code-page piece with accents.
- The date/time of the log header: `GetDateFormat`/`GetTimeFormat` A (ctrlcon1.cpp:764-768) = code page.
- `GetProxyTypeName` = `LoadStr` (ftp2.cpp:2168-2207) = code page (the names are ASCII in English).
- Login-script command text (`proxyLogCmdBuf`): built by `ProcessProxyScript` (ftp2.cpp, **not read**);
  `FTPU8NameToServer` is used only in ctrlcon2.cpp (grep), so the user name inside it is *inferred* to be the
  stored bytes (UTF-8).
- **The log is mixed by design, in every language**: the logged command is the server bytes
  (ctrlcon2.cpp:205-211 copies `buf`; CP_ACP when representable, ftputils.cpp:3521-3524) while the line
  "Changing path to" holds the UTF-8 path (ctrlcon3.cpp:1126). One accented, ACP-representable directory name
  gives a log with `CWD <ACP bytes>` and `Changing path to "<UTF-8>"` -> the whole log is not valid UTF-8 ->
  shown through the code page (ctrlcon2.cpp:1566-1573) -> the UTF-8 lines are garbled, English included.
  `LoadStrU8` templates alone do not repair the log; see group G6.

### Table

| file:line | template id(s) | pieces and their encodings | sink(s) and their encoding | verdict | fix and size |
|---|---|---|---|---|---|
| **G1 - StartControlConnection error/retry texts (one state machine, buffers `formatBuf`, `errBuf`, `buf`, `retryBuf`)** | | | | | |
| ctrlcon1.cpp:678, 740 | IDS_GETIPERROR (gives a second-level format, `%%s`) | template CP + `host` UTF-8 -> `formatBuf[300]`; later `%s` = `GetOperationFatalErrorTxt` (ctrlcon1.cpp:444: `FTPGetErrorText` CP / `LoadStr(IDS_UNKNOWNERROR)` CP) | used as format at ctrlcon1.cpp:1040 -> `buf` -> IDS_WAITINGTORETRYSUF (1061/1080) -> `waitWnd.SetText` 1064/1082 (UTF-8 or CP); and at 1984 -> `SalMessageBox` 1985 (UTF-8 or CP) | DEFECT - the host is garbled (template or Windows error text has an accent -> text not valid UTF-8) | L: `LoadStrU8` here; `e` converted with `SplLegacyToU8` before 1040 and 1984; 1037/1981 `LoadStrU8(opFatalErrorTextID)`; 1061/1080 `LoadStrU8`. Unbounded `sprintf` into `formatBuf[300]` (host up to 200 bytes) |
| ctrlcon1.cpp:906, 932 | IDS_OPENCONERROR (second-level format) | template CP + `host` UTF-8 + `inet_ntoa` ASCII + number -> `formatBuf[300]`; later `e` as above | same sinks (1040 -> wait window; 1984 -> message box); at 913 `formatBuf` is copied to `errBuf` and shown through `GetFatalErrorTxt` (1021/1026 wait window, 1948 -> LOG 1955 + `SalMessageBox` 1959) with the literal `%s` left in it | DEFECT (latent: needs a resolved non-ASCII host - in practice unreachable, inferred) | part of the L fix. Unbounded `sprintf`: English template ~67 + 200 + 15 + 5 bytes = at the edge of 300 |
| sockets.cpp:998-1007 (`GetProxyError`, `oneLineText` FALSE; caller ctrlcon1.cpp:901) | IDS_GETIPERROR, IDS_PROXYSENDREQERROR, IDS_PROXYRECVREPERROR, IDS_PROXYUNEXPECTEDREPLY, IDS_PROXYERRNOAUTHUNSUP, IDS_PROXYERRUSERPASSAUTHUNSUP, IDS_PROXYERRUSERPASSFAIL, IDS_PROXYERRLISTENUNSUP, IDS_PROXYOPENCONERROR | template CP + `HostAddress` (FTP host, UTF-8 - origin sockets.cpp:317/508, 508 not read) + number -> `formatBuf`; `errBuf` = `errText` (sockets.cpp:899-938: `LoadStr` CP / `FTPGetErrorText` CP / HTTP proxy reply, unknown) | ctrlcon1.cpp:1040 -> wait window; 1984 -> `SalMessageBox`; 913 -> `GetFatalErrorTxt` sinks | DEFECT for IDS_GETIPERROR and IDS_PROXYOPENCONERROR (the two with a host); the others RIGHT AS IT IS (no name) | part of the L fix (the helper is shared: only this `oneLineText == FALSE` branch feeds ctrlcon1) |
| ctrlcon1.cpp:1021, 1026 | IDS_WAITINGTORETRY, IDS_WAITINGTORETRY2 | template CP + `host` / `proxyScriptParams.Host` UTF-8 + `inet_ntoa` + number + `GetFatalErrorTxt` (ctrlcon1.cpp:439: `LoadStr` CP, or `errBuf` = server reply 1261 / proxy timeout `LoadStr` 886 / copy of `formatBuf` 913) | `buf` -> IDS_WAITINGTORETRYSUF 1061/1080 -> `waitWnd.SetText` 1064/1082 | DEFECT (IDS_WAITINGTORETRY2: reachable with a proxy and a non-ASCII FTP host; IDS_WAITINGTORETRY latent) | part of the L fix: `LoadStrU8` + last piece through `SplLegacyToU8` |
| ctrlcon1.cpp:1037-1040 | `opFatalErrorTextID`: IDS_SENDCOMMANDERROR, IDS_LISTCOMMANDERROR (ctrlcon4.cpp:643), IDS_ERRINPROXYSCRIPT, IDS_NOTFTPSERVERERROR, IDS_INCOMPLETEPRXSCR, IDS_LOGINERROR, IDS_SSL_ERR_CONNECT, or `formatBuf` | template CP + `e`: `FTPGetErrorText` CP / `LoadStr` CP / server reply / `retryMsg` of the callers (ctrlcon3.cpp:665/695, ctrlcon4.cpp:548, ctrlcon5.cpp:311/954/1020: reply, `LoadStr` or `FTPGetErrorText` - no name) / SSL text (ssl.cpp:673, ASCII) | 1061/1080 -> wait window | RIGHT AS IT IS when the template comes from a resource id (no UTF-8 piece); with `formatBuf` see the rows above | - |
| ctrlcon1.cpp:1061, 1080 | IDS_WAITINGTORETRYSUF | template CP + `buf` (the rows above) + numbers | `waitWnd.SetText` 1064/1082 (UTF-8 or CP) | DEFECT only through its `%s` (follows the rows above) | `LoadStrU8` once the pieces are UTF-8 (part of L) |
| ctrlcon1.cpp:1981-1985 | same ids as 1037, or `formatBuf` | as 1037-1040 | `SalMessageBox` 1985 | as 1037-1040 | part of L; `sprintf(buf[1000], f, e)` is unbounded but both pieces are < 300 |
| ctrlcon1.cpp:956/962 -> 981, 1948 -> 1955/1959, 1971 -> 1976 | `fatalErrorTextID` via `GetFatalErrorTxt`, or `e` alone | one text alone (CP, reply, or the `formatBuf` copy of 913) | LOG; `SalMessageBox` 1959 | RIGHT AS IT IS (no composition here; 913 case see above) | - |
| **G2 - connect/login wait windows** | | | | | |
| ctrlcon1.cpp:685 | IDS_GETTINGIPOFSERVER | template CP + `host` UTF-8 | `waitWnd.SetText` 686 (UTF-8 or CP) | DEFECT - host garbled when the template has an accent | S: `LoadStrU8`; unbounded `sprintf` into `buf[1000]` (fits) |
| ctrlcon1.cpp:846 | IDS_OPENINGCONTOSERVER | template CP + `host` UTF-8 + `inet_ntoa` + number | `waitWnd.SetText` 849 | DEFECT (latent: resolved non-ASCII host) | S |
| ctrlcon1.cpp:848 | IDS_OPENINGCONTOSERVER2 | template CP + `proxyScriptParams.Host` UTF-8 + number | `waitWnd.SetText` 849 | DEFECT (proxy + non-ASCII FTP host) | S |
| ctrlcon1.cpp:1523 | IDS_SENDINGLOGINCMD | template CP + `tmpCmdBuf` = login command text (user name inside; stored bytes, UTF-8 inferred) | `waitWnd.SetText` 1524 | DEFECT (inferred piece encoding) - user name garbled in the "Sending command" window | M: `LoadStrU8` + `SplLegacyToU8(tmpCmdBuf)` (encoding of an old bookmark's user is not certain) |
| ctrlcon2.cpp:350 | IDS_CLOSINGCONNECTION | template CP + `Host` UTF-8 cut to 20 bytes + "..." (341-345) | `waitWnd.SetText` 352 | DEFECT - and the cut inside a character makes the text invalid UTF-8 even with an ASCII template | M: `LoadStrU8` + cut at a whole character (`SplU8CopyTrunc`-like) |
| ctrlcon3.cpp:74 | IDS_SENDINGCOMMAND | template CP + `logCmd` = command as sent (CP_ACP when the name is representable, else UTF-8), cut to 299 bytes (ctrlcon3.cpp:69); callers of other groups may pass their own `logCmd` (not followed) | `WaitWnd.SetText` 75 (UTF-8 or CP) | DEFECT only for a name **not** representable in the code page (then UTF-8 name + CP template); RIGHT for a representable name (all CP) | M: `LoadStrU8` + `SplLegacyToU8(errBuf)`; trim torn tail after the 300-byte cut |
| **G3 - dialogs with a code-page-only sink** | | | | | |
| ctrlcon1.cpp:822, 1394, 1435, 1457 | IDS_CONNECTINGTOAS2 | template CP + `ProxyHost`/`Host` UTF-8 + `ProxyUser`/`User` UTF-8 | `CEnterStrDlg` -> `SetDlgItemText` A, IDT_CONNECTINGTOAS (dialogs8.cpp:1120) = CP only | DEFECT - host/user garbled **in every language**, English too | M: `LoadStrU8` + wide sink in dialogs8.cpp:1120 (`SetDlgItemTextW` of `SplDisplayTextToWAlloc`); buffer `connectingToAs` is `_snprintf_s(_TRUNCATE)` already - add `SplU8TrimTornTail` |
| ctrlcon1.cpp:1415 | IDS_CONNECTINGTOAS1 | template CP + `proxyScriptParams.Host` UTF-8 | `CEnterStrDlg` (title/text NULL) -> dialogs8.cpp:1120 CP only | DEFECT (non-ASCII host: proxy only, see above) | same fix as the row above |
| ctrlcon1.cpp:1646 | IDS_CONNECTINGTOAS1 | template CP + `proxyScriptParams.Host` UTF-8 | `CLoginErrorDlg` -> `SetDlgItemText` A, IDT_CONNECTINGTO (dialogs8.cpp:1220) = CP only | DEFECT (non-ASCII host: proxy only) | M: `LoadStrU8` + wide sink at dialogs8.cpp:1220 (other callers of the dialog pass their own text - another group) |
| ctrlcon1.cpp:1647 (`errBuf`) | - | server reply alone | IDE_SERVERREPLY, `SetDlgItemText` A (dialogs8.cpp:1218) | RIGHT AS IT IS (reply) | - |
| ctrlcon1.cpp:824, 1352, 1396, 1437, 1459 (title/text) | IDS_ENTER...TITLE / ...TEXT | resource text alone | dialogs8.cpp:1116/1118 A | plain, not a row | - |
| ssl.cpp:228, 249, 276, 296, 303-304 (`CheckCertificate`) | IDS_SSL_ERR_NOTYETVALID, IDS_SSL_ERR_EXPIRED | `GetErrorText` UTF-8 [+ "\n" + template CP, appended through `AddNewLine` ssl.cpp:196] | `errBuf` -> `CCertificateErrDialog` (ctrlcon1.cpp:1783, dialogs5.cpp:1289) -> `SetDlgItemText` A, IDT_CERTIFICATE_ERROR (ssl.cpp:883) = CP only. Other callers: ssl.cpp:618 (`errorBuf` of `EncryptSocket`: for the control connection shown by the same dialog; for data connections NULL/0), fs5.cpp:1262 and ctrlcon1.cpp:1804, dialogs5.cpp:1334 (text not shown) | DEFECT - the Windows error text is garbled on any Windows whose messages have accents, whatever the plug-in language; with both parts the text is mixed | M: `LoadStrU8` at 304 + `SetDlgItemTextW` at ssl.cpp:883 |
| **G4 - log header** | | | | | |
| ctrlcon1.cpp:786, 805 | IDS_LOGHEADER, IDS_RECONLOGHEADER | template CP + `Host` UTF-8 + `inet_ntoa` + numbers + date/time (A API, CP) | LOG (813) | DEFECT (latent: direct connection needs a resolved non-ASCII host) | M: `LoadStrU8` + date/time converted (`SplLegacyToU8`) |
| ctrlcon1.cpp:779, 798 | IDS_PRXSRVLOGHEADER, IDS_PRXSRVRECONLOGHEADER | template CP + `Host`, `User`, `ProxyServer->ProxyName`, `ProxyHost`, `ProxyUser` (UTF-8, typed) + `GetProxyTypeName` CP + `host` + `inet_ntoa` + numbers + date/time CP | LOG (813) | DEFECT - user, proxy name, proxy user garbled in the log | M: `LoadStrU8` + `GetProxyTypeName` text and date/time converted. But see G6 |
| **G5 - log management** | | | | | |
| ctrlcon2.cpp:1472-1513 (`AddLogsToCombo`) | IDS_FTPINLEFTPANEL, IDS_FTPINRIGHTPANEL, IDS_FTPNOTINPANEL, IDS_FTPDISCONNECTED, IDS_FTPOPERATION, IDS_OPERSTOPPED, IDS_FTPINACTIVE | number + `d->User` + `d->Host` (copies of the connection's, ctrlcon2.cpp:1352-1354, UTF-8) + one or two templates CP | `CB_ADDSTRING` A (1513) = CP only | DEFECT - user/host garbled in the combo of the Logs window in every language | M/L: `LoadStrU8` + `SendMessageW(CB_ADDSTRING)`; the reader dialogs2.cpp:688-690 (`CB_GETLBTEXT` A into `buf[300]`) must then read wide -> UTF-8 (other group's file). Unbounded `sprintf` chain into `buf[300]`: user 100 + host 200 + the rest **overflows** |
| ctrlcon2.cpp:2124, 2153 | IDS_CLEARLOGQUESTION, IDS_REMOVELOGQUESTION | template CP + `itemName` = the combo item read back with `CB_GETLBTEXT` A (dialogs2.cpp:690): the mixed bytes of the row above | `SalMessageBoxEx` 2131/2160 (UTF-8 or CP) | DEFECT - follows the combo | S once the combo row is fixed and dialogs2 hands over UTF-8 (`LoadStrU8`); `sprintf` into `buf[500]` unbounded (item < 300) |
| ctrlcon2.cpp:2067, 2081 | IDS_SAVELOGERROR | template CP + `GetErrorText` UTF-8 | `SalMessageBox` 2068/2082 (UTF-8 or CP) | DEFECT - the Windows error text garbled (or the template, never both right) | S: `LoadStrU8` (2 lines); `sprintf` -> `_snprintf_s` |
| **G6 - other log lines** | | | | | |
| ctrlcon3.cpp:1126 | IDS_LOGMSGCHANGINGPATH, IDS_LOGMSGREFRESHINGPATH | template CP + `path` UTF-8 | LOG (1127) | DEFECT | S for the line (`LoadStrU8` + `SplU8TrimTornTail`). For the log as a whole L: every message appended in `CLogs::LogMessage` (ctrlcon2.cpp:1799) would have to be normalised (`SplLegacyToU8Alloc` per message) so that commands (CP_ACP bytes), replies and CP templates do not turn the whole log to code page; that changes the bytes of the saved file (2034) and the clipboard text (2098, 2216) - a decision, not a mechanical fix |
| ctrlcon3.cpp:100-110 (`WriteUnexpReplyToLog`) | IDS_LOGMSGUNEXPREPLY | template CP + server reply | LOG | RIGHT AS IT IS (reply) | - |
| datacon1.cpp:151/156, datacon2.cpp:268/273 | IDS_LOGMSGUNABLETOCONPRX(2), IDS_LOGMSGUNABLETOOPEN(2) | template CP + `inet_ntoa` + number + `FTPGetErrorText` CP | LOG | RIGHT AS IT IS | - |
| datacon1.cpp:377, datacon2.cpp:426 | IDS_LOGMSGDATCONERROR | template CP + `errBuf` = `FTPGetErrorText` CP or `GetProxyError(oneLineText TRUE)` (next group) | LOG | RIGHT AS IT IS, except through the proxy text with a host (G7) | follows G7 |
| ssl.cpp:550, 598 | IDS_SSL_LOG_OSSL_CERT_VERIFY, IDS_SSL_LOG_ALGO | template CP + number / OpenSSL names ASCII | LOG | RIGHT AS IT IS | - |
| ssl.cpp:558, 561 | IDS_SSL_LOG_SUBJECT, IDS_SSL_LOG_ISSUER | template CP + `X509_NAME_oneline` (OpenSSL escapes non-ASCII as `\xNN` - inferred, library not read) | LOG | UNCLEAR (encoding of `X509_NAME_oneline` output for a non-ASCII subject not verified; ASCII is believed) | - |
| ssl.cpp:666 | IDS_SSL_ERR_CONNECT_LOG | template CP + number + `ERR_error_string` ASCII | LOG | RIGHT AS IT IS | - |
| ssl.cpp:673 | IDS_SSL_ERR_CONNECT_ERR | template CP + number + `name` ASCII | `errorBuf` -> ctrlcon1.cpp:1749 `errBuf` -> IDS_SSL_ERR_CONNECT at 1037/1981 (wait window, message box); operats6.cpp:1067 `ErrorDescr` (other group) | RIGHT AS IT IS | - |
| **G7 - proxy error, one line (`GetProxyError`, `oneLineText` TRUE)** | | | | | |
| sockets.cpp:952-953, 986 | IDS_PROXYERRGETIP, IDS_PROXYUNEXPECTEDREPLY, IDS_PROXYERROPENCON | template CP + `HostAddress` UTF-8 (inferred) [+ number] + `errText` (CP / HTTP proxy reply) | returned in `errBuf` to: datacon1.cpp:371 and datacon2.cpp:420 -> IDS_LOGMSGDATCONERROR -> LOG; ctrlcon4.cpp:582/1320, ctrlcon5.cpp:346/947, operats3.cpp:2242, operats7.cpp:146/969, operats8.cpp:877, operatsb.cpp:1629/1884 (other groups, sinks **not followed**) | DEFECT (proxy + non-ASCII FTP host + proxy error); UNCLEAR whether a data connection's `HostAddress` is the FTP host (datacon1.cpp:129 has a `FIXME` on it) | L: shared helper with eleven callers - the returned text becomes UTF-8 only if every caller's composition and sink follows |
| sockets.cpp:960-961, 967 | IDS_PROXYERRSENDREQ, IDS_PROXYERRRECVREP, IDS_PROXYERRUNABLETOCON2 | template CP + `errText` (`FTPGetErrorText` CP / `LoadStr` CP) | same callers | RIGHT AS IT IS | - |
| sockets.cpp:899, 936 | IDS_CONNECTIONLOSTERROR, IDS_UNKNOWNERROR, `ProxyWinError` as resource id | resource text alone into `errText` | piece of the rows above | plain piece | - |
| **Others** | | | | | |
| ctrlcon2.cpp:534-536, 570 | IDS_NONEREPLY; IDS_DCONLOSTFORMATERROR, IDS_LCONLOSTFORMATERROR, IDS_RCONLOSTFORMATERROR | template CP + `errBuf`: server reply (509/513), stored `ConnectionLostMsg` (524/549: an earlier `errBuf` of this function or `retryMsgBuf` of ctrlcon4.cpp:618 = reply / CP text), `LoadStr(IDS_NONEREPLY)` CP, `FTPGetErrorText` CP | `SalMessageBoxEx` 580 (UTF-8 or CP) | RIGHT AS IT IS (reply / CP pieces, no name) | - (`sprintf` into `buf[500]`, piece < 300) |
| ctrlcon3.cpp:688 | `opFatalErrorTextID`: IDS_NOTFTPSERVERERROR, IDS_SENDCOMMANDERROR, IDS_ABORTCOMMANDERROR | template CP + `e`: `FTPGetErrorText` CP / `LoadStr(IDS_UNKNOWNERROR)` / server reply | `SalMessageBox` 689 | RIGHT AS IT IS (reply) | - (`sprintf` into `buf[500]`, piece < 300) |
| ctrlcon3.cpp:646 -> 653/659/665; 677 -> 682; 695 | `fatalErrorTextID` via `GetFatalErrorTxt`, `e` alone | one text alone (CP or reply) | LOG; `SalMessageBox` 659; `retryMsg` to the callers -> ctrlcon1.cpp:635 `errBuf` (G1 row 1037) | RIGHT AS IT IS | - |
| ctrlcon3.cpp:817 | IDS_GETCURWORKPATHERROR | template CP + `replyBuf` server reply | `SalMessageBox` 818 | RIGHT AS IT IS (reply) | - |
| ctrlcon3.cpp:1242, 1281 | IDS_CHANGEWORKPATHERROR | template CP + `path` UTF-8 + `replyBuf` server reply (unknown encoding; a 550 reply usually repeats the path in the server's bytes) | `errBuf` -> `SalMessageBox` 1383 (UTF-8 or CP) | DEFECT - the path is garbled when the template has an accent or the reply holds non-UTF-8 bytes | M: `LoadStrU8` + `SplLegacyToU8(replyBuf)` + `SplU8TrimTornTail` (already `_snprintf_s(_TRUNCATE)`) |
| sockets.cpp:35 | IDS_WINSOCKETSERROR | template CP + `FTPGetErrorText` CP | `MessageBox` A (36) = CP | RIGHT AS IT IS | - |
| ctrlcon1.cpp:1115-1118 | IDS_WAITRETRESCABORTBTN, ...RETRYBTN, ...WAITBTN | numbers + three resource texts CP | `params.AliasBtnNames` -> `SalMessageBoxEx` 1120 | RIGHT AS IT IS (all CP, no name) | - |
| ctrlcon1.cpp:650 | IDS_PROXYSRVADREMPTY | `strcpy` overwritten by the `lstrcpyn` of line 651 | - | RIGHT AS IT IS (dead text) | - |

Counts: DEFECT 21 rows (of them 4 latent/"resolved non-ASCII host" only: 906/932, 846, 786/805, part of 1021),
RIGHT AS IT IS 17 rows (5 of them "reply"), UNCLEAR 1 row (ssl.cpp:558/561) plus one UNCLEAR remark inside G7.

### 1. How a person reaches each DEFECT

Marked **[ordinary]** = an ordinary FTP server, no error condition.

- **[ordinary]** ctrlcon1.cpp:1435 (IDS_CONNECTINGTOAS2 in the password prompt): connect (Connect to FTP Server, or
  `ftp://jiří@host` in the panel) with a user name with an accent and **no password** - the "Enter password"
  dialog shows `Connecting to "host" as "..."` garbled, in English too. 1457: the same when the server asks
  for an account (332). 822/1394: a SOCKS5/HTTP proxy with a proxy user and no proxy password.
- **[ordinary]** ctrlcon2.cpp:1472-1513 (Logs combo): connect with an accented user name (not anonymous), open the
  FTP Logs window (plug-in menu, Show Logs) - the item `1: user@host (...)` is garbled, English too.
  ctrlcon2.cpp:2124/2153: in that window Clear log / Remove log - the question repeats the item.
- **[ordinary]** ctrlcon3.cpp:1126 (log line "Changing path to"): enter a directory with an accented name, open
  the Logs window - garbled in a non-English language, and in English as soon as the same log holds the
  `CWD` line in code-page bytes (that is: the same step).
- **[ordinary]** ctrlcon1.cpp:1523 (IDS_SENDINGLOGINCMD): accented user name, non-English language, a server slow
  enough for the wait window to appear during `USER ...` (the window shows only after the delay
  `WAITWND_STARTCON`) - hard to see on a fast server.
- **[ordinary]** ctrlcon3.cpp:74 (IDS_SENDINGCOMMAND): non-English language, a command on a name that the code page
  cannot represent (e.g. a Greek or Chinese directory name on a Czech system), server slow enough for the wait
  window (delay `WAITWND_COMOPER`).
- **[ordinary]** ctrlcon2.cpp:350 (IDS_CLOSINGCONNECTION): needs a non-ASCII host - in practice unreachable
  without a proxy (the host cannot be resolved); with one: disconnect, wait window after the delay.
- **No server at all, error condition trivially made**: ctrlcon1.cpp:678/740 and 685 - connect to a host name
  with an accent (`ftp://žluťoučký.test`): the "Getting IP address of server" wait window (non-English
  language) and the error "Unable to get IP address of server ... Error: (11001) ..." (message box; with the
  retry setting first the retry wait window 1061) - host garbled in a non-English plug-in language **or** on a
  non-English Windows (the error text).
- Certificate dialog (ssl.cpp:228-304 -> ssl.cpp:883): FTPS (AUTH TLS) server with a self-signed or expired
  certificate, Windows display language with accents in its messages (Czech, German...) - the reason in the
  "certificate" dialog is garbled. An ordinary test FTPS server, no fault needed beyond the certificate.
- ctrlcon2.cpp:2067/2081 (IDS_SAVELOGERROR): Logs window, Save log to a place that cannot be written (read-only
  folder, file open elsewhere) on a Windows whose messages have accents, or with a non-English plug-in language.
- ctrlcon3.cpp:1242/1281 (IDS_CHANGEWORKPATHERROR): Change Directory (Shift+F7) to a path with an accent that
  does not exist (server error 550), non-English language or a server that repeats the path in non-UTF-8 bytes.
  Mode 1/3 hide some of these messages (ctrlcon3.cpp:1333, 1346) - the typed-path case shows it.
- Proxy rows (ctrlcon1.cpp:779/798 log header, 848, 1026, 1415, 1646; sockets.cpp:952/986/998): need a proxy
  server definition. Log header: a proxy whose **name** or user has an accent - then just connect and open
  the log (no error). The others: a non-ASCII FTP host through a SOCKS4A/5 or HTTP proxy, mostly with a proxy
  error.
- Latent (resolved non-ASCII host needed): ctrlcon1.cpp:786/805, 846, 906/932, 1021.

### 2. Texts that must NOT be touched

- Commands sent to the server: `PrepareFTPCommand` ctrlcon2.cpp:44-213 (`buf` is sent, `logBuf` is its copy,
  205-211); literals ctrlcon1.cpp:623, 947, 1482, 1828, 1839; the login-script command `proxySendCmdBuf`
  written at ctrlcon1.cpp:1513; the init commands `"%s\r\n"` ctrlcon1.cpp:2076 (sent 2078); keep-alive
  command ctrlcon2.cpp:1063; TELNET bytes ctrlcon3.cpp:240-259.
- The log bytes written to a file ctrlcon2.cpp:2034 (+ separator 2049) and to the clipboard ctrlcon2.cpp:2098,
  2216 - they change if the log's content is normalised (G6).
- ctrlcon2.cpp:1980-1987: the `LoadStr(IDS_SAVELOGFILTER)` buffer is **modified in place** (`|` -> 0) - must
  stay `LoadStr` (a `SplLoadStrU8` text must not be modified); 1993 `lpstrTitle`: what encoding
  `SplGetFileNameU8` expects for filter/title was not read.
- Stored replies used for server detection: `ServerFirstReply` ctrlcon1.cpp:1239-1242, `ServerSystem`
  ctrlcon1.cpp:2100; the welcome message ctrlcon1.cpp:1227, 1516, 1584.
- `ConnectionLostMsg` (ctrlcon2.cpp:562, ctrlcon4.cpp:618): stored text shown later at ctrlcon2.cpp:570.
- `params.AliasBtnNames` ctrlcon1.cpp:1115-1119 (a tab-separated protocol of the core).
- Bytes sent to a proxy server (sockets.cpp:1053 `ProxySendBytes` and its callers - not read, inferred).
- Message-box captions everywhere; `CALL_STACK_MESSAGE` / `TRACE` texts.

### 3. Other defects seen on the way (not to be fixed here)

- **Format string from data**: `formatBuf` holds the host and is used as a `printf` format (ctrlcon1.cpp:1040,
  1984; built at 678, 740, 906, 932 and sockets.cpp:998). A `%` in the host name would be read as a format
  directive. Whether a host can contain `%` was not checked.
- **Buffer overflow, unbounded `sprintf` with names**: ctrlcon2.cpp:1472-1510 into `buf[300]` (user up to 100 +
  host up to 200 + port + two resource texts); ctrlcon1.cpp:678, 740, 906, 932 into `formatBuf[300]` (host up
  to 200 + template; IDS_OPENCONERROR is at the edge already in English).
- Tight margins that depend on the length of a translation: ctrlcon3.cpp:688 and ctrlcon2.cpp:570 (`buf[500]`,
  piece < 300), ctrlcon3.cpp:817 (`errBuf[900]`, reply < 700), ssl.cpp:558/561 (`wsprintf` into `buffer[256]`
  with `name[200]`), ssl.cpp:666 (`sprintf` into `buffer[256]`).
- ssl.cpp:666: `ERR_error_string(err, name)` with `name[200]` - OpenSSL documents a buffer of at least 256
  bytes for this call (from the library's documentation, not read in the tree).
- **Name/text cut inside a character**: ctrlcon2.cpp:341-345 (host cut at 20 bytes); ctrlcon3.cpp:69 (command
  with a name cut at 299 bytes); `CopyStr` ctrlcon2.cpp:11-18 (replies cut by bytes into 300/700-byte
  buffers); ctrlcon3.cpp:103-104 (`WriteUnexpReplyToLog`); `_snprintf_s(_TRUNCATE)` without a whole-character
  trim at ctrlcon1.cpp:779-805, 822, 1021-1026, 1061, 1080, 1394-1457, 1523, 1646, ctrlcon3.cpp:74, 1126, 1242,
  1281, sockets.cpp:952-998.
- **A name used as such, copied with a smaller limit**: ctrlcon3.cpp:1104 and 1335
  `lstrcpyn(cutFileName, newPath, MAX_PATH)` (`newPath` is `FTP_MAX_PATH` = 301).
- **`A` API / code page on a name**: sockets.cpp:745 `gethostbyname` with the UTF-8 host (an accented host can
  never be resolved); ssl.cpp:258 `MultiByteToWideChar(CP_ACP, host)` on the UTF-8 host (peer name of the
  certificate check); ssl.cpp:926-932 host widened byte by byte (`*out++ = *host++`, sign-extended) - used as
  the peer name (ssl.cpp:262) and the title of the certificate viewer (ssl.cpp:355); ssl.cpp:166-169, 769
  `GetModuleFileName` / `LoadLibrary` A on the installation path; ctrlcon1.cpp:764-767 date/time A.
- `%ls` in a narrow format: ssl.cpp:215 and 337 (`CALL_STACK_MESSAGE` only).
- ctrlcon2.cpp:1973 `fileName[MAX_PATH]` for the UTF-8 name of the saved log (whether `SplGetFileNameU8`
  refuses a longer name was not read).
- dialogs2.cpp:688-690 (other group): the combo item read with `CB_GETLBTEXT` A.

### Plain uses (not rows)

- Plain `LoadStr` texts (message box text, caption, button, combo item, dialog title/text, wait window text
  alone): ctrlcon1.cpp about 30, ctrlcon2.cpp 21, ctrlcon3.cpp 7, sockets.cpp 7 (36, 972-981 into the proxy
  `errBuf`, 1037, 1044), ssl.cpp 2, datacon1.cpp 0, datacon2.cpp 0.
- Plain `LoadStr` texts **into the log**: ctrlcon1.cpp 6 (1594, 1788, 1795, 1806, 2001, 2026) + the error text
  alone at 981, 1955, 1976; ctrlcon2.cpp 4 (325, 379, 391, 1003) + 837; ctrlcon3.cpp 7 (333, 813, 973, 1499,
  1501, 1572, 1574) + 653, 682; ssl.cpp 6 (606, 611, 620, 625, 681, 851); datacon1.cpp 4 (239, 505, 1544,
  1813); datacon2.cpp 3 (361, 611, 1407). Each is code page with possible accents, appended to the same byte
  string as UTF-8 paths (G6).


## Part B

### Scope: Part B - listing, file system interface, configuration, parser

Files read: `ctrlcon4.cpp`, `ctrlcon5.cpp`, `fs1.cpp`, `fs2.cpp`, `fs3.cpp`, `fs4.cpp`, `fs5.cpp`, `ftp.cpp`,
`ftp2.cpp`, `ftp3.cpp`, `ftp4.cpp`, `menu.cpp`, `ftputils.cpp`, `parser1.cpp`, `parser2.cpp`, `parser3.cpp`
(all in `src/plugins/ftp`). Every `LoadStr(` line of these files was read with its context (241 lines;
`ftp3.cpp`, `menu.cpp`, `ftputils.cpp`, `parser1.cpp`, `parser2.cpp` have none). Whole functions were read
where a row lies; the rest of the files was searched for `sprintf` / `strcat` / message boxes / `A` sinks /
`IDS_` used without `LoadStr`, not read line by line. "inferred" marks what was not read.

Paths below are relative to `src/plugins/ftp` unless they start with `src/`.

### B.0 Two facts that change the picture

1. **The core's subject text is itself mixed.** `subjectSrc` / `dlgSubjectSrc` in `fs4.cpp` / `fs5.cpp` come
   from the core's `GetCommonFSOperSourceDescr` (`src/zip.cpp:3937-4007`): for one item it is
   `_snprintf_s(..., ::LoadStr(IDS_QUESTION_FILE / ...DIRECTORY / IDS_DLG_QUESTION_...), formatedFileName)`
   (`src/zip.cpp:3998-4000`) = a **code-page** core template around a **UTF-8** name; for several items it
   is `ExpandPluralFilesDirs(..., epfdmNormal, forDlgCaption)` (`src/zip.cpp:4004`) = code page only
   (the `u8` parameter is left at its default; default `FALSE` inferred from
   `specs/067-*/research.md:83`). This is the open item `specs/NEXT-WORK.md:280-283` and
   `specs/127-mixed-template-texts/research.md:59-63`. The plug-in then wraps it in its own code-page
   template (three layers).
2. **The log is one string, and a code-page template in it is enough to break every name.** Czech
   `IDS_HIDDENPASSWORD` is `skrytý` (`translations/czech/ftp.slt:1210`); `ExpandText` (`ftp2.cpp:1696`) puts
   it into the logged login command (`PASS (skrytý)`), and the login always runs through
   `ProcessProxyScript` (`ctrlcon1.cpp:645`; that every connection gets a `PASS` line this way is
   inferred, the script texts were not read). Together with the plain accented log templates (B.5) the
   log of a Czech session is practically never valid UTF-8, so the log window
   (`ctrlcon2.cpp:1566-1573`, `1609-1616`) shows the whole text through the code page and **every UTF-8
   name in it is garbled, whatever the single row does**. Fixing single log rows is only useful together
   with all the plain log texts (or with a normalisation of each message at `CLogs::LogMessage`, another
   group's file).

### B.1 (a) Texts the plug-in hands to the core, and their encoding

| What | Where | Composition | Encoding |
|---|---|---|---|
| current path / root path (user part) | `fs2.cpp:186-195` -> `MakeUserPart` `fs2.cpp:80-149` | `//` + `User` + `@` + `Host` + `:port` + `Path`, no resource text | UTF-8 (`User`, `Host` from the typed path `fs2.cpp:617-619` or from a bookmark `fs2.cpp:458-466`; bookmark fields are read with `ti.EditLine` = wide read, UTF-8 stored, `src/plugins/shared/winliblt.cpp:1296-1309`, `dialogs1.cpp:1035-1038`) |
| full FS path for a typed path | `GetFullFSPath` `fs2.cpp:197-273` (`fs2.cpp:233`, `257-262`) | `fsName:` + user part; the path is the decoded 257 reply | UTF-8 |
| full name of an item | `GetFullName` `fs2.cpp:275-290` | user part + `file.Name` | UTF-8 |
| change-drive menu / Disconnect dialog item | `GetChangeDriveOrDisconnectItem` `fs3.cpp:269-289` (core readers `src/drivelst.cpp:1965`, `src/dialogs6.cpp:1095`) | `\t` + `fsName:` + `//user@host[:port]`, no resource text | UTF-8 |
| main window title path | `GetPathForMainWindowTitle` `fs3.cpp:486-669` | directory name (`FTPCutDirectory` into `buf`, `fs3.cpp:497`) or `fsName:` + user part with `...` put in at separators (`fs3.cpp:644-651`), no resource text | UTF-8 |
| change-drive menu item of the plug-in | `ftp.cpp:922` | `LoadStr(IDS_FTPCHNGDRVITEM)` alone | code page (plain) |
| plug-in name / description | `ftp.cpp:339-345` | `LoadStr` alone | code page (plain; normalised at intake by the core per feature 052 - inferred, core not read) |
| menu items | `ftp.cpp:950-984` | `LoadStr` alone | code page (plain) |
| information line | `GetInfoLineContent` `fs4.cpp:291-526` | see rows B13, B14 | mixed |
| column names / descriptions | `fs4.cpp:115-133`, `fs3.cpp:1187-1191` | `LoadStdColumnStrName` / `...Descr` (`ftp4.cpp:158`, `290`) = code page, or the user's own `NameStr` / `DescrStr` (UTF-8 inferred: typed in a dialog, origin not read) - never composed | one or the other |
| security icon tool tip | `fs3.cpp:205-209`, `fs5.cpp:1264-1265` | `LoadStr` alone | code page (plain) |
| disk cache names | `fs5.cpp:370-392` | `fsName:` + full name; `nameInCache` = `file.Name` | UTF-8 |
| change notifications, panel path changes | `fs5.cpp:502-506`, `611-615`, `fs3.cpp:748-752`, `840-843`, `fs1.cpp:678-693` | `fsName:` + user part | UTF-8 |
| error title for `SalParsePath` | `fs4.cpp:975-978` | `LoadStr(IDS_FTPERRORTITLE)` alone | code page (plain) |
| operation subject stored in the operation | `oper->SetBasicData(dlgSubjectSrc, ...)` `fs4.cpp:696`, `fs4.cpp:1040`, `fs5.cpp:122`, `fs5.cpp:1085` -> `OperationSubject` (`operats2.cpp:155`), composed again at `operats2.cpp:367`, `680` (other part) | the core's text of B.0/1 | code-page word + UTF-8 name (one item), code page (several) |

The path shown in errors: the plug-in shows its own boxes (rows with `IDS_CHANGEWORKPATHERROR`,
`IDS_LISTPATHERROR`); the path piece there is `Path` / `workPath` / `path` = UTF-8. What the core shows on
`ChangePath` failure was not read.

### B.2 (b) `subjectSrc` in `fs4.cpp` / `fs5.cpp`

Not own code: `SalamanderGeneral->GetCommonFSOperSourceDescr` at `fs4.cpp:635-639` (Delete),
`fs4.cpp:923-927` (Copy / Move from FS), `fs5.cpp:35-39` (Change attributes), `fs5.cpp:1056-1069` (upload,
`dlgSubjectSrc` only). Encoding as in B.0/1. The plug-in's wrappers: `sprintf(subject,
LoadStr(IDS_DELETEFROMFTP), subjectSrc)` `fs4.cpp:650`; `LoadStr(copy ? IDS_COPYFROMFTP : IDS_MOVEFROMFTP)`
`fs4.cpp:929`; `LoadStr(IDS_CHANGEATTRSONFTP)` `fs5.cpp:41`. Controls: `IDT_DELSUBJECT`
(`dialogs4.cpp:1400-1407`), `IDT_TGTPATHSUBJECT` (`dialogs4.cpp:1361-1368`), `IDT_CHATTRSUBJECT`
(`dialogs4.cpp:1596-1603`) - each `SplU8ToWAlloc` -> `SetDlgItemTextW`, else `SetDlgItemText` A = "valid
UTF-8 or code page".

### B.3 Rows

Sink shorthand: **MB** = core `SalMessageBox` / `ShowMessageBox` (UTF-8 or code page); **LOG** = the log
(B.0/2); **WW** = `CListWaitWindow::SetText` `dialogs2.cpp:1295-1302` (UTF-8 or code page).
"reply" = server reply bytes, encoding unknown. cp = code page.

**Group G1 - `IDS_CHANGEWORKPATHERROR` (cs: `Nelze změnit cestu ... Cesta: %s\nOdpověď serveru: %s`), one fix pattern for all seven**

| file:line | template | pieces | sink | verdict | fix, size |
|---|---|---|---|---|---|
| `ctrlcon4.cpp:689` | IDS_CHANGEWORKPATHERROR | `path` UTF-8; `replyBuf` reply | MB `ctrlcon4.cpp:690` | DEFECT (path garbled) | `LoadStrU8` + reply -> `SplLegacyToU8`; **M** |
| `ctrlcon5.cpp:114` | same | `workPath` UTF-8; `replyBuf` reply | MB `ctrlcon5.cpp:115` | DEFECT | same, M |
| `ctrlcon5.cpp:535` | same | same | MB `ctrlcon5.cpp:536` | DEFECT | same, M |
| `ctrlcon5.cpp:711` | same | same | MB `ctrlcon5.cpp:712` | DEFECT | same, M |
| `fs2.cpp:224` | same | `path` UTF-8 (typed path from the core); `replyBuf` reply | MB `fs2.cpp:225` | DEFECT | same, M |
| `fs3.cpp:808` | same | `Path` UTF-8; `ftpReplyBuf` reply | MB `fs3.cpp:809` | DEFECT | same, M |
| `fs5.cpp:999` | same | `cutTgtPath` / `cutTgtPathIBMz_VM` UTF-8; `replyBuf` reply | MB (`ShowMessageBox`) `fs5.cpp:1001` | DEFECT | same, M |

All seven use `_snprintf_s(errBuf, _TRUNCATE, ...)` into `char errBuf[900 + FTP_MAX_PATH]` - bounded; add
`SplU8TrimTornTail`. A reply converted to UTF-8 can grow (up to 3x), the buffer is large enough for a
700-byte reply only when it is ASCII - the cut then needs the trim.

**Other rows**

| # | file:line | template(s) | pieces | sink | verdict | fix, size |
|---|---|---|---|---|---|---|
| B1 | `ctrlcon4.cpp:107` | IDS_LISTWNDDOWNLOADING (cs `Stahuji výpis ... z %s, stiskněte ...`) | `host` = `Host` UTF-8 by origin (B.1) | WW `ctrlcon4.cpp:110` | DEFECT, latent: shows only with a host name outside ASCII | `LoadStrU8`; **S** |
| B2 | `ctrlcon4.cpp:109` | IDS_LISTWNDDOWNLOADINGFILE (cs `Stahuji soubor %s z %s, stiskněte ESC ...`) | `fileName` UTF-8 (`file.Name`, `fs5.cpp:450`); `host` | WW `ctrlcon4.cpp:110` | DEFECT (name garbled) | `LoadStrU8` + `SplU8TrimTornTail` (`buf[500]`, `_TRUNCATE`); **S** |
| B3 | `ctrlcon4.cpp:184` | IDS_LOGMSGDATCONERROR | `errText` = `GetProxyTimeoutDescr` = a `LoadStr` text (`sockets.cpp:1037`, `1044`), cp | `errBuf` of `SendFTPCommand` (`ctrlcon3.cpp:342`), shown / logged there (other part; LOG inferred) | RIGHT AS IT IS (cp + cp) | - |
| B4 | `ctrlcon4.cpp:506` | IDS_LISTPATHERROR (cs accented) | `path` UTF-8; `replyBuf` reply | MB `ctrlcon4.cpp:508` | DEFECT (path garbled) | `LoadStrU8` + reply -> `SplLegacyToU8`; **M** |
| B5 | `ctrlcon4.cpp:556-600` | IDS_UNABLETOREADLIST + IDS_UNABLETOREADLISTSUFFIX / 2 / 3 / 4 | `replyBuf` = reply, or `LoadStr` text (`571`, `577`, `588`, `590`), or `GetProxyError` one-line text (`582`), or `FTPGetErrorText` (`583`) | MB `ctrlcon4.cpp:598` | RIGHT AS IT IS (reply) - no name; note: `GetProxyError` (`sockets.cpp:952-986`, other part) can carry `HostAddress` | - |
| B6 | `ctrlcon4.cpp:740-744` | IDS_UNABLETOREADLIST + IDS_UNABLETOREADLISTSUFFIX + IDS_ERRDATACONDECOMPRERROR | templates only | MB `ctrlcon4.cpp:744` | RIGHT AS IT IS | - |
| B7 | `ctrlcon4.cpp:1322` | IDS_LOGMSGDATCONERROR | `buf` = `GetProxyError` one-line (cp templates + `FTPGetErrorText` / HTTP reply + maybe `HostAddress`) | LOG `ctrlcon4.cpp:1323` | RIGHT AS IT IS by this template (cp + cp); depends on the `sockets.cpp` row | - |
| B8 | `ctrlcon5.cpp:320-369` | IDS_DOWNLOADFILEERROR (cs `Nelze stáhnout ... Název: %s\nCesta: %s`) + IDS_DOWNLOADFILEERRORSUFIX1 / 2 / 3 | `fileName`, `workPath` UTF-8; `replyBuf` = reply, or `LoadStr` text (`337`, `341`, `356`, `361`), or `GetProxyError` (`346`), or `FTPGetErrorText` (`350`) | MB `ctrlcon5.cpp:368` | DEFECT (name and path garbled) | both templates `LoadStrU8`; the five `LoadStr` pieces -> `LoadStrU8`; reply / `FTPGetErrorText` / `GetProxyError` text -> `SplLegacyToU8` once before line 367; **M** (one function, ~10 lines) |
| B9 | `ctrlcon5.cpp:440-448` | IDS_DOWNLOADFILEERROR + IDS_DOWNLOADFILEERRORSUFIX3 | `fileName`, `workPath` UTF-8; `replyBuf` = `FTPGetErrorText` (`443`) cp or IDS_UNKNOWNERROR (`445`) | MB `ctrlcon5.cpp:447` | DEFECT | templates `LoadStrU8`, error text converted; **M** |
| B10 | `ctrlcon5.cpp:471-475` | IDS_DOWNLOADFILEERROR + IDS_DOWNLOADFILEERRORSUFIX4 | `fileName`, `workPath` UTF-8 | MB `ctrlcon5.cpp:474` | DEFECT | two `LoadStrU8`; **S** |
| B11 | `ctrlcon5.cpp:590` | IDS_CREATEDIRERROR (cs accented) | `newName` UTF-8 (from the core's dialog); `replyBuf` reply | MB `ctrlcon5.cpp:591` | DEFECT (name garbled) | `LoadStrU8` + reply converted; **M** |
| B12 | `ctrlcon5.cpp:752`, `779` | IDS_QUICKRENAMEERROR (cs accented) | `fromName`, `newName` UTF-8; `replyBuf` reply | MB `ctrlcon5.cpp:753`, `780` | DEFECT x2 | `LoadStrU8` + reply converted; **M** |
| B12b | `ctrlcon5.cpp:810-814` | IDS_QUICKRENAMEFILEERR + IDS_QUICKRENAMEFILEERRSUF1 / 2 | `fromNameForSrv` (= `fromName` or its VMS form, `ctrlcon5.cpp:641-646`), `newName` UTF-8 | MB `ctrlcon5.cpp:814` | DEFECT | two `LoadStrU8`; **S** |
| B15 | `ctrlcon5.cpp:930-934` | IDS_PREPACTDATACONTIMEOUT or `GetProxyTimeoutDescr` text, then `"%s\r\n"` | one cp text + constant | LOG `ctrlcon5.cpp:934`; `retryMsg` returned to `ListWorkingPath` / `DownloadOneFile` (`ctrlcon4.cpp:428-453`, `ctrlcon5.cpp:165-191`) and on to the reconnect window (other part) | RIGHT AS IT IS (a plain text in the log) | - |
| B16 | `ctrlcon5.cpp:950` | IDS_LOGMSGDATCONERROR | `buf` = `GetProxyError` one-line | LOG `ctrlcon5.cpp:951` | RIGHT AS IT IS (as B7) | - |
| B17 | `ctrlcon5.cpp:995-997` | IDS_OPENACTDATACONERROR | `FTPGetErrorText` cp or IDS_UNKNOWNERROR | MB `ctrlcon5.cpp:997` | RIGHT AS IT IS | - |
| B18 | `ctrlcon5.cpp:1013`, `1016` | IDS_LOGMSGUNABLETOCONPRX2 / IDS_LOGMSGUNABLETOCONPRX | `inet_ntoa` ASCII, port, `errBuf` = `FTPGetErrorText` (`1008`) cp | LOG `ctrlcon5.cpp:1017` | RIGHT AS IT IS | - |
| B19 | `fs2.cpp:203` | IDS_LOGMSGCHANGINGPATH (cs `Změna cesty na "%s"...`) | `path` UTF-8 | LOG `fs2.cpp:204` | DEFECT | `LoadStrU8`; **S** (+ B.0/2) |
| B20 | `fs2.cpp:1078` | IDS_LOGMSGLISTINGCACHEDPATH / IDS_LOGMSGLISTINGPATH (cs `Výpis cesty "%s"...`) | `Path` UTF-8 | LOG `fs2.cpp:1079` | DEFECT | `LoadStrU8`; **S** (+ B.0/2) |
| B21 | `fs2.cpp:1264` | IDS_LOGMSGPARSEDBYSRVTYPE | `LastServerType` = server type name (`fs2.cpp:452`, `1202`, `1230`); built-in names ASCII (inferred), a user's own name UTF-8 (typed; origin `dialogs3.cpp:469-507` not read in full) | LOG `fs2.cpp:1265` | DEFECT, latent: only with a user-defined type name outside ASCII | `LoadStrU8`; **S** |
| B22 | `fs3.cpp:50-52` | `"%d\t%s\t%d\t%s"` + IDS_DISCONNECTBUTTON + IDS_KEEPCONBUTTON | templates + numbers | `params.AliasBtnNames` of `SalMessageBoxEx` `fs3.cpp:53` | RIGHT AS IT IS (unbounded `sprintf` into `buffer[100]`, see B.6) | - |
| B23 | `fs3.cpp:758-760` | IDS_LOGMSGSENDINGUSRCMD (cs `Odesílání příkazu uživatele "%s"...`) | `logBuf` = the typed command (`dlg.Command`, UTF-8: `dialogs8.cpp:33-60`, `172-184`) or IDS_SECRETFTPCOMMAND (cp) | LOG `fs3.cpp:760` | DEFECT, latent: only with a command outside ASCII (a path argument). With the secret text: cp + cp, right | `LoadStrU8` for both templates; **S**. Careful: `logBuf` also goes to `SendFTPCommand` (`fs3.cpp:817`) and to `CWelcomeMsgDlg` (`fs3.cpp:853` -> `dialogs2.cpp:90`, other part) |
| B24 | `fs4.cpp:327-328` | IDS_PLSTR_BLOCKSINSELFILES through `ExpandPluralString` | numbers only | core information line (`src/fileswnb.cpp:1003-1010` -> `CStatusWindow::SetText`, `src/stswnd.cpp:165` `SalU8ToWDisplayAlloc`: UTF-8, fall-back for other text inferred from `src/common/salunicode.h:105-107`) | RIGHT AS IT IS (no name; shown right only if the core falls back to the code page - not verified) | - |
| B13 | `fs4.cpp:336-524` (`AddStrAux` chain) | IDS_SRVTYPE_SIZEISDIR (`376`; en `DIR`, cs `ADR`) | `formatedFileName` UTF-8 (`356-359`); column texts from the listing UTF-8 (`426-429`); `GetDateFormat` / `GetTimeFormat` **A** texts cp (`403`, `408`, `449`, `476`); numbers | core information line (`src/fileswn2.cpp:1200`) | DEFECT, latent: name garbled only where the `DIR` word or the system's date / time text has a letter outside ASCII (not in en / cs) | `LoadStrU8(IDS_SRVTYPE_SIZEISDIR)`; date / time through `SplLegacyToU8` (or the W functions); **M** |
| B14 | `fs4.cpp:650` | IDS_DELETEFROMFTP (cs `Opravdu chcete odstranit %s z FTP serveru?` - ASCII) | `subjectSrc`: core cp template + UTF-8 name, or cp plural text (B.0/1) | `CConfirmDeleteDlg` -> `IDT_DELSUBJECT` `dialogs4.cpp:1400-1407` (W, else A) | DEFECT: name garbled when the plug-in's or the core's word has a letter outside ASCII (cs: file works by accident, directory - core word `adresář`, inferred - does not) | see B.4; **L** (needs the core's text as UTF-8) |
| B25 | `fs4.cpp:929` | IDS_COPYFROMFTP / IDS_MOVEFROMFTP (cs `Kopírovat %s z FTP serveru do`) | `subjectSrc` as B14 | `CCopyMoveDlg` -> `IDT_TGTPATHSUBJECT` `dialogs4.cpp:1361-1368` (W, else A) | DEFECT (name garbled in cs) | see B.4; **L** |
| B26 | `fs5.cpp:41` | IDS_CHANGEATTRSONFTP (cs `Změnit atributy z %s na`) | `subjectSrc` as B14 | `CChangeAttrsDlg` -> `IDT_CHATTRSUBJECT` `dialogs4.cpp:1596-1603` (W, else A) | DEFECT (name garbled in cs) | see B.4; **L** |
| B27 | `fs5.cpp:404` | IDS_LOGMSGVIEWCACHEDFILE / IDS_LOGMSGVIEWFILE (cs `Získávání souboru "%s" ...`) | `file.Name` UTF-8 | LOG `fs5.cpp:405` | DEFECT | `LoadStrU8` + trim (`logBuf[200 + MAX_PATH]`, `_TRUNCATE`); **S** (+ B.0/2) |
| B28 | `fs5.cpp:489` | IDS_LOGMSGCREATEDIR (cs `Vytváření adresáře "%s"...`) | `newName` UTF-8 | LOG `fs5.cpp:490` | DEFECT | `LoadStrU8` + trim; **S** |
| B29 | `fs5.cpp:540` (logged at `598`) | IDS_LOGMSGQUICKRENAME (cs `Přejmenování "%s" na "%s"...`) | `file.Name`, `newName` UTF-8 | LOG `fs5.cpp:598` | DEFECT | `LoadStrU8` + trim; **S** |
| B30 | `ftp.cpp:374-379` | `"%s " VERSINFO_VERSION "\n\n" VERSINFO_COPYRIGHT "\n\n%s"` + IDS_FTPPLUGINTITLE + IDS_PLUGINDESCR | templates; the constant holds `©` (`versinfo.rh2:18`, a UTF-8-BOM file) - compiled to the code page of the build (no `/utf-8` found in `ftp.vcxproj` or the shared property sheets; inferred) | MB `ftp.cpp:379` | RIGHT AS IT IS (inferred for the `©` byte) | - |
| B31 | `ftp2.cpp:799` (`GetTypeNameForUser`; suffix loaded at `ftp.cpp:318`) | `"%s %s"` + `UserDefinedSuffix` = IDS_SRVTYPEUSERDEF (cs `(definováno uživatelem)`) | `typeName` = user-defined server type name, UTF-8 (as B21) | `CB_ADDSTRING` A `ftp3.cpp:65`; `LB_ADDSTRING` A `ftp3.cpp:80` (cp only); further `dialogs1.cpp:1117`, `dialogs3.cpp:132`, `290`, `433`, `477` (other part, not read) | DEFECT, latent: a type name outside ASCII; in the two A lists the name is wrong already in English | suffix as UTF-8 + W messages at each sink; **L** (shared helper, 7 callers, the suffix is a stored global) |
| B32 | `ftp2.cpp:1696-1708` (`ExpandText`) | IDS_HIDDENPASSWORD (cs `skrytý`) put into `logBuf` | the script line, `Host`, `User`, `ProxyHost`, `ProxyUser` UTF-8 (`ftp2.cpp:1611-1658`) | `logCmdBuf` of `ProcessProxyScript` (`ftp2.cpp:1976-1978`) -> LOG in `ctrlcon1.cpp` / `operats2.cpp` (other part) | DEFECT: mixed with a user name outside ASCII; and by itself the reason of B.0/2 | `LoadStrU8`; **S** here, but see B.0/2 |
| B33 | `ftp2.cpp:2866` | IDS_WANTDELPRXSRV (cs `Opravdu chcete odstranit "%s" proxy server?` - ASCII) | `ProxyName` UTF-8 (`ti.EditLine(IDE_PRXSRV_NAME, ...)` `dialogs8.cpp:1662`) | MB `ftp2.cpp:2867` | DEFECT (cs works by accident; any language with an accented template garbles the name) | `LoadStrU8`, `sprintf` -> `_snprintf_s(buf, _TRUNCATE, ...)` + trim; **S** |
| B34 | `parser3.cpp:325` | IDS_STPAR_ERR_INVALREGEXP | `err` = the core's `GetLastErrorText` (`src/zip.cpp:3546` -> `RegExpErrorText`, `src/common/regexp.cpp:70`; cp inferred, the function body was not read) | `ErrBuf` -> `dialogs3.cpp:630-639`: wrapped in IDS_STPAR_UNABLECOMPAUTODCOND, MB | RIGHT AS IT IS (cp + cp) if the core's text is cp; UNCLEAR only in that one point | - |

Not rows but pieces of rows: `ftp2.cpp:2010` (`errDescrBuf` = one `LoadStr` text, shown by
`dialogs8.cpp:1582`, `ftp2.cpp:2466`, `ctrlcon1.cpp:646-661` - other part), `ftp2.cpp:2939`
(`GetProxyName`: either IDS_ADVSTRPROXYNOTUSED cp or `ProxyName` UTF-8, never both; composed at
`dialogs1.cpp:1054` with IDS_ADVSTRPROXYSRV - other part, a DEFECT candidate there),
`ftp2.cpp:2173-2203` (`GetProxyTypeName`, a `LoadStr` text; composed at `ctrlcon1.cpp:780`, `799`,
`operats2.cpp:776`, `792` with `ProxyName` - other part).

Counts of this part: **DEFECT 31 rows** (G1 7; the other 24: B1, B2, B4, B8, B9, B10, B11, B12 x2, B12b, B19, B20, B21,
B23, B13, B14, B25, B26, B27, B28, B29, B31, B32, B33), of them latent (need a non-ASCII host / type
name / command / locale word) 6: B1, B21, B23, B13, B31, B32; **RIGHT AS IT IS 12** (B3, B6, B7, B15,
B16, B17, B18, B22, B24, B30, B34 = 11, and B5 as "RIGHT AS IT IS (reply)"); **UNCLEAR 0** as a verdict (open points listed in
B.7).

Plain uses (not rows), lines per file: `ctrlcon4.cpp` 21 (+4 captions), `ctrlcon5.cpp` 9 (+11 captions),
`fs1.cpp` 6, `fs2.cpp` 12 (+1 caption), `fs3.cpp` 19 (+1 caption), `fs4.cpp` 10, `fs5.cpp` 19 (+1
caption), `ftp.cpp` 25 (+1 caption, +2 lines of the `LoadStr` definition), `ftp2.cpp` 22 (+1 caption; 9
more lines are `CSrvTypeColumn::LoadStr`, a parser of the column string, not a resource load),
`ftp4.cpp` 3, `parser3.cpp` 1.

### B.4 Fix of the three subject rows (B14, B25, B26)

The plug-in cannot repair the core's mixed text by conversion (a code-page word around a UTF-8 name is
neither). Two ways:
- with the core (NEXT-WORK 280-283): `GetCommonFSOperSourceDescr` returns UTF-8 (`LoadStrU8` + `u8 =
  TRUE` in the plural branch), then the three wrappers become `LoadStrU8` - **S** in the plug-in, but
  the same change is needed in Undelete (`src/plugins/undelete/dialogs.cpp:836`) and in
  `operats2.cpp:367`, `680` (the stored `OperationSubject`); outside the plug-in directory = not allowed
  by the brief of 130 -> **record**.
- plug-in only: for several items the core's text is pure code page -> `SplLegacyToU8` + `LoadStrU8`
  (**M**, right today already for that branch); for one item ask the core with `panel = -1` and an
  ASCII marker name, convert that text, put the real (formatted) name in place of the marker - **L**
  and fragile; not recommended.

All three use unbounded `sprintf(subject, ...)` into `char subject[MAX_PATH + 200]` with `subjectSrc`
up to `MAX_PATH + 99` bytes: safe only while the template is under 100 bytes (B.6).

### B.5 Plain `LoadStr` texts that go into the log

`ctrlcon4.cpp` 9 (`142`, `255`, `277`, `406`, `903`, `945`, `1085`, `1241`, `1258`), `ctrlcon5.cpp` 2
(`145`, `917`) + the one-text row B15 (`930-934`), `fs2.cpp` 1 (`1250-1252`), `fs3.cpp` 2 (`120`, `146`).
Each is code page; any of them with an accented letter turns the whole log to the code-page display
(B.0/2).

### B.6 List 1 - how a person reaches each DEFECT (ordinary server and no error = **[plain]**)

- B20 `fs2.cpp:1078` **[plain]**: enter a directory whose path has an accented letter, then *Show Logs*
  (plug-in menu / change-drive context menu): the line `Výpis cesty "..."`.
- B27 `fs5.cpp:404` **[plain]**: F3 on a file with an accented name, then the log.
- B28 `fs5.cpp:489` **[plain]**: F7 with an accented name, then the log.
- B29 `fs5.cpp:540` **[plain]**: F2 (quick rename) to or from an accented name, then the log.
- B19 `fs2.cpp:203` **[plain]**: type a relative path with an accented letter in *Change directory*
  (Shift+F7) while in the FTP panel (the core calls `GetFullFSPath`; exact trigger inferred), then the log.
- B25 `fs4.cpp:929` **[plain]**: F5 or F6 on one accented file in the FTP panel: the label above the
  target path.
- B26 `fs5.cpp:41` **[plain]**: Ctrl+F2 (*Change attributes*) on one accented file on a Unix-type
  listing: the label of the dialog.
- B14 `fs4.cpp:650` **[plain]**: F8 on one accented item with *Confirm file/directory delete* on: the
  question (cs: visible on a directory, or in a language whose template is accented).
- B2 `ctrlcon4.cpp:109` **[plain, timing]**: F3 on an accented file that takes longer than the wait-window
  delay to download (a large file or a slow link): the text of the list wait window. B1: the same on
  listing, only with a host name outside ASCII.
- B13 `fs4.cpp:336-524` **[plain, locale]**: put the cursor on an accented name; shows only in a language
  / regional format with a non-ASCII `DIR` word or date text.
- B11 `ctrlcon5.cpp:590`: F7 with an accented name that already exists (or in a read-only directory):
  server error 550 - easy on any server.
- B12 `ctrlcon5.cpp:752`, `779`: F2 an accented name to a name the server refuses (e.g. into a missing
  sub-path `x/y`, or without permission).
- B12b `ctrlcon5.cpp:810`: quick rename of a file that an operation (a running download of it) has locked.
- G1: `fs2.cpp:224` - Shift+F7 with a non-existent accented path while connected; `ctrlcon5.cpp:114` /
  `535` / `711`, `fs3.cpp:808` - the panel's directory (accented) was removed on the server, then F3 / F7 /
  F2 / *Send FTP Command* after a reconnect or with a changed working directory; `ctrlcon4.cpp:689` -
  the same during listing after a reconnect; `fs5.cpp:999` - F5 from disk to a typed accented target
  path that does not exist.
- B4 `ctrlcon4.cpp:506`: enter an accented directory the server refuses to list (no permission).
- B8 / B9 / B10 `ctrlcon5.cpp:320-475`: F3 on an accented file that cannot be downloaded (no read
  permission -> server reply; B9: the cache file cannot be created; B10: the file is locked by a
  running operation).
- B33 `ftp2.cpp:2866`: Configuration or Connect dialog -> proxy servers -> *Delete* on a proxy with an
  accented name, in a language whose template has an accented letter (not cs, not en).
- B21 `fs2.cpp:1264`, B31 `ftp2.cpp:799`: a user-defined server type with an accented name (Configuration
  -> Servers); B31 is the list there and the *Server type* combo of a bookmark, B21 the log after a
  listing parsed by it.
- B23 `fs3.cpp:758`: *Send FTP Command* with an accented argument, then the log.
- B32 `ftp2.cpp:1696`: any login (the `PASS (...)` line of the log); mixed only with an accented user name.

### B.6b List 2 - texts that must not be touched

- Commands to the server: `cmdBuf` from `PrepareFTPCommand` (`ctrlcon4.cpp:385`, `432`, `654`;
  `ctrlcon5.cpp:169`, `226`, `545`, `721`, `730`); the LIST command `listCmd` (`ctrlcon4.cpp:340-348`,
  sent and logged as it is, `495`); the user's command `cmdBuf` (`fs3.cpp:757-761`, sent raw at `817`);
  `sendCmdBuf` / `hostBuf` of `ExpandText` (`ftp2.cpp:1688-1694`, `1921`, `1976`) - only the `logBuf` side
  of `ftp2.cpp:1696` is display text.
- Registry / configuration: `ftp.cpp:734-906` (`SaveConfiguration`, `sprintf` at `746`, `758`, `852`,
  `865`, `1737`), `ftp2.cpp:725` (`CONFIG_STNAME`), `ftp2.cpp:2497` (`CONFIG_FTPPRXNAME`), the column
  string parser `CSrvTypeColumn::LoadStr` / `LoadFromStr` (`ftp2.cpp:145-260`).
- Files: server type export / import (`ftp2.cpp:817-909` `WriteStrToFile`, `ftp2.cpp:909`
  `"%s %s\r\n"` with `TypeName`, import `ftp2.cpp:1114-1432`).
- Identity keys compared byte-wise: `uniqueFileName` for the disk cache (`fs5.cpp:370-392`,
  `fs2.cpp:395-403`, `ftp.cpp:413-416`), `MakeUserPart` results used as paths (`fs2.cpp:80-149`),
  `strcmp(newPath, workPath)` (`ctrlcon4.cpp:667`, `ctrlcon5.cpp:99`, `520`, `696`, `fs3.cpp:790`, `837`).
- Generated names for the server (`ftputils.cpp:2652`, `2725`, `2853`, `3059`, `3135`, `3180`, `3262`).
- `FTPGetErrorText` itself (`ftputils.cpp:958-977`): many callers in other parts expect code page;
  convert at the place of use, not inside.

### B.6c List 3 - other defects seen (not to be fixed here)

- Path cut: `FTP_MAX_PATH` is 301 bytes (`ftp.h:23`); `lstrcpyn(Path + 1, path, FTP_MAX_PATH - 1)`
  `fs2.cpp:623`, `724`, `lstrcpyn(Path, server->InitialPath, FTP_MAX_PATH)` `fs2.cpp:466`,
  `lstrcpyn(tgtPath + 1, path, FTP_MAX_PATH - 1)` `fs5.cpp:841` cut a longer typed path silently, inside
  a character too; `lstrcpyn(newUserPart, userPart, FTP_USERPART_SIZE)` `fs2.cpp:717`, `fs5.cpp:729`.
- `MakeUserPart` (`fs2.cpp:80-149`) clamps each piece byte-wise (`92-94`, `100-102`, `133-135`); it returns
  FALSE then, but several callers ignore the result and use the cut text: `fs3.cpp:276`, `fs3.cpp:752`,
  `fs5.cpp:505`, `614`, `fs4.cpp:700`, `fs5.cpp:126`, `1089`, `fs1.cpp:678`, `692`. `GetRootPath` /
  `GetCurrentPath` write into `MAX_PATH` bytes (`fs2.cpp:189`, `194`).
- Name cut: `lstrcpyn(nameInCache, file.Name, MAX_PATH)` `fs5.cpp:384`; `lstrcpyn(newName, targetName,
  MAX_PATH)` `fs5.cpp:547`; `lstrcpyn(newName, cutDir / newPath, 2 * MAX_PATH)` `ctrlcon5.cpp:579`, `583`;
  `lstrcpyn(buffer, name, MAX_PATH)` `fs5.cpp:663` (mask test only); `char formatedFileName[MAX_PATH]`
  for `AlterFileName` `fs4.cpp:355-356` (size not passed - overflow possible if a name can be longer;
  the interface's limit was not checked).
- Reply as a path: `lstrcpyn(path, replyBuf, pathSize)` `fs2.cpp:233` (700-byte buffer for a path).
- `GetProxyName` cuts the name to `PROXYSRVNAME_MAX_SIZE` = 101 bytes (`ftp2.cpp:2948`,
  `dialogs1.cpp:1051-1052`) although the dialog stores up to 199 (`dialogs8.cpp:1619`, `1662`); and
  `dialogs1.cpp:1054-1056` cuts the composed text at byte 36 and appends `...`.
- `A` sinks with UTF-8 names (wrong already in English): proxy names `CB_ADDSTRING` /
  `CB_INSERTSTRING` `ftp2.cpp:2692`, `2815`, `2847`, `2898`, `2921`; server type names `ftp3.cpp:65`,
  `80` (B31). The bookmark list is right (`ftp3.cpp:304-319`).
- Unbounded `sprintf` into fixed buffers: `fs4.cpp:650`, `fs4.cpp:929`, `fs5.cpp:41` (`subject[MAX_PATH
  + 200]`, template + up to `MAX_PATH + 99` bytes); `ftp2.cpp:2866` (`buf[500]`, template + name up to
  199 bytes); `fs3.cpp:50` (`buffer[100]`, two translated button texts); `fs3.cpp:274` +
  `MakeUserPart(txt + strlen(txt), FTP_USERPART_SIZE, ...)` `fs3.cpp:276` (the size passed is the whole
  buffer's user-part size, not what is left; `txt` has 50 spare bytes, a long fs name is not expected);
  `fs2.cpp:257`, `fs3.cpp:646`, `660`, `750`, `fs4.cpp:698`, `fs5.cpp:124`, `503`, `612`, `1087`
  (`"%s:"` with the fs name - short).
- `_TRUNCATE` without a whole-character trim on texts with names: every G1 row, B2, B4, B8-B12b, B19,
  B20, B27-B29; and in the core `src/zip.cpp:3998` (the subject is cut at `MAX_PATH + 100` bytes - a torn
  tail makes the whole subject code page).
- `FTPGetErrorText` (`ftputils.cpp:962`): `sprintf(buf, "(%d) ", err)` is guarded only by `bufSize > 20`;
  `FormatMessage` A, so a system text outside the code page is lost.
- `GetDateFormat` / `GetTimeFormat` A in the information line (`fs4.cpp:403`, `408`, `449`, `476`); at
  `fs4.cpp:408` the time column is formatted with `GetDateFormat` (shows the date again - an old slip,
  not an encoding matter).
- No `%ls` in a narrow printf was found in these files.

### B.7 Open points

- Whether the core's information line shows non-UTF-8 text through the code page (B24, B13): only
  `src/stswnd.cpp:165` and the header comment were read.
- `SplU8ToWAlloc` returning NULL for invalid UTF-8 (the "W, else A" sinks of `dialogs4.cpp`): taken from
  the comments (`src/plugins/shared/splunicode.h:169`, `winliblt.cpp:1268-1273`), body not read.
- The plural branch of `GetCommonFSOperSourceDescr` being code page: `ExpandPluralFilesDirs` was not read.
- B30: the byte of `©` in the compiled constant depends on the compiler's execution character set.
- B34: the encoding of the core's regular-expression error text.
- B21 / B31: that a user-defined server type name and the columns' own names are stored as UTF-8
  (typed through `ti.EditLine`) was not followed to the dialog code.
- B3: where `SendFTPCommand` shows the `errBuf` filled by `IsTimeout` (`ctrlcon3.cpp:342-345`) belongs to
  another part.
- A host name outside ASCII (B1) is UTF-8 by origin, but whether such a host can be connected at all
  was not checked.


## Part C

### Scope: Part C - dialogs

Files: `src/plugins/ftp/dialogs1.cpp` ... `dialogs8.cpp`, `dialogs.h`. All line numbers are of the
working tree read on 2026-10-13. Nothing was built or run; every statement is from reading.

How it was read: `dialogs5.cpp`, `dialogs6.cpp`, `dialogs7.cpp`, `dialogs8.cpp` completely;
`dialogs1.cpp` 860-2229 completely, 1-860 through a grep of every text call (`LoadStr`, `SetWindowText`,
`SetDlgItemText`, `WM_SETTEXT`, `*_ADDSTRING`, `sprintf`, `strcat`, `SalMessageBox`, ...);
`dialogs2.cpp` 44-470, 915-1075, 1255-1670 completely, the rest through the same grep;
`dialogs3.cpp` 20-570, 615-934, 1425-1614 completely, the rest through the grep;
`dialogs4.cpp` 48-447, 466-1001, 1280-1709 completely, the rest through the grep.
Parts read only through the grep are the configuration pages with numbers, the log window procedure,
the wait-window procedure and the two `DialogProc`s of the server-type dialogs (no text call found there).

`LoadStr(` occurs on 233 lines: dialogs1 56, dialogs2 17, dialogs3 33, dialogs4 23, dialogs5 21,
dialogs6 5, dialogs7 15, dialogs8 62, dialogs.h 1 (a comment, `dialogs.h:497`).

### C.0 Facts established for this part

- `CTransferInfo::EditLine(id, char*, size)` towards the window (`src/plugins/shared/winliblt.cpp:1266-1293`):
  `SplU8ToWAlloc` -> `WM_SETTEXT` W, else `WM_SETTEXT` A. So every `ti.EditLine` sink is
  **"valid UTF-8, else code page" for the WHOLE string**. Reading back is wide -> UTF-8, refused when too long
  (`winliblt.cpp:1296-1319`). This is how names typed in dialogs become UTF-8 (bookmark name, server-type name,
  host, user, initial path, target path, init commands, proxy name/host/user, column ID, column empty value).
- Core `CStaticText::SetText` (`src/gui.cpp:626-629`): `SalU8ToW`, else `MultiByteToWideChar(CP_ACP)` - the
  fallback believed in the sub-brief is **verified**.
- Core progress bar text (`CProgressBar`, `src/gui.cpp:244-269`): `GetTextExtentPoint32` / `ExtTextOut` **A =
  code page only**.
- `GetTypeNameForUser` (`ftp2.cpp:794-803`): for a user-defined type returns `"<type name> <UserDefinedSuffix>"`;
  `UserDefinedSuffix` = `LoadStr(IDS_SRVTYPEUSERDEF)` copied at start (`ftp.cpp:318`) = **code page**; the type
  name is UTF-8 (typed through `CRenameDlg`, `dialogs8.cpp:1005`). The result is a mixed text by itself.
- `CFTPProxyServerList::GetProxyName` (`ftp2.cpp:2935-2950`): proxy name (UTF-8, typed `dialogs8.cpp:1662`) or
  `LoadStr(IDS_ADVSTRPROXYNOTUSED)` (code page).
- `Server->ListCommand` is **code page**, not UTF-8: read and written with A messages (`dialogs8.cpp:618`, `625`).
- Server-type column `NameStr` / `DescrStr` are **code page**: read and written with A calls
  (`dialogs4.cpp:176-177`, `185-187`). Column `ID` is ASCII by `IsValidIdentifier` (`dialogs4.cpp:25-48`);
  column `EmptyValue` is UTF-8 (`ti.EditLine`, `dialogs4.cpp:130`).
- `SentCommand` of `CWelcomeMsgDlg` in the "server reply" mode = `logBuf` of `fs3.cpp:755-757` = the command the
  user typed (UTF-8, `dialogs8.cpp:172-184`) or `LoadStr(IDS_SECRETFTPCOMMAND)` (code page) - it is NOT the
  `PrepareFTPCommand` log buffer here.
- No contradiction with the facts of the sub-brief was found. One addition: an A-only sink that receives a UTF-8
  name is wrong **in English too** (rows marked "also English").

### C.1 Sinks: dialog controls that show a dynamic text

"U8|CP" = set wide when the whole text is valid UTF-8, else through the A call (code page). "A" = A call only.
Column "today": is a UTF-8 text / a code-page text shown correctly.

| dialog class | control | what it shows (origin, encoding) | how it is set (file:line) | today UTF-8 / code page | verdict |
|---|---|---|---|---|---|
| CConnectDlg | IDL_BOOKMARKS (list box) | bookmark names `ItemName` (UTF-8) + first row `LoadStr(IDS_QUICKCONNECT)` | names: `ftp3.cpp:304-318` U8|CP per item, and `dialogs1.cpp:1277-1284` U8|CP; first row A `dialogs1.cpp:930`, `1245` | yes / yes | RIGHT AS IT IS |
| CConnectDlg | IDE_HOSTADDRESS, IDE_INITIALPATH, IDE_USERNAME | `s->Address`, `s->InitialPath`, `s->UserName` (UTF-8) | `ti.EditLine` `dialogs1.cpp:1035-1038` U8|CP; history combo `HistoryComboBox` `dialogs8.cpp:22-29`, `120-127` U8|CP | yes / yes | RIGHT AS IT IS |
| CConnectDlg | IDE_HOSTADDRESS on OK/Close with Quick Connect | `historyAddress` = `LastRawHostAddress` (UTF-8, read by `ti.EditLine` `dialogs1.cpp:1736`) without the password | `SetWindowText` **A** `dialogs1.cpp:970`; then read back wide and stored in the history (`dialogs1.cpp:974-976` -> `dialogs8.cpp:43-48`, `99-107`) | **no** / yes | **DEFECT (also English)**: an address with a non-ASCII user name or path is shown as mojibake and that mojibake is what goes to `Config.HostAddressHistory` (stored data, see list 2). Fix M: set wide (`SplU8ToWAlloc` + `SetWindowTextW`, A fallback). Not a `LoadStr` composition. |
| CConnectDlg | IDE_ADVANCEDINFO | the summary of advanced settings, see composition row C-1 | `ti.EditLine` `dialogs1.cpp:1161` U8|CP | only when all of it is one encoding | **DEFECT** (row C-1) |
| CConnectDlg | window title, IDC_SAVEPASSWORD_HINT | `LoadStr` alone | A `dialogs1.cpp:1337`, `1362` | - / yes | RIGHT AS IT IS (plain) |
| CConnectAdvancedDlg | IDE_TARGETPATH | `Server->TargetPanelPath` (UTF-8 local path) / path from the folder browser | `ti.EditLine` `dialogs8.cpp:545` U8|CP; `SetDlgItemTextW` with A fallback `dialogs8.cpp:912-919` | yes / yes | RIGHT AS IT IS |
| CConnectAdvancedDlg | IDC_SERVERTYPE (combo) | `LoadStr(IDS_SRVTYPEAUTODETECT)` + type names through `GetTypeNameForUser` (UTF-8 name + code-page suffix) | A `dialogs8.cpp:558`; names `CB_ADDSTRING` **A** in `ftp3.cpp:55-66` (other group's file) | **no** / yes | **DEFECT at the other group's line** (`ftp3.cpp:64`): a server type with a non-ASCII name is mojibake, also English. Here only the caller. |
| CConnectAdvancedDlg | IDC_LISTCOMMAND (combo with edit) | `Server->ListCommand` | `WM_SETTEXT` **A** `dialogs8.cpp:618`, read `WM_GETTEXT` **A** `dialogs8.cpp:625` | consistent code page (see C.0) | RIGHT AS IT IS as a pair (code page in, code page out), but see list 3 (A read = best fit on a text sent to the server) and row C-1 (it meets UTF-8 pieces there) |
| CConnectAdvancedDlg | IDE_INITFTPCOMMANDS | `Server->InitFTPCommands` (UTF-8) | `ti.EditLine` `dialogs8.cpp:640` U8|CP | yes / yes | RIGHT AS IT IS |
| CConnectAdvancedDlg | IDC_PROXYSERVER (combo) | proxy names | `proxyServerList->InitCombo` (`dialogs1.cpp:353-364` only calls it; body in `ftp2.cpp`, not read) | ? | UNCLEAR (body of `CFTPProxyServerList::InitCombo` is in another group's file; not read) |
| CRenameDlg | IDE_NAME | bookmark / server-type name (UTF-8) | `ti.EditLine` `dialogs8.cpp:1005` U8|CP | yes / yes | RIGHT AS IT IS |
| CRenameDlg | IDT_SUBJECT | `IDS_RENAMESRVTO` + name, row C-12 | `SetDlgItemTextW` with A fallback `dialogs8.cpp:1029-1036` U8|CP | only when all of it is one encoding | **DEFECT** (row C-12) |
| CRenameDlg | IDC_COPYFOCUSEDSRV (check box text) | `IDS_COPYDATAFROM` / `IDS_SRVTYPECOPYFROM` + name, row C-13 | U8|CP `dialogs8.cpp:1048-1055` | only when all of it is one encoding | **DEFECT** (row C-13) |
| CRenameDlg | title, IDT_SUBJECT (add bookmark), IDT_NEWNAME | `LoadStr` alone | A `dialogs8.cpp:1017`, `1021-1022`, `1064` | - / yes | RIGHT AS IT IS (plain) |
| CSendFTPCommandDlg | IDC_FTPCOMMAND, IDE_FTPCOMMAND_PASSWD | command + history (UTF-8) | `HistoryComboBox` U8|CP `dialogs8.cpp:172-181`; `ti.EditLine` `dialogs8.cpp:174`; swap wide `dialogs8.cpp:252-254` | yes / yes | RIGHT AS IT IS |
| CEnterStrDlg | title, IDT_STRING | `Title`, `Text`: `LoadStr` alone at every caller (`ctrlcon1.cpp:824`, `1352`, `1396`, `1437`, `1459`) | A `dialogs8.cpp:1116`, `1118` | - / yes | RIGHT AS IT IS (plain) |
| CEnterStrDlg | IDT_CONNECTINGTOAS | `ConnectingToAs` = `IDS_CONNECTINGTOAS1/2` (code page) + host and user (UTF-8), composed at `ctrlcon1.cpp:822`, `1394`, `1415`, `1435`, `1457` | `SetDlgItemText` **A** `dialogs8.cpp:1120` | **no** / yes | **DEFECT (also English)**: the user name (or host) with a letter outside ASCII is mojibake in the "enter password / user / account" dialog. Fix: wide sink here (S, `SplU8ToWAlloc` + `SetDlgItemTextW`, A fallback) **together with** `LoadStrU8` templates at the five `ctrlcon1.cpp` lines (other group). |
| CEnterStrDlg | IDE_STRING | host:port, user (UTF-8) or a secret | `ti.EditLine` / `FTPSecretEditLine` `dialogs8.cpp:1102-1104` U8|CP | yes / yes | RIGHT AS IT IS |
| CLoginErrorDlg | IDE_SERVERREPLY | `ServerReply`: the server's reply (`ctrlcon1.cpp:1622` `CopyStr(errBuf, reply)`) or a worker's `ErrorDescr` (`dialogs5.cpp:1277`, `operats3.cpp:737`; what the workers put there was not read - other group) | `SetDlgItemText` **A** `dialogs8.cpp:1218` | no / yes | RIGHT AS IT IS (reply) for a raw reply - but a UTF-8 reply (a server that answers in UTF-8, e.g. with the path in the text) is mojibake here while the same reply is readable in the log and in `CWelcomeMsgDlg`. Recommended with the neighbours: U8|CP (S). If a worker's `ErrorDescr` holds a composed text with a name: DEFECT - UNCLEAR until the other group's rows say what `ErrorDescr` holds. |
| CLoginErrorDlg | IDT_CONNECTINGTO | `ConnectingTo`: `IDS_CONNECTINGTOAS1` + host (`ctrlcon1.cpp:1646`) or `LoadStr(IDS_SOLVEERRSUBJECT)` alone (`dialogs5.cpp:1371`) | `SetDlgItemText` **A** `dialogs8.cpp:1220` | **no** / yes | **DEFECT (also English)** only for a host name outside ASCII (rare: host names are normally ASCII). Fix S: wide sink + U8 template in `ctrlcon1.cpp:1646`. |
| CLoginErrorDlg | title, IDC_RETRYWITHOUTASK, IDT_ERRORTITLE | `LoadStr` alone (`dialogs5.cpp:1372`) or NULL | A `dialogs8.cpp:1216`, `1222`, `1224` | - / yes | RIGHT AS IT IS (plain) |
| CLoginErrorDlg | IDE_USERNAME, IDE_PROXYUSER (+ secrets) | user names (UTF-8, or code-page bytes saved by 0.1.8 - comment `dialogs8.cpp:1168-1172`) | `ti.EditLine` `dialogs8.cpp:1175`, `1183` U8|CP | yes / yes | RIGHT AS IT IS |
| CProxyServerDlg | IDE_PRXSRV_NAME, _ADDRESS, _USER, _SCRIPT | proxy name, host, user, script (UTF-8) | `ti.EditLine` `dialogs8.cpp:1662`, `1687`, `1695`, `1716` U8|CP; script template `SetWindowText` A `dialogs8.cpp:1787` (ASCII constant / `GetProxyScriptText`, not read, inferred ASCII) | yes / yes | RIGHT AS IT IS |
| CWelcomeMsgDlg | window title (reply mode) | `IDS_SERVERREPLYTITLE` + the command, row C-3 | `SplSetWindowTitleW` with A fallback `dialogs2.cpp:91-98` U8|CP | only when all of it is one encoding | **DEFECT** (row C-3) |
| CWelcomeMsgDlg | IDE_WELCOMEMSG | welcome message / reply / raw listing (server bytes) | `SetDlgItemTextW` with A fallback `dialogs2.cpp:110-117`, `126-133` U8|CP | yes / yes | RIGHT AS IT IS (reply) |
| CLogsDlg | IDE_SERVERLOG, IDC_LISTOFLOGS | the log, the list of logs | `Logs.SetLogToEdit`, `Logs.AddLogsToCombo` (`dialogs2.cpp:418`, `453`, `458`; bodies `ctrlcon2.cpp`, other group) | see the sub-brief | not this part |
| CWaitWindow | the drawn text | `Text` set by callers in other files | `DrawTextW` with A fallback `dialogs2.cpp:1011-1023`, `1200-1207` U8|CP | yes / yes | sink RIGHT AS IT IS; the compositions are the callers' rows |
| CListWaitWindow | IDT_ACTION | `Text` (callers elsewhere; here only `LoadStr(IDS_LISTWNDDOWNLFILEABORTING)` alone, `dialogs2.cpp:1542`) | U8|CP `dialogs2.cpp:1302-1309`, `1446-1453` | yes / yes | RIGHT AS IT IS |
| CListWaitWindow | IDT_PATHONFTP2 | `Path` (UTF-8 remote path) | core static `SetText` `dialogs2.cpp:1322`, `1458` (U8|CP, `gui.cpp:626-629`) | yes / yes | RIGHT AS IT IS |
| CListWaitWindow | IDT_OPERSTATUS2, IDT_ELAPSEDTIME2, IDT_ESTIMATEDTIME2 | numbers, sizes, times + `LoadStr` | core static `SetText` `dialogs2.cpp:1597`, `1611`, `1651` | - / yes | RIGHT AS IT IS (numbers; row C-5) |
| CConfigPageServers | IDL_SUPPORTEDSERVERS (list box) | type names through `GetTypeNameForUser` (UTF-8 name + code-page suffix) | `LB_INSERTSTRING` **A** `dialogs3.cpp:131-132`; filling `LB_ADDSTRING` **A** `ftp3.cpp:75-81` (other group) | **no** / yes | **DEFECT (also English)** for a server type with a non-ASCII name. Fix M: per item `SplU8ToWAlloc` + W message, A fallback, and a UTF-8 suffix (see row C-7). |
| CEditServerTypeDlg | IDE_AUTODETECTCOND, IDE_PARSINGRULES | condition, rules (UTF-8 by `ti.EditLine`) | `ti.EditLine` `dialogs3.cpp:693-694` U8|CP; inserted pieces `EM_REPLACESEL` A with ASCII constants `dialogs3.cpp:1298`, `1465` | yes / yes | RIGHT AS IT IS |
| CEditServerTypeDlg | IDL_SRVTYPECOLUMNS (list view) | column ID (ASCII), name / description (`LoadStr` or code-page `NameStr` / `DescrStr`), type (`LoadStr`), empty value (UTF-8 `EmptyValue` or `LoadStr`), alignment (`LoadStr`) | all `ListView_InsertItem` / `ListView_SetItemText` **A** `dialogs3.cpp:860-907`; headers A `dialogs3.cpp:819-821` | name/descr: code page yes; **empty value: UTF-8 no** | **DEFECT (also English), small**: only the "empty value" column (`dialogs3.cpp:895`) can hold UTF-8 (a text column whose empty value has a non-ASCII letter). Fix S: that one cell wide. The rest RIGHT AS IT IS. |
| CEditSrvTypeColumnDlg | IDE_COL_ID, IDE_COL_EMPTY | ID, empty value (UTF-8) | `ti.EditLine` `dialogs4.cpp:123-125` U8|CP | yes / yes | RIGHT AS IT IS |
| CEditSrvTypeColumnDlg | IDC_COL_NAME, IDC_COL_DESCR (combos with edit) | `LoadStr` texts or `NameStr` / `DescrStr` | `CB_ADDSTRING` A `dialogs4.cpp:150-151`; `SetWindowText` **A** `dialogs4.cpp:176-177`; read `GetWindowText` **A** `dialogs4.cpp:185-187` | consistent code page | RIGHT AS IT IS as a pair; list 3 (A read = best fit; the value is stored and exported) |
| CSrvTypeTestParserDlg | IDE_PARSER_RAWLIST | the raw listing (bytes of a file or typed) | `SetDlgItemText` **A** `dialogs4.cpp:567`, `971`; read `GetWindowText` **A** `dialogs4.cpp:589` | no / yes | RIGHT AS IT IS (reply-like bytes, same A both ways) - noted: a UTF-8 listing loaded from a file is mojibake in the edit while the parsed list below shows the names right; and bytes the code page cannot map do not survive the round trip through the edit. Recorded, not a template composition. |
| CSrvTypeTestParserDlg | IDL_PARSER_RESULTS (list view, `HListView`) | headers: `LoadStr` or code-page `NameStr` (A, `dialogs4.cpp:623-629`); names `file.Name` (UTF-8); values | names `LVM_INSERTITEMW` with A fallback `dialogs4.cpp:716-725`; values `LVM_SETITEMTEXTW` with A fallback `dialogs4.cpp:822-832` | yes / yes | RIGHT AS IT IS |
| CCopyMoveDlg | title | `LoadStr(IDS_COPYTITLE / IDS_MOVETITLE)` alone (`fs4.cpp:941`) | `SetWindowText` A `dialogs4.cpp:1360` | - / yes | RIGHT AS IT IS (plain) |
| CCopyMoveDlg | IDT_TGTPATHSUBJECT | `Subject` composed at `fs4.cpp:928-929` (`IDS_COPYFROMFTP` + source description) | U8|CP `dialogs4.cpp:1361-1368` | only when all of it is one encoding | sink RIGHT AS IT IS; composition = other group's row (`fs4.cpp:929`) |
| CCopyMoveDlg | IDC_TGTPATH | target path (UTF-8) + core history | `SendMessageW(WM_SETTEXT)` with A fallback `dialogs4.cpp:1311-1318` | yes / yes | RIGHT AS IT IS |
| CConfirmDeleteDlg | IDT_DELSUBJECT | `Subject` composed at the caller (`fs4.cpp:663` area, other group) | U8|CP `dialogs4.cpp:1400-1407` | only when all of it is one encoding | sink RIGHT AS IT IS; composition = other group's row |
| CChangeAttrsDlg | IDT_CHATTRSUBJECT | `Subject` composed at the caller (`fs5.cpp:105` area, other group) | U8|CP `dialogs4.cpp:1596-1603` | only when all of it is one encoding | sink RIGHT AS IT IS; composition = other group's row |
| COperationDlg | window title | `TitleText` (`operats2.cpp:679-681`: `LoadStr(IDS_OPERDLG...TITLE)` + `OperationSubject` + `Host`) with a prefix, row C-10 | `SplSetWindowTitleW` with A fallback `dialogs5.cpp:296-313` U8|CP | only when all of it is one encoding | **DEFECT** (row C-10) |
| COperationDlg | IDT_OPSOURCETEXT, IDT_OPTARGETTEXT | `SourcePath`, `TargetPath` (UTF-8) | core static `SetText` in `operats2.cpp:696-703` (attached `dialogs6.cpp:79-80`) U8|CP | yes / yes | RIGHT AS IT IS |
| COperationDlg | IDT_OPSTATUS, IDT_OPTIMELEFT, IDT_OPELAPSEDTIME | numbers, sizes, times + `LoadStr` | core static `SetText` `dialogs5.cpp:623`, `646`, `651` | - / yes | RIGHT AS IT IS (numbers; row C-11) |
| COperationDlg | IDC_OPPROGRESS text | `LoadStr(IDS_OPERDLGTITLE_...)` alone | core progress bar `SetProgress(0, progressTxt)` `dialogs5.cpp:703` -> A draw `gui.cpp:261`, `269` | - / yes | RIGHT AS IT IS (plain) - **but it shares the pointer with the title** (`dialogs5.cpp:688-695`), see row C-10 |
| COperationDlg | IDT_OPERATIONSTEXT | the resource text read back (`dialogs6.cpp:92-96`, A) + two numbers | `SetWindowText` A `dialogs5.cpp:417-418` | - / yes | RIGHT AS IT IS |
| COperationDlg | IDL_CONNECTIONS, IDL_OPERATIONS (list views) | texts from `WorkersList->GetListViewDataFor` / `Queue->GetListViewDataFor` (other groups) | `LVN_GETDISPINFOW`: `SplU8ToW`, else `CP_ACP` `dialogs6.cpp:786-813`, `865-889`; headers A `dialogs5.cpp:769-779` | yes / yes per cell | sink RIGHT AS IT IS; the compositions are the other groups' rows |
| COperationDlg | list-view tooltips | the same cell text | `TTM_SETTOOLINFOW` with A fallback `dialogs7.cpp:1185-1200` | yes / yes | RIGHT AS IT IS (width measured with an A call, list 3) |
| COperationDlg | IDT_ERRORMSG hint | `IDS_LOWDISKSPACEONTGTPATH` + three sizes | core hyper link `SetActionShowHint` `dialogs6.cpp:381-383` | - / yes | RIGHT AS IT IS (numbers; row C-11) |
| COperationDlg | buttons IDB_PAUSERESUME, IDB_OPCONSPAUSERESUME, IDCANCEL, IDB_SHOWDETAILS | `LoadStr` alone / resource text read back | A `dialogs5.cpp:1034`, `1070`, `1123`; `dialogs6.cpp:1331`, `1367` | - / yes | RIGHT AS IT IS (plain) |
| CSolveItemErrorDlg | IDE_SCRD_SRCPATH, _SRCNAME, _TGTPATH, _TGTNAME | `FtpPath`, `FtpName` (UTF-8 remote), `DiskPath`, `DiskName` (UTF-8 local) | `ti.EditLine` `dialogs7.cpp:208-218` U8|CP | yes / yes | RIGHT AS IT IS |
| CSolveItemErrorDlg | IDE_SCRD_DETAILS | one of: `LoadStr(IDS_SIED_DETAIL1/2)` alone; `FTPGetErrorText(WinError)` alone (code page, `dialogs7.cpp:189`); `ErrDescription` copied (`dialogs7.cpp:193`) = `errDescrBuf` of `operats1.cpp` (a `LoadStr` alone at `operats1.cpp:1978`, or the item's `ErrAllocDescr`, a server reply or a text composed by the workers - other group) | `ti.EditLine` `dialogs7.cpp:202` U8|CP | yes / yes when it is one encoding | sink RIGHT AS IT IS; no composition in this file. What `ErrAllocDescr` holds = other group's rows. |
| CSolveItemErrorDlg | title | `LoadStr(IDS_SIED_TITLEn)` alone | A `dialogs7.cpp:452` | - / yes | RIGHT AS IT IS (plain) |
| CSolveItemErrUnkAttrDlg, CSolveItemSetNewAttrDlg | IDE_SCRD_SRCPATH, _SRCNAME | `Path`, `Name` (UTF-8 remote) | `ti.EditLine` `dialogs7.cpp:592-593`, `790-791` U8|CP | yes / yes | RIGHT AS IT IS |
| CSolveItemErrUnkAttrDlg, CSolveItemSetNewAttrDlg | IDE_SCRD_CURATTR, IDE_SCRD_NEWATTR | `OrigRights` (a listing field, UTF-8 by the parser; normally ASCII) or `LoadStr(IDS_OPERDOPPR_UNKEXISTATTR)` alone; new rights string + `" (%03o)"` (ASCII) | `ti.EditLine` `dialogs7.cpp:597`, `601`, `795` U8|CP | yes / yes | RIGHT AS IT IS |
| CSolveLowMemoryErr | IDE_SCRD_SRCPATH, _SRCNAME | path, name (UTF-8) | `ti.EditLine` `dialogs7.cpp:911-912` U8|CP | yes / yes | RIGHT AS IT IS |
| CSolveItemErrorSimpleDlg | IDE_SISE_PATH, IDE_SISE_NAME | path, name (UTF-8) | `ti.EditLine` `dialogs7.cpp:1416-1417` U8|CP | yes / yes | RIGHT AS IT IS |
| CSolveServerCmdErr | IDE_SSCD_PATH, IDE_SSCD_NAME | path, name (UTF-8; for upload items the disk path and name) | `ti.EditLine` `dialogs7.cpp:1609-1611` U8|CP | yes / yes | RIGHT AS IT IS |
| CSolveServerCmdErr | IDE_SSCD_ERRDSCR | `ErrorDescr` = `errDescrBuf` composed in `operats1.cpp` (other group) | `ti.EditLine` `dialogs7.cpp:1612` U8|CP | only when all of it is one encoding | sink RIGHT AS IT IS; composition = other group's rows |
| CSolveServerCmdErr2 | IDE_SSCD_SRCPATH/_SRCNAME/_TGTPATH/_TGTNAME | remote and disk path / name (UTF-8) | `ti.EditLine` `dialogs7.cpp:1720-1730` U8|CP | yes / yes | RIGHT AS IT IS |
| CSolveServerCmdErr2 | IDE_SSCD_ERRDSCR | `ErrorDescr` = `errDescrBuf` (`operats1.cpp`, other group) | `ti.EditLine` `dialogs7.cpp:1732` U8|CP | only when all of it is one encoding | sink RIGHT AS IT IS; composition = other group's rows |
| CSolve* (all) | titles | `LoadStr(TitleID)` alone | A `dialogs7.cpp:926`, `1516`, `1625`, `1745` | - / yes | RIGHT AS IT IS (plain) |
| FTPShowPasswordOfEdit | message box | `IDS_PASSWORDIS` + the password | composed wide (`LoadStrW`), handed as UTF-8 `dialogs1.cpp:2198-2213` | yes | RIGHT AS IT IS (done in feature 116) |

Sink verdicts: DEFECT 10 (CConnectDlg host address on OK, CConnectDlg advanced summary, CRenameDlg subject,
CRenameDlg check box, CEnterStrDlg "connecting to", CLoginErrorDlg "connecting to", CConfigPageServers list,
CEditServerTypeDlg empty-value cell, CWelcomeMsgDlg title, COperationDlg title - the four with a composition are
counted again as rows in C.2), plus one DEFECT located in another group's file (`ftp3.cpp:64`); UNCLEAR 1
(proxy combo, body not in my files); CLoginErrorDlg reply = RIGHT AS IT IS (reply) with a recommendation.

**For the solve-error dialogs of dialogs7.cpp the conclusion is: no UTF-8 name or path goes into an A-only
control.** Every name, path and error text there goes through `ti.EditLine` (wide when the whole text is valid
UTF-8). What can be wrong there is only the *content* of `ErrorDescr` / `ErrDescription`, composed in
`operats*.cpp`.

### C.2 Compositions of a resource text with a non-constant text (sites in my files)

| # | file:line | template id(s) | pieces and their encodings | sink(s) and encoding | verdict | fix and size |
|---|---|---|---|---|---|---|
| C-1 | `dialogs1.cpp:1045-1161` (one buffer `buf[300]`, pieces through `num[100]` and `AddToAdvancedStr` `dialogs1.cpp:983-993`): templates at 1054, 1064, 1073-1079, 1086, 1090, 1096, 1100, 1106, 1110, 1116, 1125, 1132, 1136, 1140, 1146, 1154 | `IDS_ADVSTRPROXYSRV`, `IDS_ADVSTRPORT`, `IDS_ADVSTRTRMOD*`, `IDS_ADVSTRSERVERPASV*`, `IDS_ADVSTRKEEPALIVE*`, `IDS_ADVSTRMAXCONCURCON`, `IDS_ADVSTRUNLIMITEDCON`, `IDS_ADVSTRSPEEDLIM`, `IDS_ADVSTRUNLIMITEDSPEED`, `IDS_ADVSTRSERVERTYPE`, `IDS_ADVSTRTARGETPATH`, `IDS_ADVSTRUSECACHE*`, `IDS_ADVSTRSSLCONTR*`, `IDS_ADVSTR*MODEZ`, `IDS_ADVSTRLISTCOMMAND`, `IDS_ADVSTRINITFTPCMDS` | templates: code page. Proxy name: UTF-8 or `LoadStr(IDS_ADVSTRPROXYNOTUSED)` code page (`ftp2.cpp:2939`). Server type: UTF-8 name + code-page suffix (`ftp2.cpp:799`). `TargetPanelPath`: UTF-8 local path. `ListCommand`: code page (C.0). `InitFTPCommands`: UTF-8. Numbers. All joined with `", "` into ONE text. | `ti.EditLine(IDE_ADVANCEDINFO)` `dialogs1.cpp:1161`, U8|CP for the whole text | **DEFECT**: one non-ASCII template anywhere in the line (e.g. a translated "passive mode") makes the whole line code page, so the proxy name / target path / server type in it is garbled. Second cause, **also English**: each piece is cut at byte 36 and `"..."` is written there (`dialogs1.cpp:1050-1056`, `1114-1119`, `1124-1127`, `1145-1148`, `1153-1156`) - a cut inside a UTF-8 character makes the whole line invalid UTF-8, so every name in it is garbled. | **L**: all 18 template lines -> `LoadStrU8`; UTF-8 variants of the two helpers' texts (`GetProxyName`'s "not used", `UserDefinedSuffix`) - both live in other groups' files and are used elsewhere; `ListCommand` -> `SplLegacyToU8`; the cut at byte 36 -> a cut at a whole character (`SplU8TrimTornTail` before the dots). `IDS_ADVSTRNONE` alone (`dialogs1.cpp:1160`) may stay. |
| C-2 | `dialogs1.cpp:1708` | `IDS_REMOVECONFIRM` | template code page; `s->ItemName` UTF-8 (bookmark name) | `SalMessageBoxEx` `dialogs1.cpp:1717-1718` (U8|CP) | **DEFECT**: the bookmark name is garbled when the template has a non-ASCII letter | **S**: `LoadStrU8`; unbounded `sprintf` into `buf[200 + BOOKMARKNAME_MAX_SIZE]` -> `_snprintf_s(_TRUNCATE)` + `SplU8TrimTornTail` |
| C-3 | `dialogs2.cpp:90` | `IDS_SERVERREPLYTITLE` | template code page; `SentCommand` = the typed command, UTF-8 (`fs3.cpp:755-757`), or `LoadStr(IDS_SECRETFTPCOMMAND)` code page when "secret" | window title, `SplSetWindowTitleW` with A fallback `dialogs2.cpp:91-98` (U8|CP) | **DEFECT**: a command with a non-ASCII argument (`MKD <name>`, `CWD <path>`) is garbled in the title when the template has a non-ASCII letter | **S** here: `LoadStrU8` + `SplU8TrimTornTail(buf)` (`buf[300]`, a command is up to 300 bytes, `_TRUNCATE` can tear). Reverse rule: the "secret" placeholder at `fs3.cpp:757` (other group; the same buffer also goes to the log there) must then be UTF-8 for this use, or converted here with `SplLegacyToU8`. |
| C-4 | `dialogs2.cpp:355`, `365` | `IDS_RAWLISTSAVEERROR` | template code page; `SalamanderGeneral->GetErrorText(err)` UTF-8 | `SalMessageBox` `dialogs2.cpp:356`, `366` (U8|CP) | **DEFECT**: the Windows error text is garbled (localized Windows + non-ASCII template) | **S**: `LoadStrU8`; unbounded `sprintf` into `buf[200 + MAX_PATH]` -> `_snprintf_s` |
| C-5 | `dialogs2.cpp:1577`, `1582`, `1589`, `1592` | `IDS_LISTWNDDOWNLOADSPEED`, `IDS_LISTWNDCONNECTIONIDLE`, `IDS_LISTWNDSTATUS1/2` | templates code page; `PrintDiskSize` / `PrintTimeLeft` texts of the core (numbers with a unit; encoding of the unit words not read - inferred ASCII or code page) | core static `dialogs2.cpp:1597` (U8|CP) | RIGHT AS IT IS (numbers only, never meets a name) | - |
| C-6 | `dialogs3.cpp:212`, `222` | `IDS_SRVTYPEEXPORTERROR` | template code page; `GetErrorText(err)` UTF-8 | `SalMessageBox` `dialogs3.cpp:213`, `223` | **DEFECT** (error text garbled) | **S**: `LoadStrU8`; unbounded `sprintf` into `buf[200 + MAX_PATH]` |
| C-7 | `dialogs3.cpp:289-290` | `IDS_SRVTYPEOVERWRITE` | template code page; `GetTypeNameForUser(...)`: UTF-8 type name (from the imported file - bytes as written by export; inferred UTF-8 when exported by this version) + code-page suffix | `SalMessageBox` `dialogs3.cpp:291` | **DEFECT** (type name garbled; also when only the suffix is non-ASCII) | **M**: `LoadStrU8` + a UTF-8 suffix. `GetTypeNameForUser` / `UserDefinedSuffix` are shared (`ftp2.cpp:794`, `ftp.cpp:318`, used by A sinks `ftp3.cpp:64`, `80` and `dialogs3.cpp:131`) -> the helper change is **L** and belongs to one place for all its users. |
| C-8 | `dialogs3.cpp:319` | `IDS_SRVTYPEIMPORTERROR` | template code page; `LoadStr(errResID)` code page | `SalMessageBox` `dialogs3.cpp:324` | RIGHT AS IT IS | - but it shares the template with C-9: when C-9 is fixed, this argument becomes `LoadStrU8(errResID)` too (reverse rule) |
| C-9 | `dialogs3.cpp:322`, `332` | `IDS_SRVTYPEIMPORTERROR` | template code page; `GetErrorText(err)` UTF-8 | `SalMessageBox` `dialogs3.cpp:324`, `333` | **DEFECT** (error text garbled) | **S**: `LoadStrU8` (with C-8); unbounded `sprintf` into `buf[300 + MAX_PATH]` |
| C-10a | `dialogs3.cpp:432-433` | `IDS_SRVTYPEREMOVECONF` | template code page; `GetTypeNameForUser(s->TypeName)` UTF-8 name + code-page suffix | `SalMessageBoxEx` `dialogs3.cpp:440-441` | **DEFECT** (type name garbled) | **M** (as C-7) |
| C-10b | `dialogs3.cpp:486` | `IDS_SRVTYPENOTUNIQUE` | template code page; `name + 1` UTF-8 (just typed in `CRenameDlg`) | `SalMessageBox` `dialogs3.cpp:487` | **DEFECT** (type name garbled) | **S**: `LoadStrU8`; unbounded `sprintf` into `buf[300 + SERVERTYPE_MAX_SIZE]` |
| C-10c | `dialogs3.cpp:638` | `IDS_STPAR_UNABLECOMPAUTODCOND` | template code page; `LoadStr(errorResID)` code page, or `errBuf` filled in `parser3.cpp:325-327` (`LoadStr(IDS_STPAR_ERR_INVALREGEXP)` + the regular-expression error text `err`; origin of `err` not read - inferred ASCII) | `SalMessageBox` `dialogs3.cpp:639` | RIGHT AS IT IS (inferred for `err`) | - (unbounded `sprintf` into `buf[300]` with `errBuf[200]`, list 3) |
| C-10d | `dialogs3.cpp:675`, `1602` | `IDS_STPAR_UNABLECOMPPARSER` | template code page; `LoadStr(errorResID)` code page | `SalMessageBox` `dialogs3.cpp:676`, `1603` | RIGHT AS IT IS | - |
| C-10e | `dialogs3.cpp:1502` | `IDS_SRVTYPECOL_REMOVECONF` | template code page; column `ID` ASCII (`IsValidIdentifier`, `dialogs4.cpp:25-48`; an ID from an imported or registry-stored type is validated elsewhere - not read, inferred ASCII) | `SalMessageBoxEx` `dialogs3.cpp:1509-1510` | RIGHT AS IT IS | - |
| C-10f | `dialogs4.cpp:984`, `996` | `IDS_SRVTYPE_READRAWLISTERR` | template code page; `GetErrorText(err)` UTF-8 | `SalMessageBox` `dialogs4.cpp:985`, `997` | **DEFECT** (error text garbled) | **S**: `LoadStrU8`; unbounded `sprintf` into `buf[300 + MAX_PATH]` |
| C-10 | `dialogs5.cpp:285`, `290` (`SetDlgTitle`) with the state texts loaded at `dialogs5.cpp:688`, `692`, `695-696` | `IDS_OPERDLGTITLE_ERRORS`, `_DONE`, `_STOPPED`, `_WAITING`, `_PAUSED` (state) + `TitleText` | state: code page (or an ASCII size from `PrintDiskSize`, `dialogs5.cpp:672-674`, or a number, 285). `TitleText` = `operats2.cpp:679-681`: `LoadStr(IDS_OPERDLG...TITLE)` code page + `OperationSubject` + `Host` (UTF-8 by the sub-brief; `OperationSubject` is composed in other files - not read) | window title `dialogs5.cpp:296-313` (U8|CP). The same `TitleText` is the caption of two message boxes (`dialogs6.cpp:580`, `718`) - captions, not to be touched. | **DEFECT**: the file / directory name in the title of the operation window is garbled when the title template or the state word has a non-ASCII letter. Two places make it: the state word here and the title template in `operats2.cpp:680`. | **M** here: the three `LoadStr` of 688-696 feed BOTH the title and `Progress->SetProgress(0, progressTxt)` (`dialogs5.cpp:703`), and the core progress bar draws A (`gui.cpp:261`) - so the title needs its own `LoadStrU8` text and `progressTxt` keeps `LoadStr`. `txt[500]` with `_TRUNCATE` -> `SplU8TrimTornTail`. Plus `LoadStrU8` in `operats2.cpp:680` and whatever composes `OperationSubject` (other group). |
| C-11 | `dialogs5.cpp:417`; `434-455`, `513`, `530`, `538`, `552`, `611`, `616`; `dialogs6.cpp:381`; `dialogs6.cpp:714` | resource text of `IDT_OPERATIONSTEXT`; `IDS_OPERDLGSTATUS1..5`, `IDS_OPERDLGCONNECTIONSIDLE(2)`; `IDS_LOWDISKSPACEONTGTPATH`; `IDS_WANTTOSTOPCON` | templates code page; numbers, `PrintDiskSize` / `PrintTimeLeft` texts (see C-5), a worker ID | `SetWindowText` A `dialogs5.cpp:418`; core static `dialogs5.cpp:623`; core hint `dialogs6.cpp:383`; `SalMessageBox` `dialogs6.cpp:717` | RIGHT AS IT IS (numbers only, none meets a name) | - |
| C-11b | `dialogs7.cpp:598-601` | none (`GetUNIXRightsStr` + `" (%03o)"`) | ASCII | `ti.EditLine` `dialogs7.cpp:601` | RIGHT AS IT IS | - |
| C-12 | `dialogs8.cpp:1028` | `IDS_RENAMESRVTO` | template code page; `Name` UTF-8 (bookmark name `dialogs1.cpp:1650-1652`, or server-type name `dialogs3.cpp:469-474`) | `SetDlgItemTextW(IDT_SUBJECT)` with A fallback `dialogs8.cpp:1029-1036` (U8|CP) | **DEFECT**: the name in "Rename "%s" to" is garbled when the template has a non-ASCII letter | **S**: `LoadStrU8`; unbounded `sprintf` into `buf[BOOKMSRVTYPE_MAX_SIZE + 200]` -> `_snprintf_s` + `SplU8TrimTornTail` |
| C-13 | `dialogs8.cpp:1043-1047` | `IDS_COPYDATAFROM` (bookmarks) / `IDS_SRVTYPECOPYFROM` (server types); second piece `IDS_QUICKCONNECT` | templates code page; `checkboxName` = bookmark name (UTF-8) or `CopyFromName` = `GetTypeNameForUser(...)` (UTF-8 name + code-page suffix, `dialogs3.cpp:477`), cut by `lstrcpyn` at 100 bytes, ampersands doubled; or `LoadStr(IDS_QUICKCONNECT)` code page | `SetDlgItemTextW(IDC_COPYFOCUSEDSRV)` with A fallback `dialogs8.cpp:1048-1055` (U8|CP) | **DEFECT**: the name in the check box "Copy data from bookmark "%s"" is garbled | **M**: `LoadStrU8` for both templates **and** for `IDS_QUICKCONNECT` here (reverse rule); the server-type case needs the UTF-8 suffix (C-7); the 100-byte cut of the name at `dialogs8.cpp:1043` can tear a character - trim at a whole character |
| C-14 | `dialogs1.cpp:2198-2213` | `IDS_PASSWORDIS` | `LoadStrW` template + the password read wide | `SalMessageBoxEx` as UTF-8 | RIGHT AS IT IS (done in feature 116) | - |

(Row numbers C-10a ... C-10f are separate rows of dialogs3 / dialogs4; C-10 is the operation-window title.)

Counts of rows: **DEFECT 13** (C-1, C-2, C-3, C-4, C-6, C-7, C-9, C-10a, C-10b, C-10f, C-10, C-12, C-13; C-7 and
C-10a share one fix of the type-name helper); **RIGHT AS IT IS 8**
(C-5, C-8, C-10c, C-10d, C-10e, C-11, C-11b, C-14); `RIGHT AS IT IS (reply)` 0
in this table (the reply sinks are in C.1); UNCLEAR 0 in this table (two inferences marked: `err` of C-10c,
imported column IDs of C-10e).

Sizes: S = C-2, C-3, C-4, C-6, C-9 (+C-8), C-10b, C-10f, C-12; M = C-10, C-13, C-7 / C-10a at their own lines;
L = C-1 and the shared type-name suffix helper.

Plain uses (not rows), lines per file: dialogs1 37, dialogs2 10, dialogs3 21, dialogs4 21, dialogs5 9, dialogs6 3,
dialogs7 15 (all of them: `dialogs7.cpp` has no composition with a `LoadStr`), dialogs8 59, dialogs.h 1 (comment).
Number-only composition lines counted in C-5 / C-11: dialogs2 4, dialogs5 9, dialogs6 2.
Plain `LoadStr` texts into the log: dialogs2 1 (`dialogs2.cpp:1546`, `IDS_LOGMSGDATACONTERMINATED`); none in the
other files of this part.

### C.3 List 1 - how a person reaches each DEFECT

Reachable with an ordinary FTP server and no error condition is marked **[plain]**; "no server" = reachable
without any connection.

- C-2 **[plain, no server] - easiest**: Connect to FTP Server dialog, a bookmark whose name has a letter outside
  ASCII (e.g. `Žluťoučký server`), button Remove -> the question names the bookmark.
- C-12 **[plain, no server] - easiest**: the same dialog, the same bookmark, Rename (F2) -> the static text above
  the edit line. Also Configuration > Servers > Rename for a server type.
- C-13 **[plain, no server] - easiest**: the same dialog with that bookmark focused, New -> the check box "Copy
  data from bookmark ...". Also Configuration > Servers > New / Copy To with a user-defined type focused.
- C-1 **[plain, no server]**: the same dialog; a bookmark with Advanced settings that name something: a target
  panel path with a non-ASCII folder, a proxy server with a non-ASCII name, or a user-defined server type -> the
  read-only line "Advanced" under the fields. The torn-character variant shows in English: a target panel path
  whose 36th byte of "Target path: ..." falls inside an accented letter.
- Sink "host address on OK" (C.1, `dialogs1.cpp:970`) **[plain]**: Quick Connect, type an address with a non-ASCII
  user name or path (`ftp://server/dokumenty/přílohy`), Connect; open the dialog again -> the address field and
  its history show mojibake (English too).
- Sink CEnterStrDlg "Connecting to ... as ..." (`dialogs8.cpp:1120`) **[plain]**: connect with a user name that has
  a non-ASCII letter and no stored password -> the password prompt names the user (English too).
- C-3 **[plain]**: connected panel, plug-in menu Send FTP Command, a command with a non-ASCII argument that
  succeeds (e.g. `MKD žluťoučký`) -> title of the reply window.
- C-10 **[plain]**: copy (download or upload), delete or change attributes of ONE file or directory with a
  non-ASCII name (the subject then names it - inferred from `operats2.cpp:680`, the composing of
  `OperationSubject` was not read) -> title bar / task bar text of the operation window, while it runs ("(12 %)
  ...") and when it ends ("(Done) ...").
- C-7, C-10a, C-10b [no server]: Configuration > Servers: a user-defined server type with a non-ASCII name ->
  Remove (C-10a); New / Rename to a name that already exists (C-10b); Import of a `.str` file of a type that
  already exists (C-7). The list itself (sink `dialogs3.cpp:131`, `ftp3.cpp:80`) shows the name wrong after Move
  Up / Down and on every fill.
- C-4, C-6, C-9, C-10f [needs a Windows error]: Show Raw Listing > Save As to a place that cannot be written (C-4);
  Configuration > Servers > Export to such a place (C-6); Import of a file that cannot be opened or read (C-9);
  server type > Edit > Test Parser > Load of such a file (C-10f). Visible only with a localized Windows (non-ASCII
  error text) and a translation whose template has a non-ASCII letter.
- Sink CLoginErrorDlg "Connecting to" (`dialogs8.cpp:1220`) [needs a login error and a host name outside ASCII]:
  rare.
- Sink "empty value" cell (`dialogs3.cpp:895`) [no server]: server type > Edit > a text column whose empty value
  has a non-ASCII letter.

The three easiest: **C-2, C-12, C-13** (one bookmark with an accented name, no server, three buttons of one dialog).

### C.4 List 2 - texts that must NOT be touched (go to the server, a file, the configuration)

- `dialogs1.cpp:967-980` + `dialogs8.cpp:38-112`: the address / initial-path / command history values
  (`Config.HostAddressHistory`, `Config.InitPathHistory`, `Config.CommandHistory`) - stored in the configuration.
  (Fixing the A call at `dialogs1.cpp:970` changes what is *shown and re-read*, i.e. it makes the stored value the
  typed one; the stored format stays UTF-8.)
- `dialogs1.cpp:1646-1697`: bookmark name (`AddServer`, `UpdateStr(s->ItemName, ...)`) - stored.
- `dialogs1.cpp:1765-1837`: address split into user / host / path (`UpdateStr`) - stored and sent to the server.
- `dialogs8.cpp:608-645`: `Server->ListCommand`, `Server->InitFTPCommands` - sent to the server and stored.
- `dialogs8.cpp:139-185`: the user's FTP command (`Command`) - sent to the server (`fs3.cpp:755-822`).
- `dialogs8.cpp:1754-1764`: proxy server name / host / user / script - stored; the script is interpreted.
- `dialogs8.cpp:1951-1977`: script variables `$(Host)` ... inserted into the script - parsed by the plug-in.
- `dialogs2.cpp:331-343`: the raw listing bytes written to the file as they came from the server.
- `dialogs3.cpp:155-159`, `199-206`, `275-284`: export file name made from the type name; `ExportToFile` /
  `ImportFromFile` - file format.
- `dialogs3.cpp:465-508`, `699-789`: server-type name, autodetect condition, parsing rules, columns
  (`UpdateStr`) - stored in the configuration and exported.
- `dialogs3.cpp:1430-1435`, `1189-1297`: the function names inserted into the condition / rules - parsed.
- `dialogs4.cpp:271-352`: column ID, name, description, empty value - stored and exported.
- `dialogs2.cpp:1546`: a text to the log (plain, LOG).

### C.5 List 3 - other defects seen on the way (not to be fixed here)

- `dialogs1.cpp:1050-1056`, `1114-1119`, `1124-1127`, `1145-1148`, `1153-1156`: a text cut at byte 36 with
  `"..."` - not at a whole character (see C-1; display only).
- `dialogs1.cpp:1051-1052` with `ftp2.cpp:2947`: the proxy name is copied into `PROXYSRVNAME_MAX_SIZE` (101) bytes
  while the dialog accepts 200 bytes (`dialogs8.cpp:1510-1511`, `1619`, `1662`) - a byte cut (display only here).
- `dialogs1.cpp:970`: `SetWindowText` A with a UTF-8 address (C.1; the mojibake is then stored in the history).
- `dialogs1.cpp:1650`, `dialogs8.cpp:1043`: `lstrcpyn` of a bookmark / type name into 101 bytes - a cut inside a
  character is possible for a longer stored name; at `dialogs1.cpp:1650` the cut name becomes the default of the
  new name.
- Unbounded `sprintf` into a fixed buffer with a name or an error text: `dialogs1.cpp:1708`; `dialogs2.cpp:355`,
  `365`; `dialogs3.cpp:212`, `222`, `289`, `319`, `322`, `332`, `432`, `486`, `638` (`buf[300]` with `errBuf[200]`
  and a template of unknown translated length), `675`, `1502`, `1602`; `dialogs4.cpp:984`, `996`;
  `dialogs8.cpp:1028`, `1046`; `dialogs6.cpp:714` (`buf[200]`, template + number).
- A calls on texts that are UTF-8 elsewhere or that are stored / sent: `dialogs8.cpp:618`, `625` (list command: A
  read = best fit, and `CB_LIMITTEXT` is `FTPCOMMAND_MAX_SIZE` while the buffer is `FTPCOMMAND_MAX_SIZE` bytes -
  the last character can be cut, `dialogs8.cpp:616`, `624-625`); `dialogs4.cpp:176-177`, `185-187` (column name
  and description, best fit, stored); `dialogs4.cpp:567`, `589`, `971` (raw listing in the parser test);
  `dialogs3.cpp:1585` (`GetDlgItemText` A of the rules for Test Parser while Validate reads them as UTF-8,
  `dialogs3.cpp:663`); `dialogs8.cpp:904` (A fallback of the target path); `dialogs8.cpp:1967` (`GetWindowText` A
  of the proxy script, used with character positions of `EM_GETSEL`).
- Byte offsets used as character positions: `dialogs8.cpp:1587-1588` (`errPos - proxyScript` into `EM_SETSEL`),
  `dialogs3.cpp:643`, `679`, `1606` (`errorPos`), `dialogs4.cpp:883-885` - wrong caret place when the text before
  it has a non-ASCII letter.
- `dialogs7.cpp:1152`: `ListView_GetStringWidth` (A) measures a UTF-8 cell text as code page - the tooltip of a
  cell with non-ASCII names appears or not by a wrong width (`LastWidth`, also the tooltip's size at
  `dialogs7.cpp:1225`, `1264-1268`).
- `dialogs7.cpp:193`: `lstrcpyn(buf, ErrDescription, 500)` and the callers' `lstrcpyn(errDescrBuf, ..., 500)`
  (`operats1.cpp:1978-1981`, `2001`): a cut inside a character turns the whole "details" text to code page.
- Path cut for a path used as such: `dialogs6.cpp:48-49` (`pathBuf[MAX_PATH]`, `GetTargetPath` =
  `lstrcpyn`, `operats2.cpp:1311`), `dialogs7.cpp:1311`, `1366-1368` (`Path[MAX_PATH]`) - the free-space check
  then asks about a cut path (effect: a missing or wrong low-disk warning only). In the caller of the solve-error
  dialogs (`operats1.cpp:1938-1939`, `1968-1969`, other group) `diskPath` / `diskName` are cut the same way at
  `MAX_PATH` before they are shown in `dialogs7.cpp:210-216`.
- `dialogs2.cpp:287-291`, `325-326`; `dialogs3.cpp:149`, `193-194`; `dialogs4.cpp:893`, `927-928`: `initDir` /
  `fileName` of `MAX_PATH` bytes for UTF-8 paths of the file dialogs (whether `SplGetFileNameU8` refuses a longer
  path was not read).
- No `%ls` in a narrow printf in these files (searched).

### C.6 Uncertainties

- `CFTPProxyServerList::InitCombo` (proxy combo of the Connect / Advanced / Defaults dialogs) is in `ftp2.cpp`
  and was not read: A or W unknown.
- What `CFTPWorker::ErrorDescr` and the queue item's `ErrAllocDescr` hold (raw reply, or a composed text with a
  name) was not read - it decides whether `CLoginErrorDlg` IDE_SERVERREPLY (`dialogs8.cpp:1218`, A only) and the
  "details" / "error description" edits of dialogs7 can show a mixed text.
- `OperationSubject` (operation window title, C-10): encoding taken from the sub-brief; its composition is in
  other files.
- Unit words of the core's `PrintTimeLeft` / `PrintDiskSize` (C-5, C-11): encoding not read; they only meet
  code-page templates and numbers.
- The regular-expression error text `err` (`parser3.cpp:325`) and the validation of imported column IDs:
  inferred ASCII.
- The mojibake of `dialogs1.cpp:970` and the "also English" verdicts for A-only sinks are conclusions from the
  code (A call with UTF-8 bytes), not measured on a build.


## Part D

### Scope: Part D - operations, queue, workers

Files: `src/plugins/ftp/operats1.cpp` ... `operatsb.cpp`, `operats.h`. Read-only triage, nothing built or run.
All 211 uses of `LoadStr(` in these files were read in their context (the task said "about 215";
the count by grep is 211: operats1 48, operats2 56, operats3 28, operats4 5, operats6 17, operats7 14,
operats8 12 (one of them in a comment, 971), operatsa 3, operatsb 28; operats5, operats9 and operats.h have none).
Statements marked *inferred* were not read in the code.

No contradiction with the sub-brief's facts was seen. Two additions to them are in section 0.

---

### 0. What was established first

**(a) Encoding of the queue item fields and where they are filled**

| Field | Encoding | Filled at |
|---|---|---|
| `CFTPQueueItem::Name`, `Path` (download, delete, change attributes) | UTF-8 | `CFTPQueueItem::SetItem` copies both with `DupStr` (operats2.cpp:2098-2107). Callers: from the panel listing `fs4.cpp:746`, `fs4.cpp:1124`, `fs5.cpp:178` (`Path`, `f->Name`; other group, call sites only read by grep); from a listing parsed in the worker `operats6.cpp:1547` (`WorkingPath`, `file.Name` out of `parser->GetNextItemFromListing`, operats6.cpp:1486 - UTF-8 by the sub-brief's parser fact); from an existing item `operats7.cpp:1465`, `operats4.cpp:354/371/394` |
| `Name`, `Path` (upload = disk name and disk path) | UTF-8 | `fs5.cpp:1157` (`sourcePath`, `name` from the panel, other group); sub-directories: `operatsa.cpp:845` with `sourcePath` (operatsa.cpp:810-814) and `lstItem->Name`; the disk enumeration is `operats5.cpp:2043-2062` (`FTPFindFirstFileU8` + `FindNextFileW`, each name through `SplWToU8`, a name that is not valid UTF-16 is skipped at 2060-2061); `CDiskListingItem::Name` = `DupStr` (operats5.cpp:822-824) |
| `TgtName`, `TgtPath` (download = disk) | UTF-8 | `SetItemCopyOrMove` / `SetItemCopyMoveExplore` called at `fs4.cpp:853/864/889` (other group), `operats4.cpp:353/393` (copied from the item), in sub-directories `operats6.cpp:1472-1479` + `1522-1526` (`targetPath` built from `cmItem->TgtPath` + `TgtName`, `tgtName = file.Name`); renamed by the disk thread: `DiskWork.NewTgtName = DupStr(localWork.Name)` (operats5.cpp:1220, 1630) -> `Queue->UpdateTgtName` (operats6.cpp:87, 278) |
| `TgtName`, `TgtPath` (upload = server) | UTF-8 | `SetItemCopyOrMoveUpload` / `SetItemCopyMoveUploadExplore` at `fs5.cpp:652/684` (other group); sub-directories `operatsa.cpp:836-840` (`WorkingPath`, `tgtName` = the disk name); auto-rename of a directory `operatsa.cpp:573-580` (`UploadAutorenameNewName` from `FTPGenerateNewName`, operatsa.cpp:499) |
| `RenamedName` (upload) | UTF-8 (*inferred*: produced from `TgtName` by `FTPGenerateNewName`, operatsb.cpp:1176; the call that stores it was not read) | `CFTPQueue::UpdateRenamedName` (operats1.cpp:2831-2838), moved to `TgtName` by `ChangeTgtNameToRenamedName` (operats1.cpp:2851-2860) |
| `ErrAllocDescr` | **not one encoding** - see below | only `CFTPQueue::UpdateItemState` (operats1.cpp:2805-2821), always `DupStr(errText)` |
| `WinError` | a number; text made at display time with `FTPGetErrorText` = code page | `UpdateItemState` |
| `CFTPWorker::ErrorDescr` (200 bytes, operats.h:1212, 1291) | code page, or a raw server reply | see group G7-G9 |

`ErrAllocDescr` holds one of three things (all 25 calls of `UpdateItemState` with a non-NULL description were read):
1. a raw **server reply** (`CopyStr(errText, ..., reply, replySize)` just before): operats4.cpp:461, 617, 710, 784, 856;
   operats7.cpp:546, 695; operats8.cpp:1105; operatsa.cpp:167, 220, 276 (used at 293, 302), 472, 612, 687, 738;
   operatsb.cpp:368, 711, 1998, 2006 (used at 2019, 2026); `ListCmdReplyText` at operats7.cpp:1070 and operats8.cpp:964;
   operatsb.cpp:2084;
2. a **plain resource text** (code page): `IDS_ERRDATACONSSLCONNECTERROR` / `IDS_ERRDATACONDECOMPRERROR` at
   operats7.cpp:1061, 1077; operats8.cpp:958; operatsb.cpp:2078;
3. the **proxy error text** of `CSocket::GetProxyError` (operats7.cpp:1073-1074, operats8.cpp:967-968,
   operatsb.cpp:2087-2088): code-page templates + `FTPGetErrorText` + `HostAddress` (sockets.cpp:883-1010, other group).

It never holds a name composed by these files. A server reply may of course quote a name in the server's bytes.

**(b) The way of an item text to the screen**

- Operations list: `COperationDlg` `LVN_GETDISPINFOW` (dialogs6.cpp:786-813) -> `CFTPQueue::GetListViewDataFor`
  (operats1.cpp:~1100-1404; texts at 1152-1390) into `ItemsTextBuf[3][1000]` (dialogs.h:1013, 1108) -> `SplU8ToW`,
  when that gives 0 `MultiByteToWideChar(CP_ACP)` (dialogs6.cpp:805-810). **Each sub-item text is converted on its
  own**: column 0 (description, operats1.cpp:1158-1333) and column 1 (state, operats1.cpp:1335-1387) never share a buffer.
  The `A` notification `LVN_GETDISPINFO` (dialogs6.cpp:775-784) hands the bytes to the control = code page only
  (reached only if the list view is not in the Unicode format; the comment at dialogs6.cpp:787 says it is).
- The same text again for the tool tip: dialogs7.cpp:1138-1198, `buff[1000]`, `SplU8ToWAlloc` else the `A` path.
- State column: `item->GetProblemDescr(reason, 500)` (operats2.cpp:2136-2469) put into
  `IDS_OPERDLGOPSTS_SKIPPED / _FAILED / _WAITUSER` (operats1.cpp:1346-1365).
- Solve Error dialogs: `CFTPQueue::SolveErrorOnItem` (operats1.cpp:1549-2267) copies `Path`/`Name`/`TgtPath`/`TgtName`
  into `ftpPath[301]`, `ftpName[301]`, `diskPath[MAX_PATH]`, `diskName[MAX_PATH]` and the error text into
  `errDescrBuf[500]`, then the dialogs of dialogs7.cpp show each of them **as a separate field** with
  `ti.EditLine` (dialogs7.cpp:202, 208-218, 911, 1416, 1609-1612, 1720-1732) = `SplU8ToWAlloc` else `A`
  (`src/plugins/shared/winliblt.cpp:1259-1293`): UTF-8 or code page. No sentence is composed there from these pieces.
- Connections list: `LVN_GETDISPINFOW` (dialogs6.cpp:865-889) -> `CFTPWorkersList::GetListViewDataFor`
  (operats5.cpp:279-301) -> `CFTPWorker::GetListViewData` (operats3.cpp:353-697) into `ConsTextBuf[3][1000]`
  -> the same "UTF-8 else code page" rule per sub-item. Column 1 = action (operats3.cpp:370-476), column 2 = status
  (operats3.cpp:478-692).
- Worker error: `CFTPWorker::ErrorDescr` -> status column (operats3.cpp:509-518) and -> `GetErrorDescr`
  (operats3.cpp:717-748, operats5.cpp:387-410) -> `COperationDlg::SolveErrorOnConnection` (dialogs5.cpp:1272-1277)
  -> `CLoginErrorDlg(HWindow, errBuf, ...)` (dialogs5.cpp:1371) -> `SetDlgItemText(IDE_SERVERREPLY)` (dialogs8.cpp:1218)
  = **code page only**.
- Title: `CFTPOperation::InitOperDlg` (operats2.cpp:679-681) -> `dlg->TitleText` -> `COperationDlg::SetDlgTitle`
  (dialogs5.cpp:276-313: `SplU8ToWAlloc` + `SplSetWindowTitleW`, else `SetWindowText` A); also the caption of two
  message boxes (dialogs6.cpp:580, 718).

**(c) Is a composed text of these files written to a file or sent to the server?**

- **To the server: none.** Everything sent is built by `PrepareFTPCommand` (no resource text) or by the login
  script (`CFTPOperation::PrepareNextScriptCmd`, operats2.cpp:879-884: `proxySendCmdBuf` from `ProcessProxyScript`);
  the resource text of that function (operats2.cpp:875) goes to `errDescrBuf` only.
- **To a file: every `LOG` row**, when the user saves the log: `WriteFile(file, d->Text.GetString(), ...)`
  (ctrlcon2.cpp:2034) writes the bytes as they are; the same bytes go to the clipboard (sub-brief). Nothing else
  of these files reaches a file, the registry or the configuration.

**Two additions to the sub-brief's facts**

1. `OperationSubject` (operats2.cpp:155, used at 367 and 680) comes from the core:
   `SalamanderGeneral->GetCommonFSOperSourceDescr` (fs4.cpp:638, 926; fs5.cpp:38, 1056, 1068 -> `oper->SetBasicData`).
   For one item the core composes `::LoadStr(IDS_DLG_QUESTION_FILE / _DIRECTORY)` with the UTF-8 name
   (`src/zip.cpp:3996-4000`); for several items it is `ExpandPluralFilesDirs` (zip.cpp:4004), a pure resource text.
   If the core's `::LoadStr` is code page (CLAUDE.md says so; the core function was not read), the subject is
   **already a mixed text when the plug-in gets it** in a language whose word for "file"/"directory" has a
   non-ASCII letter, and a pure code-page text for a multiple selection.
2. `SalamanderGeneral->PrintDiskSize`, `NumberToStr`, `PrintTimeLeft` (operats1.cpp:1207, 1210, 1240;
   operats3.cpp:564, 572, 585, 591, 644, 653; operatsb.cpp:1140) give core texts whose encoding was not checked
   (units, possibly a localized word). Treated below as "code page or ASCII, unverified".

---

### 1. Table of compositions

`LOG` = `Logs.LogMessage` (one byte string per connection, shown as UTF-8 only when ALL of it is valid UTF-8,
ctrlcon2.cpp:1564-1568; file at ctrlcon2.cpp:2034). CP = system code page. "LV" = list view sink of (b), UTF-8 or CP per text.

| # | file:line | template id(s) | pieces and their encodings | sink(s) | verdict | fix and size |
|---|---|---|---|---|---|---|
| G1 | operats1.cpp:1164, 1170, 1176, 1182, 1188, 1196, 1265, 1271, 1321 | `IDS_OPERDOPDS_DELLINK`, `_DELFILE`, `_DELDIR`, `_DELEXPLDIR`, `_CHATTREXPLDIR`, `_RESLINK`, `_MOVEDELDIR`, `_MOVEDELDIRLNK`, `_CHATTREXPLDIRLNK` | template CP + `item->Name` UTF-8 + `item->Path` UTF-8 | LV column 0 (dialogs6.cpp:805-810), tool tip (dialogs7.cpp:1185) | **DEFECT** - with a non-ASCII letter in the translated template and in the name/path the text is not valid UTF-8, the name is shown through the code page (garbled). Template pure ASCII: works by accident | `LoadStrU8`; `S` each (9 lines). Add `SplU8TrimTornTail(buf)` after each (the buffer is 1,000 bytes, `_TRUNCATE`) |
| G1 | operats1.cpp:1205-1232 | `IDS_OPERDOPDS_COPY1/MOVE1/COPY2/MOVE2`, `IDS_OPERDOPDS_ASCIITRMODE/BINARYTRMODE`, `IDS_OPERDOPDS_SIZEINBLOCKS` (1212) | template CP + `Name`, `Path`, `TgtPath`, `TgtName` UTF-8 + `size` (`" ("` + `PrintDiskSize` or `NumberToStr` + `" "` + resource text CP + `")"`, encoding of the core part unverified) + a second resource text CP | LV column 0, tool tip | **DEFECT** (as above) | `LoadStrU8` for the main template, for the transfer-mode text and for `IDS_OPERDOPDS_SIZEINBLOCKS`; `size` passed through `SplLegacyToU8` before use (reverse rule; the core's size text is unverified). Note: today two `LoadStr` in one expression (1221+1223 ...) rely on the rotating buffers of `LoadStr`; `LoadStrU8` has no such limit. `M` |
| G1 | operats1.cpp:1239-1258 | same ids (upload) | template CP + `Name`, `Path` (disk) UTF-8 + `TgtPath`, `TgtName` / `RenamedName` UTF-8 + `size` + resource text | LV column 0, tool tip | **DEFECT** | as the row above; `M` |
| G1 | operats1.cpp:1278, 1287, 1295 | `IDS_OPERDOPDS_COPYEXPLDIR`, `_MOVEEXPLDIR`, `_MOVEEXPLDIRLNK` | template CP + `Name`, `Path`, `TgtPath`, `TgtName` UTF-8 | LV column 0, tool tip | **DEFECT** | `LoadStrU8`; `S` each |
| G1 | operats1.cpp:1303-1306, 1312-1315 | `IDS_OPERDOPDS_CHATTRFILE`, `_CHATTRDIR` | template CP + `Name`, `Path` UTF-8 + `unixRights` ASCII (`"%03o ("` + `GetUNIXRightsStr`, *inferred* ASCII) | LV column 0, tool tip | **DEFECT** | `LoadStrU8`; `S` each |
| G2 | operats1.cpp:1346-1347, 1353-1354, 1364-1365 | `IDS_OPERDLGOPSTS_SKIPPED`, `_FAILED`, `_WAITUSER` | template CP + `reason` = `GetProblemDescr` (rows G3-G5: CP, or CP + server reply) | LV column 1, tool tip | **RIGHT AS IT IS**; **(reply)** when the reason carries a server reply | none. Must stay code page as long as G3-G5 stay code page (separate buffer from G1, so G1 can change alone) |
| G3 | operats2.cpp:2161-2200 | `IDS_OPERDOPPR_CANTCRTGTFILE`, `_CANTCRTGTDIR`, `_TGTFILEREADERROR`, `_SRCFILEREADERROR`, `_TGTFILEWRITEERROR`, `_UPLCANTLISTSRCPATH`, `_UPLCANTDELSRCDISKDIR`, `_UPLCANNOTOPENSRCFILE`, `_UPLCANTDELSRCDISKFILE`; `IDS_UNKNOWNERROR` (2164) | template CP + `FTPGetErrorText(WinError)` CP or resource text CP | `buf` of the caller: `reason` -> G2 (operats1.cpp:1346, 1353, 1364) | **RIGHT AS IT IS** | none |
| G3 | operats2.cpp:2277-2285 | `IDS_OPERDOPPR_LISTENFAILURE`, `IDS_UNKNOWNERROR` | template CP + `FTPGetErrorText` CP | -> G2 | **RIGHT AS IT IS** | none |
| G3 | operats2.cpp:2304-2322 | `IDS_OPERDOPPR_INCOMPLLISTING1`, `_INCOMPLDOWNLOAD1`, `_INCOMPLUPLOAD1`, `_UPLCANTLISTTGTPATH`, `_UPLCANTLISTTGTPATH3`, `IDS_UNKNOWNERROR` | template CP + `FTPGetErrorText` CP / resource text CP / empty | -> G2 | **RIGHT AS IT IS** | none |
| G4 | operats2.cpp:2222-2244 | `IDS_OPERDOPPR_UNKNOWNATTRS`, `IDS_OPERDOPPR_UNKEXISTATTR` | template CP + `OrigRights` (rights column of the listing, UTF-8 by the parser fact, in practice ASCII `rwx` text - *inferred*, the setter was not read) or resource text CP | -> G2 | **RIGHT AS IT IS** (ASCII piece) | none |
| G5 | operats2.cpp:2259, 2266, 2296-2299, 2343, 2351-2352, 2359, 2366, 2387, 2399, 2406, 2420 + the append at 2458-2468 | `IDS_OPERDOPPR_UNABLETOCWD`, `_UNABLETOPWD`, `_INCOMPLLISTING2`, `_INCOMPLDOWNLOAD2`, `_INCOMPLUPLOAD2`, `_UPLCANTLISTTGTPATH2`, `_UNABLETORESOLVELNK`, `_UNABLETODELFILE`, `_UNABLETODELSRCFILE`, `_UNABLETODELDIR`, `_UNABLETOCHATTRS`, `_UPLCANTCRTGTDIR`, `_UPLCRDIRAUTORENFAILED`, `_UPLFILEAUTORENFAILED`, `_UPLCANTCRTGTFILE` | template CP + `' '` + first line of `ErrAllocDescr` (server reply: unknown; or resource text CP; or proxy error text CP - section 0a) | -> G2 | **RIGHT AS IT IS (reply)** | none. See "other defects" 3.1: the append loop stops at the first byte >= 0x80 |
| G6 | operats1.cpp:1656-1667, 1676-1683, 1699-1702, 1729, 1746-1749, 1774-1796, 1904-1911, 1923-1924, 1976-1981, 2001-2002 | none composed: either `ErrAllocDescr`, or `FTPGetErrorText`, or one plain resource text (`IDS_OPERDOPPR_UPLCANTLISTTGTPATH`, `IDS_UNKNOWNERROR`, `IDS_SSCD2_*`, `IDS_UPLERR_*`, `IDS_OPERDOPPR_UPUNABLERESUNKSIZ`) copied into `errDescrBuf[500]` | one piece at a time: server reply (unknown) / CP | `CSolveServerCmdErr` (operats1.cpp:2150-2168 -> dialogs7.cpp:1612), `CSolveServerCmdErr2` (2195-2209 -> dialogs7.cpp:1732), `CSolveItemErrorDlg` (2226, 2244, 2254 -> dialogs7.cpp:192-202): `ti.EditLine` = UTF-8 or CP | **RIGHT AS IT IS** / **(reply)** - not a composition; listed because the buffer crosses into dialogs7.cpp | none |
| G7 | operats3.cpp:455 | `IDS_OPERDLGCOACT_DELFILE`, `_COPY`, `_MOVE`, `_CHATTR`, `_DELLINK`, `_DELDIR`, `_EXPLDIR`, `_RESLINK` (chosen at 398-446) | template CP + `CurItem->Name` UTF-8 | LV Connections column 1 (dialogs6.cpp:881-886), tool tip (dialogs7.cpp:1149, 1185) | **DEFECT** - name garbled when the translated template has a non-ASCII letter | `LoadStrU8(strResID)` + `SplU8TrimTornTail(buf)`; `S` |
| G8 | operats3.cpp:509-511, 518 | `IDS_OPERDLGCOACT_WAITRECON`, `IDS_OPERDLGCOACT_CONERROR` | template CP + numbers + `ErrorDescr` (rows G9-G11: CP or CP + server reply or a bare server reply) | LV Connections column 2, tool tip | **RIGHT AS IT IS**; **(reply)** when `ErrorDescr` carries a reply | none |
| G8 | operats3.cpp:531-547, 565, 573, 592-593, 639-644, 654, 661-663, 670 | `IDS_OPERDLGCOACT_PAUSED`, `_WAITFORLIST`, `IDS_LISTWNDDOWNLOADSPEED`, `IDS_LISTWNDCONNECTIONIDLE`, `IDS_LISTWNDSTATUS1`, `IDS_OPERDLGSTATUS2`, `IDS_OPERDLGCOACT_TIMELEFT`, `IDS_OPERDLGCONNECTIONSIDLE`, `IDS_LISTWNDSTATUS2` | templates CP + core size/time texts (unverified, CP or ASCII) + numbers; never a name | LV Connections column 2 | **RIGHT AS IT IS** (number-only, the buffer never meets a name) | none |
| G9 | operats3.cpp:2225-2226, 2245; operats6.cpp:671-672, 787-788 | `IDS_WORKERGETIPERROR`, `IDS_WORKEROPENCONERR` (+ `IDS_UNKNOWNERROR` through `GetWorkerErrorTxt`, operats3.cpp:7-15) | template CP + `FTPGetErrorText` CP / resource text CP; at 2242-2245 alternatively `GetProxyError(errBuf, 300, NULL, 0, TRUE)` = CP templates + CP error text + `HostAddress` (sockets.cpp:952-986, other group; the host is UTF-8 only if it is not ASCII) | `ErrorDescr` -> G8 (LV) and -> `CLoginErrorDlg` `SetDlgItemText` A (dialogs8.cpp:1218, CP only) | **RIGHT AS IT IS** | none |
| G9 | operats7.cpp:72-83; operatsb.cpp:1557-1568 | `IDS_PROXYERRUNABLETOCON2`, `IDS_PROXYERRUNABLETOCON`, then `IDS_LOGMSGDATCONERROR` around it | template CP + `FTPGetErrorText` CP; second template CP + the first text | `ErrorDescr` -> G8, `CLoginErrorDlg`; `errBuf` -> LOG (operats7.cpp:86, operatsb.cpp:1571) | **RIGHT AS IT IS** (LOG: all pieces CP) | none |
| G9 | operats7.cpp:176-179, 207-210, 221-222; operatsb.cpp:1658-1661, 1688-1691, 1702-1703 | `IDS_LOGMSGDATCONERROR` (+ plain `IDS_PROXYERROPENACTDATA`, `IDS_PREPACTDATACONTIMEOUT`) | template CP + `GetProxyError` text (CP, may hold `HostAddress`) or `GetProxyTimeoutDescr` text (resource text CP, sockets.cpp:1037) | `ErrorDescr` -> G8, `CLoginErrorDlg`; `"%s\r\n"` -> LOG | **RIGHT AS IT IS** (LOG: CP) | none |
| G9 | operats3.cpp:2402-2406 | `IDS_LOGMSGDATCONERROR` | template CP + `GetProxyTimeoutDescr(errText, 200)` resource text CP | LOG (operats3.cpp:2406) | **RIGHT AS IT IS** (LOG: CP). Unbounded `sprintf` into `errBuf[300]` with a 200-byte piece: fits while the translated template is shorter than 100 bytes | none |
| G10 | operats6.cpp:889-890, 1219-1220; 982-983; 1191-1192 (and the bare reply at 873-874, operats3.cpp:2204) | `IDS_NOTFTPSERVERERROR`, `IDS_INCOMPLETEPRXSCR3`, `IDS_WORKERLOGINERR` | template CP + `CopyStr(errBuf, ..., reply, replySize)` = server reply, unknown encoding | `ErrorDescr` -> G8 (LV), `CLoginErrorDlg` A | **RIGHT AS IT IS (reply)** | none |
| G11 | operats6.cpp:998-1001 | `IDS_ERRINPROXYSCRIPT`; or the bare `errDescrBuf` | template CP + `errDescrBuf` from `PrepareNextScriptCmd` (operats2.cpp:875: resource text CP; or `ProcessProxyScript`'s text, ftp2.cpp:2009-2010 `LoadStr(errCode)` CP - only these two lines of ftp2.cpp were read) | `ErrorDescr` -> G8, `CLoginErrorDlg` | **RIGHT AS IT IS** | none |
| G11 | operats6.cpp:1064-1067 | `LoadStr(errID)` (id returned by `EncryptSocket`) | template CP + `errBuf` filled by `EncryptSocket` (*inferred* ASCII OpenSSL text; the function was not read) | `ErrorDescr` -> G8, `CLoginErrorDlg` | **RIGHT AS IT IS** (if the SSL text is ASCII) | none |
| G12 | operats2.cpp:367-369 | `IDS_OPERDLGDELETETITLE`, `_COPYDOWNLOADTITLE`, `_MOVEDOWNLOADTITLE`, `_COPYUPLOADTITLE`, `_MOVEUPLOADTITLE`, `_CHATTRSTITLE` | template CP + `OperationSubject` (core text: CP words + UTF-8 name, section 0) + `Host` UTF-8 (believed, sub-brief) | LOG (first lines of every worker's log; called from the worker's constructor, operats3.cpp:130) | **DEFECT** (LOG) - the name inside the subject | `LoadStrU8`, `OperationSubject` through `SplLegacyToU8` (it is pure CP for a multiple selection), `SplU8TrimTornTail` (buffer 498 + `"\r\n"`); `M`. Useful only together with the whole log - see the note under the table |
| G12 | operats2.cpp:371-379 | `IDS_WORKERLOGHEADER` | template CP + `Host` UTF-8 + numbers + `timeBuf` = `GetDateFormat` / `GetTimeFormat` (A) = CP | LOG | **DEFECT** (LOG) only with a non-ASCII host name; otherwise all CP | `LoadStrU8` + `timeBuf` through `SplLegacyToU8`; the unbounded `sprintf(buf, ...)` into `buf[500]` (Host <= 200 bytes, `timeBuf` <= 100) becomes `_snprintf_s(buf, _TRUNCATE, ...)`; `M` |
| G13 | operats2.cpp:679-681 | the same six title ids | template CP + `OperationSubject` (as G12) + `Host` UTF-8 | `dlg->TitleText` -> window title (dialogs5.cpp:296-313: UTF-8 else `SetWindowText` A) and -> caption of `SalMessageBox` (dialogs6.cpp:580, 718) | **DEFECT** - title of the operation window: the name garbled when the template or the core's word has a non-ASCII letter | `LoadStrU8` + `OperationSubject` through `SplLegacyToU8` + `SplU8TrimTornTail(title)`; `M`. Complete only when the core's subject is UTF-8 (not in the plug-in's hands; record) |
| G14 | operats2.cpp:775-779, 791-794 | `IDS_PRXSRVRECONLOGHEADER`, `IDS_PRXSRVWORKERCONLOGHDR` | template CP + `Host`, `User`, `ProxyServer->ProxyName`, `ProxyHost`, `ProxyUser`, `ConnectToHost` UTF-8 (believed, sub-brief) + `GetProxyTypeName(...)` (not read: resource text CP or a constant) + `inet_ntoa` ASCII + numbers + `dateTime` CP (operats6.cpp:750-754) | `buf` of the caller -> LOG (operats6.cpp:743-744, 755-756) | **DEFECT** (LOG) with a non-ASCII user, proxy name or host | `LoadStrU8`; `GetProxyTypeName` text and `dateTime` through `SplLegacyToU8`; `SplU8TrimTornTail`; `M` |
| G14 | operats2.cpp:783-784, 798 | `IDS_RECONLOGHEADER`, `IDS_WORKERCONLOGHDR` | template CP + `ConnectToHost` UTF-8 + ASCII + numbers + `dateTime` CP | LOG (operats6.cpp:744, 756) | **DEFECT** (LOG) only with a non-ASCII host name | `LoadStrU8` (+ `dateTime` converted); `S`/`M` |
| G15 | operats4.cpp:34-37 | `IDS_LOGMSGEXPLORINGDIR` | template CP + `TgtName`, `TgtPath` UTF-8 | LOG | **DEFECT** (LOG) | `LoadStrU8` + `SplU8TrimTornTail(errText)`; `S` |
| G15 | operats4.cpp:311-312; operatsa.cpp:125-126; operatsb.cpp:326-327 | `IDS_LOGMSGRESOLVINGLINK` | template CP + `ftpPath` UTF-8 | LOG | **DEFECT** (LOG) | `S` each |
| G15 | operats4.cpp:520-558 | `IDS_LOGMSGDELETELINK`, `_DELETEFILE`, `_DELETEDIR`, `_DOWNLOADFILE`, `_DOWNLOADFILE2`, `_DELETEDIRLINK`, `_CHATTRSFILE`, `_CHATTRSDIR` | template CP + `CurItem->Name` UTF-8 (+ `tgtName` UTF-8) | LOG | **DEFECT** (LOG) | `LoadStrU8(opDescrResID)`; `S` |
| G15 | operats7.cpp:496-497 | `IDS_LOGMSGLISTINGPATH` | template CP + `ftpPath` UTF-8 | LOG | **DEFECT** (LOG) | `S` |
| G15 | operats8.cpp:764-765 | `IDS_LOGMSGDWNLOADFORCRESUM` | template CP + `curItem->Name` UTF-8 | LOG | **DEFECT** (LOG) | `S` |
| G15 | operatsa.cpp:209-210, 534-535 | `IDS_LOGMSGCREATEDIR` | template CP + `curItem->TgtName` / `UploadAutorenameNewName` UTF-8 | LOG | **DEFECT** (LOG) | `S` each |
| G15 | operatsb.cpp:213-214 | `IDS_LOGMSGUPLOADFILE` | template CP + `curItem->Name` UTF-8 | LOG | **DEFECT** (LOG) | `S` |
| G15 | operatsb.cpp:1139-1144 | `IDS_LOGMSGUPLOADISCOMPL`, `_ISCOMPL2`, `_ISNOTCOMPL`, `_ISNOTCOMPL2` | template CP + `curItem->TgtName` UTF-8 + `num` (`PrintDiskSize`, unverified) | LOG | **DEFECT** (LOG) | `LoadStrU8` + `num` through `SplLegacyToU8`; `M` |
| G15 | operatsb.cpp:1787-1788 | `IDS_LOGMSGUPLOADRENFILE` | template CP + `curItem->RenamedName` UTF-8 | LOG | **DEFECT** (LOG) | `S` |
| G16 | operats7.cpp:1313-1316 | `IDS_LOGMSGPARSEDBYSRVTYPE` | template CP + `listingServerType` = `serverType->TypeName` without `*` (operats7.cpp:1285-1288; UTF-8 believed, sub-brief; the built-in type names are ASCII - *inferred*) | LOG | **DEFECT** (LOG) only with a user-defined server type that has a non-ASCII name | `LoadStrU8`; `S` |

Counts: **DEFECT 39 composition sites** (G1: 18 `_snprintf_s` sites; G7: 1; G12: 2; G13: 1; G14: 4 templates in one function;
G15: 12; G16: 1 - of them 19 go to the log only (G12, G14, G15, G16), and 4 of those (G12 header line 378, G14 x2 without
proxy, G16) need an unusual host / type name; 20 are on the screen: G1, G7, G13). **RIGHT AS IT IS 20 sites** (G3: 3,
G4: 1, G8 number-only status: 1 group, G9: 4 + 4 + 4 + 1, G11: 2). **RIGHT AS IT IS (reply) 21 sites** (G2: 3 and G8: 2 -
right, "reply" only when the inner text carries one; G5: 11 templates with the one append; G6: 1 group; G10: 4).
**UNCLEAR: no whole row**; unclear *pieces* are named in the rows (core size/time texts, `GetProxyTypeName`,
`EncryptSocket` text, the core's subject).

**Note on every LOG row (decides whether fixing them is worth it).** The log of one connection is one byte string
and is shown as UTF-8 only if all of it is valid UTF-8. So a `LoadStrU8` template in one message does not help
while any other message of that log holds code-page bytes: the plain resource texts logged by these files (list
below, 34 uses), `FTPGetErrorTextForLog` (operats3.cpp:2281-2282, 2346-2347), the date text of the header, the
G9 texts, raw server replies (operats3.cpp:2198, 2313) and the logged command line (code page when
representable, sub-brief). A consequence that follows from the sub-brief's facts and was **not tested**: also in
**English**, a file whose name is not ASCII gives a log with the name as UTF-8 bytes in the `IDS_LOGMSG*` line and
as code-page bytes in the command line (`RETR ...`), so the whole log is shown through the code page and the
`IDS_LOGMSG*` line shows the name garbled. The log rows are therefore one `L` piece of work that belongs to the
sink (`CLogs::LogMessage`, ctrlcon2.cpp:1799: e.g. each appended message made UTF-8 on its own - valid UTF-8 kept,
anything else converted from the code page), plus the `S` template changes of G12, G14, G15, G16 so that the
message itself is not mixed. That changes the bytes of a saved log file (today: mixed bytes) - a decision for the
maintainer, not a per-site fix.

**Plain uses (no row), per file**

- operats1: 22 - wait window 1 (356), message box + caption 2 (379-380), state texts into the list view 5
  (1341, 1359, 1370, 1373, 1376), resource text copied into `errDescrBuf` 14 (in G6).
- operats2: 30 - `SetDlgItemText` 3 (693, 694, 702), `errDescrBuf` 1 (875), `GetProblemDescr` texts without any
  piece 26 (2145, 2148, 2205, 2208, 2213, 2217, 2249, 2253, 2272, 2328, 2332, 2335, 2338, 2372, 2375, 2383, 2394,
  2416, 2427, 2430, 2433, 2436, 2439, 2442, 2445, 2448).
- operats3: 16 - list view texts 11 (373, 379, 382, 385, 388, 488, 497, 500, 506, 531, 547), `GetWorkerErrorTxt` 1
  (13), `ErrorDescr` 2 (2351, 2424), log 2 (868, 2413).
- operats4: 2 (log). operats6: 9 - `ErrorDescr` 7 (721, 838, 967, 1052, 1065, 1074, 1093; 1065 is the
  no-text branch of G11), log 2 (975, 1147). operats7: 8 - `ErrorDescr` 3 (80, 177, 208), `ErrAllocDescr` 2
  (1061, 1077), log 3 (288, 851, 1303-1305). operats8: 10 - log 9, `ErrAllocDescr` 1 (958); + 1 in a comment (971).
  operatsa: 0. operatsb: 20 - log 16, `ErrorDescr` 3 (1565, 1659, 1689), `ErrAllocDescr` 1 (2078).
- Total: 117 plain + 93 `LoadStr` uses inside the rows + 1 in a comment = 211.

**Plain resource texts that go into the log** (count per file): operats3 2 (868, 2413); operats4 2 (1170, 1266);
operats6 2 (975, 1147); operats7 3 (288, 851, 1303-1305); operats8 9 (64, 68, 466, 486, 494, 573, 800, 986, 994);
operatsb 16 (628, 629, 886, 889, 913, 1063, 1066, 1090, 1108, 1111, 1445, 2049, 2053, 2069, 2070, 2155). Total 34.
operats1, operats2 (only composed ones), operats5, operats9, operatsa: none.

---

### 2. How a person reaches each DEFECT

| Row | How | Condition |
|---|---|---|
| **G1** (description column) | FTP panel: Copy (F5), Move (F6), Delete (F8), Change Attributes on a file/directory whose name has a non-ASCII letter, or upload such a file from disk; look at the *Operations* list of the operation window | **ordinary server, no error.** Non-English language whose `IDS_OPERDOPDS_*` text has a non-ASCII letter (the translations were not read). The window must stay open long enough (a large file, a paused operation, or "close when done" off) |
| **G7** (action column) | the same operations; *Connections* list, column Action ("Copying <name>") while a worker works on the item | **ordinary server, no error**; the item must be in work (large file or pause) |
| **G13** (window title) | the same operations started on ONE item with a non-ASCII name: the title is "Copy file "<name>" from <host>" | **ordinary server, no error**; visible at once, also in the task bar. For a multiple selection the title holds no name and is right |
| G12, G15 (log) | the same operations, then the FTP *Logs* window, the log of the worker ("Downloading file ...", "Uploading file ...", "Listing path ...", "Deleting ...", "Creating directory ...") | **ordinary server, no error**, logging of workers enabled (`Config.EnableLogging && !Config.DisableLoggingOfWorkers`, operats3.cpp:127). By the note above the name is very likely garbled in English too (not tested) |
| G15 operats4.cpp:311, operatsa.cpp:125, operatsb.cpp:326 | operation on a **link** (the server lists symbolic links) | ordinary UNIX server with a symbolic link |
| G15 operats8.cpp:764 | download where all data arrived and the server did not answer in time | server fault / very long transfer |
| G15 operatsb.cpp:1142 | upload after which the size test ran (upload error, then `SIZE`) | transfer error |
| G15 operatsb.cpp:1787, operatsa.cpp:534 | upload with the collision answer *Autorename* | target name exists on the server |
| G14 | any operation that opens a new connection (second worker, reconnect); log header "Connecting to ..." | non-ASCII user name, proxy server name or host - unusual |
| G12 header line 378, G16 | as G12 / a listing parsed by a user-defined server type | non-ASCII host / type name - unusual |

Easiest three: **G13** (title, one item), **G1** (description column), **G7** (action column).

---

### 3. Texts that must NOT be touched

- operats2.cpp:879-884 - `buf` = the login-script command sent to the server and `logBuf` its log form
  (`PrepareNextScriptCmd`; used at operats6.cpp:958-992). No resource text; leave.
- Every `PrepareFTPCommand(buf, ..., errBuf, ...)` in these files (e.g. operats4.cpp:314, 847; operats7.cpp:153, 499;
  operatsa.cpp:128, 212, 537; operatsb.cpp:329, 1792) - bytes for the server and their log copy.
- operats6.cpp:915-944 - `"AUTH TLS\r\n"`, `"PBSZ 0\r\n"`, `"PROT P\r\n"`, `"MODE Z\r\n"` constants sent to the server.
- The raw reply logged at operats3.cpp:2198 and 2313 and stored by `CopyStr` (operats3.cpp:2204, operats6.cpp:873,
  operats2.cpp:812, 825 `ServerSystem` / `ServerFirstReply`, which are parsed later) - server bytes.
- All `LOG` rows reach the saved log file (ctrlcon2.cpp:2034): a change of their bytes changes that file - only
  with the decision described in the note under the table.
- Nothing in these files writes a composed text to the registry or the configuration.

---

### 4. Other defects seen on the way (not to be fixed here)

1. **operats2.cpp:2465** - `while (s < end && *src >= ' ')` with `char* src`: `char` is signed with MSVC (no `/J`
   was found by a grep of the FTP project files; not checked further), so the copy of the reply's first line
   **stops at the first byte >= 0x80**. A reply `550 <name with a non-ASCII letter>: ...` is shown in the state
   column cut before that letter. The same pattern is in `sockets.cpp:914` (other group).
2. **operats6.cpp:1472-1479** - `char targetPath[MAX_PATH]`; `lstrcpyn(targetPath, cmItem->TgtPath, MAX_PATH)` +
   `SalPathAppend(..., MAX_PATH)` with the result not checked ("must succeed ... at most MAX_PATH-1 characters").
   The path is **used as the target directory** of the items created at 1522-1526; a UTF-8 path under 260 UTF-16
   units can be longer than 259 bytes -> silently cut target path (files would go to another directory). The rule
   "a path is never cut" - candidate for `specs/NEXT-WORK.md`.
3. **operatsa.cpp:810-814** - `char sourcePath[MAX_PATH]`, `lstrcpyn(sourcePath, CurItem->Path, MAX_PATH)` (silent
   cut) before `SalPathAppend` (whose failure is handled as an error). **operatsa.cpp:826-831** `mbrName`:
   `lstrcpyn(mbrName, tgtName, MAX_PATH)` (AS/400 only). **operats6.cpp:1515-1520** `mbrName[MAX_PATH]` filled by
   `FTPAS400CutFileNamePart` (not read).
4. **operats1.cpp:1558-1561** `diskPath[MAX_PATH]`, `diskName[MAX_PATH]` filled by `lstrcpyn` at 1608-1609,
   1642-1643, 1694-1695, 1721-1722, 1726-1727, 1743-1744, 1764-1765, 1769-1770, 1875-1876, 1897-1898, 1938-1939,
   1969-1970, and `ftpPath[301]`, `ftpName[301]` at 1585-1586, 1593-1594, 1598-1599: byte cut, possibly inside a
   character (then the field of the Solve Error dialog shows through the code page). As far as read they are
   display values of the dialogs (the dialogs' use of `DiskName` for the new-name proposal was not followed).
5. **`_TRUNCATE` without a whole-character trim** on texts that hold names: operats1.cpp:1164-1321 (1,000 bytes),
   operats3.cpp:455, operats2.cpp:367 (498), 680 (500), 775-798, and every `errText` log message of G15
   (`200 + FTP_MAX_PATH` = 501 bytes; operats4.cpp:34, 311, 557; operats7.cpp:496; operats8.cpp:764; operatsa.cpp:125,
   209, 534; operatsb.cpp:213, 326, 1142, 1787). A cut log message also loses the `\r\n` of its template. A cut
   inside a character makes the whole list-view text invalid UTF-8 (shown through the code page).
6. **Unbounded `sprintf`**: operats2.cpp:378 (`buf[500]`, Host up to 200 bytes + `timeBuf` up to 100 + the
   translated template), operats3.cpp:2405 (`errBuf[300]`, 200-byte piece + template). Both fit with the English
   templates; a long translation could overflow. operats2.cpp:373-377 and operats6.cpp:750-754 build the date/time
   text with `strcat` / `sprintf` into 100-byte buffers from two 50-byte API calls (fits).
7. **operats2.cpp:373, 376; operats6.cpp:750, 753** - `GetDateFormat` / `GetTimeFormat` (A): a code-page text in
   the log header (non-ASCII in some locales).
8. **dialogs8.cpp:1218** (other group, sink of `ErrorDescr`) - `SetDlgItemText` A: a server reply in UTF-8 is shown
   through the code page in the login error dialog, while the same text in the Connections list (operats3.cpp:518)
   is shown as UTF-8 when the whole status text is valid UTF-8.
9. **`src/zip.cpp:3996-4000`** (core) - `GetCommonFSOperSourceDescr` composes `::LoadStr(...)` with the UTF-8
   name; if the core's `::LoadStr` is code page (not read), the subject given to plug-ins is mixed (section 0).
10. No `%ls` in a narrow printf and no `A` file API on a path was seen in these files (disk work in operats5.cpp
    goes through `FTP*U8` / `SalamanderGeneral->Sal*`, operats5.cpp:1056-2202).

---

### 5. Not verified / uncertain

- The translated templates were not read: whether a given `IDS_OPERDOPDS_*` / `IDS_OPERDLGCOACT_*` / title text
  has a non-ASCII letter in cs/de/... decides whether the DEFECT shows; English never shows G1, G7, G13.
- `SplU8ToW` (dialogs6.cpp:805, 881) returning 0 also when the text does not fit `cchTextMax` would send a valid
  UTF-8 text through the code page - not read.
- Encoding of the core's `PrintDiskSize` / `NumberToStr` / `PrintTimeLeft`, of `GetProxyTypeName`, of
  `EncryptSocket`'s error text and of the core's `::LoadStr`; `OrigRights` and `RenamedName` setters not read.
- `Host`, `User`, proxy and server-type names taken as UTF-8 from the sub-brief, their origin was not met in
  these files (`CFTPOperation::SetConnection`, operats2.cpp:92-102, only copies them).
- The statement about the log in English is a deduction from the sub-brief's facts, not a reading of
  ctrlcon2.cpp:44 or a test.

