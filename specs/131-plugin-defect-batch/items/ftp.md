# Feature 131 - FTP plug-in (`src/plugins/ftp`): items of the triage of feature 130

Session 2026-10-13. Nothing was built or run; every verdict is from reading the code (the lines
are given). One script was run outside the tree: it measured the longest translation of the
templates named below (`translations/*/ftp.slt`). Line numbers are those of the tree before this
work unless a function name is given.

Scope kept: only cut paths / names, overruns and wrong loops. No message encoding, template, log
or server text was changed. No new string, no interface change, nothing outside the directory.

Files changed: `ftputils.h`, `ftp.h`, `ctrlcon1.cpp`, `ctrlcon2.cpp`, `sockets.cpp`, `dialogs2.cpp`,
`fs5.cpp`, `operatsa.cpp`.

Two facts that decide several items:

- **`char` is unsigned in every plug-in.** `src/plugins/shared/vcxproj/plugin_base.props:16` has
  `<AdditionalOptions>/MP /J %(AdditionalOptions)</AdditionalOptions>`; `ftp.vcxproj:58/70/82/94`
  imports it in all four configurations and no project file of the plug-in sets the option again.
  The triage looked only in the FTP project files and found no `/J`.
- **The core never hands the plug-in a user part of 260 bytes or more.** Change Directory and every
  other path change: `fileswn2.cpp:2961` (`strlen(fsUserPart) >= MAX_PATH` - refused) and
  `fileswn2.cpp:2729-2730` (`char user[MAX_PATH]; lstrcpyn(user, origUserPart, MAX_PATH)`), also
  `fileswn3.cpp:2046`. Copy / Move to a file system: `fileswn8.cpp:788-793`
  (`strlen(secondPart) >= MAX_PATH` - message "too long path", back to the dialog). The plug-in's
  own limit for a remote path is 300 bytes (`FTP_MAX_PATH` 301), so a typed path cannot reach it.

---

## 1. `operats6.cpp:1472-1479` - target path of the items of a downloaded directory

**Note of 130:** `targetPath[MAX_PATH]` filled with `lstrcpyn` and an unchecked `SalPathAppend`,
then used as the target directory of the new items - a silently cut path.

**Found: UNREACHABLE.** The comment in the code ("must succeed; the directory already exists on
disk and its full name is at most MAX_PATH-1 characters") holds, by this chain:

- `ParseListingToFTPQueue` runs for an explore item only after its target directory is ready:
  `operats6.cpp:45-53` starts the disk work `fdwtCreateDir` with the item's `TgtPath` / `TgtName`
  while `TgtDirState == TGTDIRSTATE_UNKNOWN`, and only `operats6.cpp:91-93` sets
  `TGTDIRSTATE_READY` (when `DiskWork.State == sqisNone`). The item is created with `UNKNOWN`
  (`fs4.cpp:864`, `operats4.cpp:353`); nothing else sets `READY`.
- `DoCreateDir` (`operats5.cpp:1038`) succeeds only with a full name under `PATH_MAX_PATH` = 248
  bytes: `SalPathAppend(fullName, localWork.Name, PATH_MAX_PATH)` at 1048, and the autorename
  branch builds the name inside `rest = PATH_MAX_PATH - ...` (1163, 1206). "Use the existing
  directory" needs `alreadyExists`, which is set only after that append succeeded (1072-1073).
- A `TgtPath` of 260 bytes or more is cut by `InitDiskWork` (`operats3.cpp:302`,
  `lstrcpyn(DiskWork.Path, path, MAX_PATH)`) to exactly 259 bytes; then no name fits
  (`SalPathAppend`, `src/salamdr3.cpp:23-52`: `l + 1 + n < pathSize` with `l` >= 258) and the
  autorename has `rest` <= 0 - the work ends with "file name too long", the item fails, the
  listing is never parsed.

So at 1478-1479 `TgtPath + "\" + TgtName` is at most 247 bytes and nothing is cut.

**User's view of a long target:** F5 from an FTP panel into a local directory whose UTF-8 path is
260 bytes or more (possible under 260 UTF-16 units: 90 CJK letters) - every item fails with the
system's "file name too long" text in the operation window. Nothing is created under a wrong
name. That the cut in `InitDiskWork` is harmless only because a cut path is always full is an
accident of the arithmetic, not a check.

**Change:** none.

**Test:** GUI row - target directory `C:\T\<86 times 語>` (3 + 258 bytes), F5 on a remote
directory with one file: expected the directory item in state failed, nothing new on disk
(also not in a directory whose name is a prefix of the target).

**Not sure:** that no other path sets `TgtDirState` (searched: `TGTDIRSTATE_` in the plug-in).
The same reasoning for file items (`DoCreateFile`, `operats5.cpp:1300-1301`, `MAX_PATH`) was read
for the first branch and the autorename branch only.

## 2. `fs2.cpp:466`, `623`, `724` (and `fs5.cpp:841`) - remote paths cut at 300 bytes

**Note of 130:** a typed remote path longer than `FTP_MAX_PATH` is cut silently, inside a
character too.

**Found:**

- `fs2.cpp:466` (`Path` from a bookmark's initial path): **NOT A DEFECT.** The value cannot be
  longer: the field is read with `ti.EditLine(IDE_INITIALPATH, ..., FTP_MAX_PATH)`
  (`dialogs1.cpp:1036`, `1851`; a value that does not fit is refused, feature 104) and the registry
  value is read into `initialPath[FTP_MAX_PATH]` (`ftp.cpp:1505`, `1564`).
- `fs2.cpp:623`, `724` (`ChangePath`) and `fs5.cpp:841` (target of an upload): **UNREACHABLE** -
  the user part arrives with at most 259 bytes (second fact above), the path inside it is
  shorter, the limit is 299 bytes after the first slash.

**The real cut is in the core** and is not mine to change: `fileswn2.cpp:2729-2730` copies the
user part into 260 bytes before `ChangePath` - after the length test of line 2961 this is safe for
that caller; whether every caller of `ChangeAndListPathOnFS` (lines 3029, 3186, 3323, 3561) has
such a test was not followed.

**Change:** none. If the core's limit is ever raised, three guards are owed here (refuse with
`IDS_TOOLONGPATH` when `strlen(userPart) >= FTP_USERPART_SIZE` or `strlen(path) > FTP_MAX_PATH - 2`,
before `Path` is written / before the connection is opened): `fs2.cpp` after the feature-121 test
(line 586), `fs2.cpp:717-724`, `fs5.cpp:729-735`. Of the three, `fs5.cpp:841` would be the
dangerous one: a cut target path of an upload is another directory, or a cut last component is
taken as the new file name.

**Test:** GUI row - Shift+F7 with `ftp://127.0.0.1/` + 300 bytes of path: expected the core's
"too long path" message, no connection attempt. F5 from disk with the same target: the same
message, back in the Copy dialog.

**Not sure:** the two drag-and-drop routes `fileswna.cpp:691-692`, `731-732` (mode 3) - the size
of `data->ArchivePathOrUserPart` was not read.

## 3. `operats2.cpp:2465` (and `sockets.cpp:914`) - `*src >= ' '` on `char`

**Note of 130:** `char` is signed with MSVC, so the copy of a server reply stops at the first
byte >= 0x80; "no `/J` was found by a grep of the FTP project files".

**Found: NOT A DEFECT.** The plug-ins are compiled with `/J` (first fact above): `char` is
unsigned, a byte >= 0x80 is greater than `' '`, the loop copies it. The same holds for
`sockets.cpp:914-916`.

**Change:** none.

**Test:** GUI row (it would fail if `/J` were ever dropped) - a server that answers `STOR` or
`RETR` with `550 soubor žluťoučký: denied`; the state column of the operation window must hold the
whole first line. Not run.

**Not sure:** nothing; the option was read in the property sheet, not seen in a compiler command
line.

## 4. The other items of the three sections

### 4.1 FIXED - Logs window: overrun of the combo item (`ctrlcon2.cpp:1467-1510`)

**Note of 130:** unbounded `sprintf` chain into `buf[300]` (user 100 + host 200) - overflow.

**Found: real, reachable.** `CLogs::AddLogsToCombo` wrote "UID: user@host:port (state, state)"
with six unbounded `sprintf` calls into 300 bytes; a user name of 100 and a host of 200 bytes are
accepted (`USER_MAX_SIZE` 101, `HOST_MAX_SIZE` 201) and alone make 319 bytes.

**Reach:** a connection whose user + host have more than about 250 bytes, then Plugins > FTP
Client > Show Logs: stack overrun of `buf` (with the stack cookie the program ends when the
function returns). The log is created only once the host name has resolved
(`ctrlcon1.cpp:791`, state `sccsConnect`), so the host must be a name that resolves - a long DNS
name, an entry of the `hosts` file - or the connection must go through a proxy server (the FTP
host is then not resolved locally). A long name that does not resolve leaves no log and does not
reach this code. Rare in practice; real.

**Fix:**
- `ftp.h`: `LOGSCOMBOITEM_MAX_SIZE` (20 + user + host + 300 = 622).
- `ctrlcon2.cpp`, `AddLogsToCombo`: the buffer has that size and every piece is appended with
  `_snprintf_s(buf + len, size - len, _TRUNCATE, ...)`.
- `dialogs2.cpp` (`CM_SAVELOG` / `CM_COPYLOG` / `CM_CLEARLOG` / `CM_REMOVELOG`): the reader's buffer
  and its `CB_GETLBTEXTLEN` test use the same constant. It was 300: without this the four commands
  would do nothing for an item of 300 characters or more.
- `ctrlcon2.cpp`, `ClearLog` / `RemoveLog`: the question (template + item) is bounded and its
  buffer is `300 + LOGSCOMBOITEM_MAX_SIZE` (it was `sprintf` into 500 bytes - with the larger item
  it would have become the next overrun).

The sink stays `CB_ADDSTRING` (A) and the texts stay as they are - that is step 5 of the plan of
130.

**Test:** GUI row - needs a 200-character host name that resolves to the probe's server (a line
in the `hosts` file - administrator rights - or a proxy server defined in the plug-in); connect as
user `u` x 100; open Logs; expected: the window opens, the combo item is `N: uuu...@aaa... (...)`
whole (`CB_GETLBTEXTLEN` = 3 + 100 + 1 + 200 + the state text), and *Clear log* asks its question
with the whole item. Before the fix: the program ends. Whether the log of a connection that
failed stays in the list was not read - use a server that answers.

**Not sure:** that the two state texts stay under 300 bytes in every language (longest today:
52 + 39 bytes of UTF-8, Ukrainian / Russian) - the calls are bounded either way.

### 4.2 FIXED - a `%` in the host name was read as a printf directive; the same lines bounded (`ctrlcon1.cpp:678`, `740`, `906`, `932`, `1984`; `sockets.cpp:998`)

**Note of 130:** `formatBuf[300]` is filled with unbounded `sprintf` (host up to 200 bytes) and
then used as a printf format; "whether a host can contain `%` was not checked".

**Found:**
- The overrun: **not reachable with today's translations.** Longest `IDS_OPENCONERROR` is 85
  characters (Ukrainian, a language that is not built); with a 200-byte host, the IP and the port
  the text is 298 characters - one byte of margin. `IDS_GETIPERROR`: 61 + 200.
- The format: **real, reachable.** The host is taken as typed (`fs2.cpp:617`, the Connect dialog's
  address) and nothing refuses a `%`. `formatBuf` = `Unable to get IP address of server "a%sb".`
  `Error: %s`, then `_snprintf_s(buf, _TRUNCATE, formatBuf, e)` (`ctrlcon1.cpp:1040`) or
  `sprintf(buf, formatBuf, e)` (1984) with ONE argument: the second `%s` reads a string pointer
  that was never passed.

**Reach:** Shift+F7 `ftp://a%sb/` or the Connect dialog with the address `a%sb`: the name does
not resolve, the error message is composed - undefined behaviour, in practice an access
violation or garbage in the message box (not run).

**Fix:**
- `ftputils.h`: `FTPDoublePercents` (copy with every `%` doubled, bounded, a pair is never split)
  and `FTPDropCutFormatTail` (a cut format must not end in `%`).
- `ctrlcon1.cpp`: new `MakeConnectErrorFormat` - the template is printed with the escaped host,
  bounded; the four `sprintf(formatBuf, ...)` calls use it. Line 1984 is `_snprintf_s`.
- `sockets.cpp`, `GetProxyError` (the branch that returns a format): the same for `HostAddress`.

**What it does not do:** when a proxy error has no error text the format is shown as plain text
(`ctrlcon1.cpp:913`, old behaviour, the literal `%s` is visible there already); a host with `%`
now shows `%%` in that one message. Not changed - the state machine is step 6 of 130.

**Pure rules, unit cases owed** (`FTPDoublePercents`, `FTPDropCutFormatTail`): `""`; `"abc"`;
`"a%sb"` -> `"a%%sb"`; `"%"` -> `"%%"`; destination with room for one more byte before a `%` (the
pair is left out, returns FALSE); `dstSize` 1 and 0; NULL source. Tail: `"x%"` -> `"x"`,
`"x%%"` -> `"x"`, `"x%%%"` -> `"x"`, `"%"` -> `""`, `"x"` unchanged.

**Test:** GUI row - Shift+F7 `ftp://a%sb%n%s/`; expected one message box whose text contains
`"a%sb%n%s"` literally and ends with the system's reason; the program lives.

**Not sure:** the typed address is converted first (`ftputils.cpp:1363`, `1389`: `%` + two hex
digits is an escape) - `%s` is not one and stays, `%25s` becomes `%s`; read as two lines, the
function around them not. Which of the two routes (`GetHostByAddress` failing at once, line 678, or the
answer `ccsevIPReceived` with `INADDR_NONE`, line 740) a name with `%` takes; both are covered.
Whether another format is built from data elsewhere: `ctrlcon3.cpp:688` and the other
`sprintf(buf, LoadStr(...), e)` calls take the format from a resource only (read by the list of
unbounded calls, not line by line).

### 4.3 FIXED - Quick Rename with a mask: the new name was cut at 259 bytes and the file renamed to it (`fs5.cpp:545-547`)

**Note of 130:** "`lstrcpyn(newName, targetName, MAX_PATH)` `fs5.cpp:547`" in the list of name
cuts.

**Found: real, reachable.** `MaskName` writes the masked name into 520 bytes; it was copied into
the interface's `newName` (260 bytes, `fileswn5.cpp:2587`) with `lstrcpyn` and that cut text went
on to `RNFR` / `RNTO` (`ControlConnection->QuickRename`, line 606). A listing name may have 255
bytes (`parser2.cpp:652-663`), so a mask that adds five bytes is enough; the cut can fall inside a
character.

**Reach:** FTP panel, a file whose name has about 250 bytes (84 CJK letters, or 125 accented
ones), F2, new name `*.*.backup-copy`: the file is renamed to a name cut at 259 bytes, without a
word; the overwrite test of lines 550-594 is made with the cut name too.

**Fix:** `fs5.cpp`, `QuickRename`: when the masked name has 260 bytes or more the plug-in shows
`IDS_TOOLONGPATH` ("Unable to finish operation because of too long path.", caption
`IDS_FTPERRORTITLE`) and returns FALSE before anything is sent or logged - the standard dialog
opens again with the typed mask. No existing text says "name"; this is the nearest.

**Test:** GUI row - server with a file named 84 x `語` + `.txt`; F2, type `*.*.zaloha-souboru`;
expected the message, then the rename dialog again; listing unchanged (the old name is still
there, no name of 259 bytes).

**Not sure / outside my directories:** the core cuts a name TYPED without a mask the same way
before the plug-in sees it: `fileswn5.cpp:2640`
(`lstrcpyn(newName, ..., MAX_PATH); // plugin QuickRename ABI caps newName at MAX_PATH`) - a typed
name of 260 bytes or more is renamed to its first 259. **NEEDS A CHANGE OUTSIDE MY DIRECTORIES**
(refuse there). `MaskName` itself cuts at its buffer (`src/masks.cpp:189-191`) - with a name of at
most 255 and a mask of at most 259 bytes the 520-byte buffer is not reached as far as I counted.

### 4.4 FIXED (cannot be probed) - AS/400 upload: a long local name was cut before the member form (`operatsa.cpp:826-831`)

**Note of 130:** "`mbrName`: `lstrcpyn(mbrName, tgtName, MAX_PATH)` (AS/400 only)".

**Found: real in the code, reach needs an AS/400 server.** In a `/QSYS.LIB` path every name of a
listed local directory is copied into `mbrName` with a limit of 259 bytes and that copy becomes
the target name; a local name can have up to 765 bytes of UTF-8 (`operats5.cpp:2059`).

**Fix:** the member form is made only when the name fits (`strlen(tgtName) < MAX_PATH`); a longer
name goes on whole and unchanged - the server decides (such a name is no member name).

**Test:** none without an AS/400 server. `operats6.cpp:1515-1520` (`FTPAS400CutFileNamePart` into
`mbrName[MAX_PATH]`): read, every copy in it is bounded by `MAX_PATH` (`ftputils.cpp:3300-3330`)
and listing names have at most 255 bytes - not a defect.

### 4.5 Verdicts without a change

| Item of 130 | Verdict | Why |
|---|---|---|
| `operatsa.cpp:810-814` `sourcePath[MAX_PATH]` cut before `SalPathAppend` | UNREACHABLE as a wrong path | a cut `Path` has 259 bytes, the append then fails (`salamdr3.cpp:38`) and `err` is set: the explore item fails. The message is the low-memory one - wrong text, right outcome. `DoListDirectory` (`operats5.cpp:2023-2025`) refuses the same path first |
| `InitDiskWork` `operats3.cpp:302`, `306` (found on the way; the root of item 1) | LEFT - fails closed by arithmetic | see item 1. A real length test with `ITEMPR`-"too long" would be the honest form; it touches every disk work type |
| `ctrlcon3.cpp:1104`, `1335` `lstrcpyn(cutFileName, newPath, MAX_PATH)` | UNREACHABLE | the component comes from a user part of at most 259 bytes; the name is only focused |
| `ctrlcon5.cpp:579`, `583` | NOT A DEFECT | name to focus after the refresh, 520 bytes for a name of at most 300 |
| `fs5.cpp:384` `nameInCache[MAX_PATH]`, `fs5.cpp:663`, `fs4.cpp:355` `formatedFileName[MAX_PATH]` | NOT A DEFECT | a listing name has at most 255 bytes (`parser2.cpp:652-663`); `AlterFileName` does not lengthen |
| `fs2.cpp:717`, `fs5.cpp:729` `lstrcpyn(newUserPart, userPart, FTP_USERPART_SIZE)` | UNREACHABLE | user part at most 259 bytes |
| `fs2.cpp:233` reply as a path | NOT A DEFECT | a cut copy has `pathSize - 1` bytes, the test of line 259-260 then fails and `IDS_TOOLONGPATH` is shown |
| `MakeUserPart` results ignored: `fs3.cpp:276`, `752`, `fs5.cpp:126`, `505`, `614`, `1089`, `fs4.cpp:700`, `1044` | LEFT | needs user + host + path over about 505 bytes (host up to 200, path up to 300 from a server's `PWD`). The clamped text is the operation's source / target path: shown, used for change notifications and for "is an operation working on this path" (`operats2.cpp:1146-1156`, `1943-2019`). Effect of a clamp: a missing refresh. Local fix = these eight buffers at `FTP_USERPART_SIZE + 50`; not done, the consumers in the core were not read |
| `fs2.cpp:189`, `194` `GetRootPath` / `GetCurrentPath` into `MAX_PATH` | NEEDS A CHANGE OUTSIDE MY DIRECTORIES | the buffer is the interface's (`spl_fs.h:272-277`). `MakeUserPart` returns FALSE for a clamped path and the core sees it (`fileswn2.cpp:2870`). Reach: a server whose `PWD` answer is longer than the path asked for (a link); not tried |
| `dialogs1.cpp:1650`, `dialogs8.cpp:1043` names into 101 bytes | NOT A DEFECT | the names are limited to 100 bytes where they enter (`dialogs8.cpp:994`, `1005`; registry read `ftp.cpp:1561`). `DuplicateAmpersands` in the same 101 bytes can drop the tail of a check-box label - display only, LEFT |
| `GetProxyName` 101 bytes vs 199 in the dialog (`ftp2.cpp:2948`, `dialogs1.cpp:1051`) | LEFT | display only (the summary line); whether the dialog really stores 199 (`dialogs8.cpp:1619`, `1662`) was not read |
| `ctrlcon2.cpp:1973`, `dialogs2.cpp:287-326`, `dialogs3.cpp:149-194`, `dialogs4.cpp:893-928` `MAX_PATH` buffers of the file dialogs | NOT A DEFECT | `SplGetFileNameU8` refuses a picked name that does not fit `lpstrFile` (`splfiledlg.h:309-311`) |
| `dialogs6.cpp:48-49`, `dialogs7.cpp:1311`, `1366` free-space check on a cut path | LEFT | effect: a missing low-disk warning for a target that fails anyway (item 1) |
| `operats1.cpp:1558-1970` `diskPath` / `diskName` / `ftpPath` / `ftpName`, `dialogs7.cpp:193` | LEFT | fields of the Solve Error dialogs; a cut inside a character is a display matter of the later feature. The use of `DiskName` as the proposal of a new name was not followed |
| `ssl.cpp:558`, `561` `wsprintf` into `buffer[256]` with `name[200]` | LEFT - no overrun today | longest template 54 characters + 199 = 253. `ssl.cpp:666`: `ERR_error_string(err, name)` with `name[200]` while OpenSSL writes up to 256 bytes, then `sprintf` into `buffer[256]` with a 102-character template: an error string of about 150 characters would overrun `buffer`. OpenSSL's strings seen in practice are under 120; not shown reachable. Local fix when wanted: `name[256]`, bounded calls |
| unbounded `sprintf` with `GetErrorText` / a name into 460-500 bytes: `ctrlcon2.cpp:2067`, `2081`, `dialogs2.cpp:355`, `365`, `dialogs3.cpp:212`, `222`, `289`, `319-332`, `432`, `486`, `1502`, `dialogs4.cpp:984`, `996`, `dialogs1.cpp:1708`, `dialogs8.cpp:1028`, `1046`, `ftp2.cpp:2866` | LEFT - no overrun shown | measured: the longest template is 144 bytes; the names are limited to 100-199 bytes; the margin left for the system's text is over 340 bytes. These are the lines step 1 of 130 rewrites (bounded there) |
| `dialogs3.cpp:638` `buf[300]` + `errBuf[200]` | LEFT - fits | longest template 63 characters + 199 |
| `fs4.cpp:650`, `929`, `fs5.cpp:41` `subject[MAX_PATH + 200]` | LEFT - fits | longest template 56 characters + 359 = 415 of 460 |
| `fs3.cpp:50` `buffer[100]` | LEFT - fits | two button texts, longest 14 characters |
| `operats2.cpp:378` `buf[500]`, `operats3.cpp:2405` `errBuf[300]` | LEFT - fits | 61 + 200 + 99 + numbers; 43 + 199 |
| `ctrlcon2.cpp:350`, `570`, `ctrlcon3.cpp:688`, `817`, `sockets.cpp:35` | LEFT - fits | piece under 300 (700 for 817) into 500 (900); longest templates 122 / 144 bytes |
| `FTPGetErrorText` `sprintf` guarded by `bufSize > 20` | NOT A DEFECT | "(%d) " is at most 15 bytes |
| cut inside a character of shown texts (`ctrlcon2.cpp:341-345`, `ctrlcon3.cpp:69`, `CopyStr`, every `_TRUNCATE` row) | LEFT | display; belongs to the mixed-templates feature |
| `A` calls and code page on names (`sockets.cpp:745`, `ssl.cpp:258`, `926-932`, `dialogs8.cpp:618/625`, `dialogs4.cpp:176-187`, ...) | not of the three kinds | not touched |

### 4.6 Seen on the way, not in the lists, NOT fixed (for `specs/NEXT-WORK.md`)

- **Autorename of a download cuts the name by bytes**: `operats5.cpp:1188-1193` (directory) and
  `1594-1602` (file) shorten the name so that the full name fits; the cut is a byte offset
  (`rest - (suffixLen + 1)`), so it can fall inside a UTF-8 character, and the directory or file
  is then created with that torn name (`FTPCreateDirectoryU8` / the create at the retry). Reach:
  download into a deep local directory with "cannot create target: autorename" (configuration or
  the Solve Error dialog) and a non-ASCII name at the cut. The fix is three lines (move the cut
  back while `(name[cut] & 0xC0) == 0x80`); the effect of the torn name on the wide conversion was
  not measured.
- **Core, Quick Rename**: `fileswn5.cpp:2640` (4.3).
- **Core, Change Directory**: `fileswn2.cpp:2729-2730` copies the user part into 260 bytes; safe
  behind the test of line 2961, the other callers not followed (item 2).

## What a probe can drive most easily

1. 4.2 - no server needed: Shift+F7 `ftp://a%sb%n%s/`.
2. 4.3 - a local FTP server with one long-named file.
3. 4.1 - hardest: a resolvable 200-character host name (see its test).
