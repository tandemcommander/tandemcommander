# Feature 130 triage: `sftp` (SFTP Client)

Read: every `LoadStr(` use in `src/plugins/sftp/` (121 hits: `dialogs.cpp` 24, `fs.cpp` 18,
`listing.cpp` 6, `operats.cpp` 36, `session.cpp` 24, `sftp.cpp` 12, `sftp.h` 1), all of
`operats.cpp`, the error / log / prompt code of `session.cpp`, `logs.cpp`, the text helpers and
dialog procedures of `dialogs.cpp` that show a composed text, and in the core the sinks named
below. Not built, not run. Line numbers are those after the change.

## 1. Encodings - what was established, with evidence

| Text | Encoding | Evidence |
|---|---|---|
| host, user, key file, initial path (`Params.*`, `Host`, `User`) | UTF-8 | read with `GetDlgItemTextU8` (`dialogs.cpp:835-838`, W API + `SplWToU8`); key file opened with `SplU8ToWExtAlloc` (`session.cpp:635`) |
| local paths (`localPath`, `targetLocalPath`, names from the enumerator) | UTF-8 | `operats.cpp:24-43` (`MultiByteToWideChar(CP_UTF8)` before every W file API), `operats.cpp:530` (`WideToUtf8`) |
| a name in the panel (`file.Name`) | valid UTF-8 always | `listing.cpp:101-105` `SanitizeUTF8` (bytes that break UTF-8 replaced) |
| the **real** remote name / path (`SFTPRealName`, `Path`, `remotePath`, `remoteDir`, `e->Name`) | the server's bytes - UTF-8 by convention, **not guaranteed** | `listing.cpp:149-150` ("may have had invalid UTF-8 bytes replaced" - the real name is kept unsanitized), `session.cpp` `ListDir` (`_strdup(nameBuf)`), `fs.cpp:908` |
| `Session.GetLastErrorText()` (`LastErrorText[512]`) | was: a `LoadStr` text (code page), or `LoadStr` template + UTF-8 host / key file (**itself a mix**), or `LoadStr` + `": "` + libssh2's text, or an English constant. **Now UTF-8 in every case** | writers: `session.cpp:166-170, 192, 379, 390, 395, 408, 435, 501, 528, 629, 641, 656-659, 671, 695, 704, 714, 749, 801, 818, 844, 929, 977` (complete list by `grep LastErrorText`) |
| libssh2's message (`libssh2_session_last_error`) | English constants of the library (ASCII) as far as read; now passed through `CSFTPMsgText` anyway | `session.cpp:164-169` |
| key type, fingerprints | ASCII | `hostkeys.cpp:160-170`, `keyType` from the key file's header |
| `LoadStr(id)` | code page | `sftp.cpp:97-100` |

Sinks:

| Sink | Takes | Evidence |
|---|---|---|
| `SalamanderGeneral->SalMessageBox` text | UTF-8 when valid, else code page | the brief; `src/msgbox.cpp:1241-1277` |
| `CreateSafeWaitWindow` message | UTF-8 when valid (`SalU8ToWAlloc` + `DrawTextW`), else `DrawText` A; the caption goes to `CreateEx` (A) | core `src/dialogs3.cpp:2649-2661, 2813-2820, 2693` |
| the plug-in's own dialogs: `SetDlgItemTextU8` (password / passphrase prompt, host key text, rename prompt, chmod / owner labels) | UTF-8 when valid (`SetDlgItemTextW`), else `SetDlgItemTextA` | `dialogs.cpp:21-29, 154, 234` |
| **the log** | every line is appended to ONE buffer (`logs.cpp:94-159`) which is shown whole with `SetDlgItemTextU8` (`logs.cpp:224`): one line that is not valid UTF-8 made the **whole log** go through the code page - every remote path in it garbled | `logs.cpp` |
| `ListBoxAddStringU8` | UTF-8 when valid, else A | `dialogs.cpp:68-76` |
| there is no progress dialog of the plug-in: transfers show the core's wait window (`operats.cpp:134-141` `WaitText`) | | |

## 2. Compositions

`U8` = UTF-8, `CP` = code page. "name*" = the server's bytes (see 1), now passed as
`CSFTPMsgText(x).Get()` (valid UTF-8 kept, anything else read as code page - what the sinks'
fallback did with it).

| Where | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `session.cpp:192` | `IDS_ERR_RESOLVE` | host U8 | `LastErrorText` -> message box (`fs.cpp:403`), log | **FIXED** |
| `session.cpp:395` | `IDS_ERR_CONNECT` | host U8, port | same | **FIXED** |
| `session.cpp:641` | `IDS_ERR_KEYFILEMISSING` | key file path U8 | same | **FIXED** |
| `session.cpp:656` | `IDS_ERR_KEYTYPEUNSUP` (`keyReason`) | key type ASCII | same | **FIXED** (reverse rule: `LastErrorText` is a piece of the sentences below) |
| `session.cpp:379, 390, 408, 528, 629, 658, 671, 695, 704, 714, 749, 929, 977` | a text alone copied into `LastErrorText` (`IDS_CANCELLED`, `IDS_ERR_TIMEOUT`, `IDS_ERR_HOSTKEYDECLINED`, `IDS_ERR_NOAUTHMETHOD`, `IDS_ERR_AUTHKEY`, `IDS_ERR_KEYUNLOCK`, `IDS_ERR_CONNLOST`, `IDS_ERR_AUTHPASSWORD`, `IDS_ERR_KEYPUTTY / KEYPKCS8`) | - | `LastErrorText` -> log line, `%s` of the sentences below | **FIXED** (`LoadStrU8` + `SplU8CopyTrunc`; reverse rule and the one-text log) |
| `session.cpp:166-170` `SetLastErrorFromSsh` (`818` `IDS_ERR_HANDSHAKE`, `844` `IDS_ERR_SFTPINIT`, `1082` `"opendir"`, `1246` none) | `"%s%s%s"` | prefix now `LoadStrU8` / ASCII; libssh2 text | `LastErrorText` | **FIXED** |
| `session.cpp:905` | `IDS_CONNECTING` | host U8 | wait window | **FIXED** |
| `session.cpp:990-993` | `IDS_ENTERPASSPHRASE` / `IDS_ENTERPASSPHRASE_RETRY` | key file path U8 | `ShowPasswordPrompt` -> `SetDlgItemTextU8` | **FIXED** |
| `session.cpp:1004`, `fs.cpp:113`, `fs.cpp:563` | `IDS_ENTERPASSWORD` | user U8 | same | **FIXED** |
| `fs.cpp:129` | `IDS_ENTERPASSPHRASE` | key file path U8 | same | **FIXED** |
| `session.cpp:1020`, `fs.cpp:382` | `IDS_RECONNECTING` | host U8 | log | **FIXED** |
| `fs.cpp:667` | `IDS_ERR_LISTDIR` | `Path` name*, `LastErrorText` | message box | **FIXED** |
| `fs.cpp:913` | `IDS_ERR_RENAME` | `file.Name` U8, `LastErrorText` | message box | **FIXED** |
| `fs.cpp:942` | `IDS_ERR_MKDIR` | typed name U8, `LastErrorText` | message box | **FIXED** |
| `fs.cpp:993` | `IDS_DOWNLOADINGFILE` | `file.Name` U8 | wait window | **FIXED** |
| `operats.cpp:211` | `IDS_ERR_DOWNLOAD` | remote path name*, `LastErrorText` | message box + log | **FIXED** |
| `operats.cpp:224`, `435` | `IDS_ERR_OPENLOCAL` | local path U8 | message box | **FIXED** |
| `operats.cpp:293` | `IDS_ERR_LISTDIR` | remote dir name*, `LastErrorText` | message box | **FIXED** |
| `operats.cpp:327` | `IDS_SYMLINK_DIR_SKIPPED` | remote path name* | log | **FIXED** |
| `operats.cpp:446` | `IDS_ERR_UPLOAD` | remote path name*, `LastErrorText` | message box | **FIXED** |
| `operats.cpp:680` | `IDS_ERR_RMDIR` | remote path name*, `LastErrorText` | message box | **FIXED** |
| `operats.cpp:691` | `IDS_ERR_DELETE` | remote path name*, `LastErrorText` | message box | **FIXED** |
| `operats.cpp:739` | `IDS_ERR_CHMOD` | remote path name*, `LastErrorText` | log only | **FIXED** |
| `operats.cpp:818` | `IDS_ERR_CHOWN` | remote path name*, `LastErrorText` | log only | **FIXED** |
| `dialogs.cpp:222, 231` | `IDS_HOSTKEY_CHANGEDTEXT`, `IDS_HOSTKEY_NEWTEXT` | `host:port` U8, key type and fingerprints ASCII | `SetDlgItemTextU8` | **FIXED** |
| `dialogs.cpp:297` `ShowResumePrompt` | `IDS_RESUME_OVERWRITE` | remote base name name* | message box | **FIXED** |
| `logs.cpp:102` `CLogs::Append` | none | any line | the log | **FIXED** as a guard: a line that is not valid UTF-8 (a remote name in another encoding inside one of the English lines, e.g. `session.cpp:1228` `"Rename %s -> %s"`) is converted, so it cannot turn the whole log into code-page text; `logs.cpp:170` and `session.cpp:155` trim a tail cut by `_TRUNCATE` |
| `sftp.cpp:511-512` About | `IDS_ABOUT` | `VERSINFO_VERSION`, `VERSINFO_COPYRIGHT` (literals; the second holds `©`) | message box | RIGHT AS IS (all code page: no `/utf-8` in `plugin_base.props`, the literal is compiled into the build machine's code page - not verified by a build) |
| `operats.cpp:164-168` `ConfirmOverwrite` | English literal | local path U8 | message box | RIGHT AS IS (ASCII + UTF-8); untranslated, see 4 |
| `operats.cpp:134-141` `WaitText("Downloading %s ..." / "Uploading" / "Deleting")` | English literal | name | wait window | RIGHT AS IS (ASCII + name; a name that is not UTF-8 goes through the code page as before); untranslated, see 4 |
| `fs.cpp:852` `ShowInfoDialog` | English literal | host, user, path | message box | RIGHT AS IS |
| `session.cpp` `LogFmt("Connecting to %s:%d as %s ...")` and the other English log lines | English literal | host, user, paths | log | RIGHT AS IS (and guarded by `logs.cpp:102`) |
| `fs.cpp:403` | none (`LastErrorText` alone) | - | message box | RIGHT AS IS (now always UTF-8) |
| `dialogs.cpp:1385, 1412, 1454` `ShowRenameDialog(hwnd, LoadStr(IDS_BOOKMARKNAME), name)` | prompt and name are two controls | - | `SetDlgItemTextU8` each | RIGHT AS IS (never combined) |
| `dialogs.cpp:997` `ListBoxAddStringU8(lb, LoadStr(IDS_QUICKCONNECT))` | alone | - | A fallback | RIGHT AS IS |

Everything else is a text alone: captions (`IDS_SFTPERRORTITLE`, `IDS_PLUGINNAME`, ... -
untouched, as the brief says), `SalMessageBox(LoadStr(x), ...)` without arguments
(`operats.cpp:249, 259, 281, 476, 494, 658`, `fs.cpp:509`, `dialogs.cpp:648, 852, 858, 1441,
1469`), dialog titles and a button (`dialogs.cpp:220, 226, 230, 1300` - `SetWindowTextA` /
`SetDlgItemTextA`), the wait window's first text `LoadStr(IDS_PLUGINNAME)` (`operats.cpp:390,
598, 703, 787, 869`, `fs.cpp:652`), menu items and column names (`sftp.cpp:715-725`,
`listing.cpp:220-245`, `fs.cpp:1216`), `SetBasicPluginData` (`sftp.cpp:153, 156`).

Added: `LoadStrU8` (`sftp.cpp:102-105`), its declaration and the small `CSFTPMsgText` class in
`sftp.h` (which now includes `splloadstru8.h`).

## 3. How to reach the fixed sites

All need a server (the test container `tandem-sftp`, `localhost:2222`) and a language whose
texts have letters above ASCII - in Czech and German **every** sentence with a name has them,
because the translations quote names with `„ “` (`translations/czech/sftp.slt` 80, 84, 86, 87,
92, 132). So before the fix: a remote or local name with an accented letter is garbled in all
of them; an ASCII name looks right.

- **Mark 1 - create directory that fails** (`fs.cpp:942`): in an SFTP panel, in a directory
  without write permission (or where the name already exists), F7, name `Příliš žluťoučký`.
  Message: `Nelze vytvořit adresář „Příliš žluťoučký“: <reason>`. The typed name is in the
  message box's text, exact.
- **Mark 2 - list a directory that cannot be read** (`fs.cpp:667`): on the server
  `mkdir 'žluťoučký' && chmod 000 'žluťoučký'`, Enter on it in the panel:
  `Nelze zobrazit obsah adresáře „/.../žluťoučký“: opendir: ...`.
- **Mark 3 - the log** (`logs.cpp:102`, `session.cpp`, `fs.cpp:382`): Plugins > SFTP Client >
  Show Logs after (a) a failed connect to a host that does not resolve - the line
  `Nelze vyřešit název hostitele „...“.` - and (b) any `Rename a -> ž` in a session. Before:
  as soon as one translated line is in the log, every accented remote path in the whole log
  is garbled; after: all lines readable. Read the edit `IDE_LOGTEXT` with `GetWindowTextW`.
- Quick rename that fails (`fs.cpp:913`): F2 on `žluťoučký.txt` in a read-only directory.
- Delete that fails (`operats.cpp:680 / 691`): F8 on an accented name in a directory without
  write permission.
- Download of an unreadable remote file (`operats.cpp:211`), upload into a read-only directory
  (`operats.cpp:446`), upload of a local file that is locked (`operats.cpp:435`).
- Password prompt (`fs.cpp:113 / 563`, `session.cpp:1004`): a connection without a stored
  password and a user name with a letter above ASCII (German `Gib das Passwort für %s ein:`).
  Passphrase prompt (`fs.cpp:129`, `session.cpp:990`): an encrypted key in a folder with an
  accented name.
- Wait window `Stahování %s...` (`fs.cpp:993`): F3 on an accented name; shown only when the
  download takes over 500 ms. `Připojování k %s...` (`session.cpp:905`): the host is ASCII in
  practice - visible only with an internationalised host name typed as such.
- Host key dialog (`dialogs.cpp:222 / 231`): first connect to a host; the host is ASCII in
  practice, so the text was right before unless the host has a letter above ASCII.
- Resume question (`dialogs.cpp:297`): download a file whose smaller partial copy exists
  locally (at least `Config.ResumeMinFileSize`).

## 4. Other things seen (not changed)

- **The reason in most messages is stale or empty.** `LastErrorText` is written only by the
  connect path, `ListDir` (`"opendir"`) and `Rename` (`session.cpp:1082, 1246`). `Mkdir`,
  `Rmdir`, `Unlink`, `OpenRead`, `OpenWrite`, `Chmod`, `Chown` do not set it (by `grep`; their
  bodies were not read line by line), so `IDS_ERR_MKDIR / RMDIR / DELETE / DOWNLOAD / UPLOAD /
  CHMOD / CHOWN` print the reason of an **earlier** failure - or nothing. Worth an item of its
  own.
- Untranslated English texts composed in code: `operats.cpp:164` (overwrite question, with a
  hint "hold nothing - use Cancel to skip the rest"), `operats.cpp:330, 337, 541, 626, 715`
  (`"Downloading %s ..."`, `"Uploading"`, `"Deleting"`), `fs.cpp:852`, `sftp.cpp:788`,
  `dialogs.cpp:1301` (`"Close"`), `operats.cpp:779, 853` (`"%d item(s)"`), `session.cpp:435,
  502, 801`, all log lines. `IDS_DOWNLOADINGFILE` exists for one of them.
- Paths cut silently by `_snprintf_s(..., _TRUNCATE)` / `lstrcpynA` where the result is **used
  as a path**: `operats.cpp:306, 403, 532, 581, 619` (`lpath[4096]` / `child[4096]`, `"%s\\%s"`),
  `sftputils.cpp:235-239` `PosixPathAppend`, `fs.cpp:907-909` (`from[3072]`, `to[3072]`),
  `fs.cpp:934` (`full[3072]`), `operats.cpp:776, 850` (`label[256]`, display only). A cut
  path names another file or directory (standing rule "a path is never cut", 097/098/101).
  `operats.cpp:529-530` `char name[1024]` from `WideToUtf8` - a failed conversion leaves the buffer
  as it was and the result is not checked.
- `operats.cpp:24-27` `Utf8ToWide` uses `CP_UTF8` (strict): a local name with an unpaired
  surrogate (WTF-8, feature 066/089) does not convert; `MakeLocalWidePath` then gives an empty
  path. `fs.cpp:977` the same for the cache name.
- `operats.cpp:49-61` `SanitizeLocalName` works byte-wise and its `outSize` clamp
  (`safe[512]`) can cut a UTF-8 name inside a character.
- `session.cpp:146-156`, `logs.cpp:161-171`: log lines are cut at 1,024 bytes (now at a whole
  character).
- `dialogs.cpp:220, 226, 230, 1300`: `SetWindowTextA` / `SetDlgItemTextA` with a resource text
  alone - right, noted because the dialogs are created with the W API elsewhere.
- A remote name that is not valid UTF-8 is read as code-page text in messages (before and
  after); the panel shows it with `?` (`SanitizeUTF8`). The two views of one name differ.
