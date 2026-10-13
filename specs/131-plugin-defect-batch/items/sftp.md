# Feature 131, items of `src/plugins/sftp` (SFTP Client)

> **Correction (review):** "every caller checks" was not true for one of the 19 calls of
> `PosixPathAppend` (the link target lookup in `ListCurrentPath`, read-only) - it checks now.
> `LocalPathAppend` refuses an empty directory. The "SFTP error %d: %s" sentence was wrong in
> seven languages, not only Czech - corrected and pinned.


Read in full: `operats.cpp`, `session.cpp`, `fs.cpp`, `sftputils.cpp/.h`, `session.h`, `fs.h`,
`sftp.h`, `logs.cpp` (Append / AppendFmt), `lang/lang.rc2`, parts of `dialogs.cpp`,
`listing.cpp`, `sftp.cpp`; in the core the callers of the FS interface (`src/fileswn2.cpp`,
`fileswn3.cpp`, `fileswn5.cpp`, `fileswn8.cpp`, `fileswna.cpp`, `fileswnb.cpp`), the contract
comments of `src/plugins/shared/spl_fs.h`, and in libssh2 `src/common/dep/libssh2/src/sftp.c`
(readdir, open, the status handling).

What was run: the plug-in's own unit harness (`src/plugins/sftp/test/build_and_run.cmd` - it
copies `sftputils.cpp` into `%TEMP%` and builds it there): **85 passed, 0 failed**, with 23 new
checks; a compiler **syntax check** (`cl /Zs`, no output files, started from the scratch
directory) of `fs.cpp`, `operats.cpp`, `session.cpp`, `sftputils.cpp` with the project's
include paths and defines: exit 0, no warning at `/W3`; `tools/check_encoding.py --strict`:
`TOTAL: 0`. **Not built, not linked, not run, no server contacted.** Line numbers are those
after the change.

Changed files: `fs.cpp`, `fs.h`, `operats.cpp`, `session.cpp`, `session.h`, `sftputils.cpp`,
`sftputils.h`, `test/harness.cpp`. No new resource string, no interface change, nothing outside
`src/plugins/sftp`.

---

## 0. The real limits (asked for by item 1)

| What | Limit | Evidence |
|---|---|---|
| FS user part the core accepts for a path change (`user@host:port/path`) | **< 260 bytes** (`MAX_PATH`), refused above with the core's "too long path" | `src/fileswn2.cpp:2961-2967`, `src/fileswn3.cpp:2046` |
| FS user part of an upload target (F5 disk -> SFTP) | < 260 bytes, refused above | `src/fileswn8.cpp:788-794` |
| `GetCurrentPath` / `GetRootPath` buffer | 260 bytes, by contract | `spl_fs.h:242, 272`; e.g. `src/fileswn2.cpp:3154` |
| `GetFullName` buffer | `2 * MAX_PATH - l` (about 510 bytes) | `src/fileswn9.cpp:2162`, `fileswn8.cpp:1534`, `shellsup.cpp` |
| Download target the core hands to `CopyOrMoveFromFS` | buffer of 520 bytes (`2 * MAX_PATH`), modes 2 / 3 / 5 | `src/fileswna.cpp:113-141`, `fileswnb.cpp:269-270` |
| New name of quick rename / create directory | 260 / 520 bytes | `src/fileswn5.cpp:2587, 2102` |
| Upload source path (`sourcePath` = the disk panel's path) | up to `SAL_MAX_PATH_UTF8` (98,302 bytes) | `src/fileswnd.h:504, 583`, `fileswn8.cpp:877` |
| The plug-in's current remote path `Path` | 3,072 bytes (`fs.h:55`); since this change its user part always fits 260 bytes (see 1.3) | |
| Remote path buffers of the operations | 4,096 bytes (`operats.cpp`), 3,072 bytes (`fs.cpp`) | |
| One name of a listing | <= 2,046 bytes (`nameBuf[2048]`, `session.cpp` `ListDir`); libssh2 answers `LIBSSH2_ERROR_BUFFER_TOO_SMALL` for a longer one and the listing **ends there silently** (`sftp.c:1856-1858`, `session.cpp` `rc <= 0 -> break`) | not changed, see 4 |
| Local name made from a remote name | 511 bytes (`safe[512]`) | `operats.cpp` |
| Local path buffers | 4,096 bytes UTF-8, 4,096 UTF-16 units (a UTF-8 text never has more units than bytes, so the wide buffer is large enough by construction) | `operats.cpp` |
| SFTP protocol / libssh2 | no path limit of their own: the length is a 32-bit field, libssh2 allocates the request from the length (`sftp.c` `sftp_open`, `sftp_unlink`, ...); incoming packets are limited to 256 KB (`LIBSSH2_SFTP_PACKET_MAXLEN`, `sftp.c:99`) | |
| A real server (OpenSSH on Linux) | path 4,095 bytes (`PATH_MAX`), one name 255 bytes (`NAME_MAX`) - from knowledge of the platform, **not measured here** | |

Consequences:

- With a Linux server the top-level 4,096-byte joins of `operats.cpp` (current path + one name)
  cannot overflow (3,071 + 1 + 255). The **recursive** joins can: a tree whose paths pass 4,095
  bytes (16 nested directories with 250-byte names), and any server that sends longer names.
- The 3,072-byte joins of `fs.cpp` could overflow only when the current path was far longer
  than the core ever asks for - which happened through the server's answer to `realpath` (a
  symbolic link to a deep directory): `ChangePath` adopted the resolved path whatever its length.
- The download target and the two new names fit their buffers by construction; the upload
  source path does **not** (it was copied into 3,072 bytes).
- Local paths longer than 259 characters depend on the process being long-path aware
  (`src/manifest.xml` has `longPathAware`; the system setting was not looked at):
  `MakeLocalWidePath` adds no `\\?\` prefix. Not changed.

---

## 1. Paths cut and then used as paths

**Note of 130:** `operats.cpp:306, 403, 532, 581, 619`, `fs.cpp:907-909, 934`,
`PosixPathAppend` - `_snprintf_s(_TRUNCATE)` / `lstrcpynA`, the result used as a path.

**Found: REAL.** `PosixPathAppend` cut silently and returned the cut text; every caller used
it. All places where a remote or local path is composed into a fixed buffer, and what became of
each:

### 1.1 `operats.cpp` (transfers, delete, attributes)

| Place (function) | Was | Effect of a cut | Now |
|---|---|---|---|
| `DownloadDir` (child of a directory) | `rpath[4096]`, `safe[512]`, `lpath[4096]` cut | the cut remote path is opened (another file, or "cannot download"); a cut local path is **another local file** that is then written (after the overwrite question when it exists) | refused: item skipped, result `xrFailed` (so a move deletes nothing) |
| `SFTPDownloadFromPanel` (selected items) | same | same; on a move the cut remote path was then **deleted** (`Unlink` / `Rmdir`) | refused: `ok = FALSE`, no transfer, no delete |
| `SanitizeLocalName` | byte clamp at `outSize - 1`; the reserved-name prefix `_` cut by `lstrcpynA` | a remote name of 512 bytes or more became a shorter local name (two remote names -> one local file) | returns `FALSE`, the item is refused |
| `UploadDirRecursive` mask `"%s\\*"` | `pattern[4096]` cut | the mask is lost or another directory is searched | refused before the remote directory is created |
| `UploadDirRecursive` child | `lpath`, `rpath` cut | another local file is read / the upload creates another remote name | refused, `ok = FALSE` |
| `DeleteLocalTree` mask and child (move disk -> SFTP) | `pattern`, `child` cut | **`DeleteFileW` on a cut local path** | nothing is deleted for that entry; the directory stays (`RemoveDirectoryW` fails on what is left). After the change this cannot be reached with a path that passed `UploadDirRecursive` (same buffers), it is a guard |
| `SFTPUploadToFS` source | `srcBase[3072]` = `lstrcpynA(sourcePath)` | a panel path of 3,072 bytes or more was cut: **another local path is uploaded and, on a move, deleted** | `srcBase` is gone, `LocalPathAppend(sourcePath, name, lpath[4096])` refuses |
| `SFTPUploadToFS` target | `rpath` cut | cannot overflow (target < 260 bytes + one name), checked all the same | refused |
| `DeleteRecursive` child | `child[4096]` cut | **`Unlink` / `Rmdir` / listing of a cut remote path** (a sibling whose name is the cut prefix); the result of the child was ignored | refused; the entry stays, so the parent's `Rmdir` fails and reports "Cannot remove directory" |
| `SFTPDeleteFromPanel` | `rpath` cut | delete of another item of the panel's directory | refused, `ok = FALSE` |
| `ChmodRecursive` / `ChownRecursive` child, `SFTPChangeAttrsFromPanel` / `SFTPChangeOwnerFromPanel` | cut | `chmod` / `chown` / set-time of another path | refused (logged) |
| `label[256]` (two dialogs) | `lstrcpynA`, display only | a torn last character made the whole label go through the code page | `SplU8CopyTrunc` |
| `ConfirmOverwrite` `msg[1400]` | display only | a local path over about 1,300 bytes pushed the question itself ("Overwrite it?") out of the box | `msg[4096 + 200]`, trimmed at a character if ever cut |
| `WaitText` `msg[1024]` | display only | torn character | trimmed only when cut |
| `DownloadOneFile` / `UploadOneFile` wide paths `[4096]` | - | fit by construction (see 0) | unchanged |

Refusal in this file = `ReportTooLongPath` (`operats.cpp:171`): one log line per skipped item
(`Path too long, item skipped: <dir> -> <name>`, English like the other log lines) and the
box `IDS_TOOLONGPATH` ("Unable to finish operation because of too long path.", an existing
string of the plug-in, translated) **once per operation** - a deep tree would otherwise show
it for every item. The operation reports failure, so the core does not deselect / a move keeps
its sources.

### 1.2 `sftputils.cpp` - the two pure rules

- `PosixPathAppend(dir, name, dst, size)` (`sftputils.cpp:229`): same result as before when it
  fits; when it does not, `dst` is empty and the function returns `NULL`. **Every** caller
  checks (11 in `operats.cpp`, 7 in `fs.cpp`; `grep PosixPathAppend` shows no unchecked call).
- New `LocalPathAppend(dir, name, dst, size)` (`sftputils.cpp:253`): `dir\name`, no doubled
  backslash when `dir` ends with one (so `C:\` + `x` is `C:\x`, it was `C:\\x`), `FALSE` and an
  empty `dst` when it does not fit.

An empty buffer is never used as a path (an empty remote path means "the home directory" to a
server): the callers return before any use.

### 1.3 `fs.cpp` (panel side)

| Place | Was | Now |
|---|---|---|
| `MakeUserPart` (`fs.cpp:319`) | `void`, cut at the buffer | `BOOL`; `FALSE` + empty buffer when it does not fit; all 8 callers act on it |
| `GetCurrentPath` (260-byte buffer of the core) | **returned TRUE with a cut path** whenever `user@host:port` + path reached 260 bytes | returns `FALSE` instead of a cut path - and cannot fail any more, see `ChangePath` |
| `ChangePath` | adopted the server's `realpath` answer of any length up to 3,071 bytes | a resolved path whose user part does not fit 260 bytes is **not adopted**: the path stays as requested (it names the same directory, and the core only asks for user parts under 260 bytes). If even that does not fit (the port or IPv6 brackets written out add a few bytes): box `IDS_TOOLONGPATH`, `FALSE` (`fs.cpp:653-655, 708-714`). So `Path` + `user@host:port` is always under 260 bytes, and with a name of at most 2,046 bytes every 3,072-byte join below fits by construction; they are checked all the same |
| `ParseUserPart` path part | `lstrcpynA` cut | `FALSE` when it does not fit; `ChangePath` then shows `IDS_TOOLONGPATH` instead of "host name is missing" (guard: the core hands in < 260 bytes) |
| `GetFullName` | cut name / cut user part, returned TRUE | `FALSE`, empty buffer |
| `GetFullFSPath` | cut, `success = TRUE` (the core then changes to that path) | box, `success = FALSE`; `path` is written only when all of it fits |
| `GetRootPath` | own `_snprintf_s`, cut; **no brackets around an IPv6 host** | through `MakeUserPart("/")`: not cut, and the same form as every other path of the FS (for a non-IPv6 host the text is identical to before) |
| `ExecuteOnFS` up-dir and sub-directory (`cur`, `userPart`, `full[3072]`) | cut -> the panel went to another directory | box, no path change; a focus name that does not fit `MAX_PATH` is not passed (no focus instead of a cut name) |
| `ExecuteCommandLine` (`cd <path>`) | `target[3072]` cut, joins cut | no copy (the command text is used directly), refused with a box, nothing posted |
| `QuickRename` `from` / `to` | cut: **another item renamed / the item gets a cut name** | box, `FALSE` (the core reopens its rename dialog) |
| `CreateDir` `full` | cut: **a directory of another name created** | box, `FALSE` |
| `ViewFile` `remote`, `uniqueName[3200]` | cut remote path = another file viewed; a cut unique name is the **cache key of another file** | box, nothing downloaded |
| `ViewFile` cache name -> wide | `return` on a failed conversion **without `FreeFileNameInCache`** | no early return: an empty wide path makes `CreateFileW` fail and the existing failure path releases the name |
| `CopyOrMoveFromFS` `localTarget[2 * MAX_PATH]` | `lstrcpynA` | fits by construction (0); a longer one is refused |
| `CopyOrMoveFromDiskToFS` mode 1 (target offered in the Copy dialog) | cut target offered | not offered: `FALSE`, the dialog opens with an empty target (contract of mode 1) |
| `ConnectSFTPServer` `userPart[3072]` | - | fits by construction (255 + 255 + 1,023 + port), checked |
| `ChangePath` `cutFileName` (`lstrcpynA(..., MAX_PATH)`), `GetPathForMainWindowTitle`, `GetChangeDriveOrDisconnectItem`, `EnsureConnected` log label, `ShowInfoDialog` | display / focus only | unchanged |

**How a user reaches it (before the fix):**

1. *Rename / create directory / view on a cut path* - on the server a symbolic link in the home
   directory to a directory whose path is about 2,900 bytes; Enter on the link in the panel
   (`realpath` gives the long path, `Path` becomes it); then F7 with a 250-byte name: the
   directory is created with the name cut at byte 3,071 and no message. Also visible without any
   operation: the panel's path line / history / "other panel" path show a path cut at 259 bytes.
2. *Recursive operations* - a remote tree deeper than 4,095 bytes of path (or a server with
   names over 255 bytes): F8 on its top, or F5 to disk, or Change Attributes with "recursively".
3. *Upload from a long local path* - a disk panel whose path has 3,072 UTF-8 bytes or more
   (long paths enabled), F6 to the SFTP panel: files of **another** directory would be
   addressed and deleted after the upload. Seen by reading only; needs long local paths.
4. *A name of 512 bytes or more* on a server that allows it, F5 to disk: stored under a cut name.

On the test container (Linux, `NAME_MAX` 255) rows 1 and 2 can be built; 4 cannot.

**Pure functions and the unit cases** (in `test/harness.cpp`, all green):

- `PosixPathAppend`: fits exactly (`"/abc" + "de"` in 8 bytes), one byte too long -> `NULL`
  and `dst[0] == 0` (the buffer held text before), root + name at the limit and one over,
  directory with a trailing slash at the limit and one over, size 0.
- `LocalPathAppend`: plain join, no doubled backslash after `C:\`, the `*` mask fits / is one
  byte too long (-> `FALSE`, empty), size 0.
- Worth adding to `saltests` if these two move to `src/common` one day: a name holding a
  multi-byte character at the limit (the rule is byte length, so nothing special happens - a
  check would pin that no half character is ever written), `dir == NULL`, empty name.
- `SanitizeLocalName` stays `static` in `operats.cpp` (not reachable from the harness). Cases a
  check should cover: 511 bytes pass, 512 refused; `CON` and `con.txt` get `_`; a reserved name
  of 511 bytes is refused (the added `_` does not fit); `.`, `..`, `"a. "` (trailing dot and
  space stripped), a name of only dots -> `_`.

**Not sure about:**

- `ChangePath` keeping the *requested* path when the resolved one does not fit (`fs.cpp:653`):
  the requested form may contain `.` / `..` or a link name, which the panel then shows as it is,
  and the up-dir (`..`) cuts it by text. Chosen over refusing the directory altogether. Not run.
- `GetCurrentPath` / `GetFullName` returning `FALSE` (`fs.cpp:460`, `fs.cpp:475`): the callers in
  the core that were read test the result, but what each then shows was not read for every
  call site. By construction `GetCurrentPath` cannot fail after the `ChangePath` rule.
- The box of `ReportTooLongPath` is shown while the wait window is up (as the other error
  boxes of this file are).
- `ChangePath` returning `FALSE` with a box in mode 1 (refresh), where the contract asks for
  silence about a path that does not exist - this is another kind of error, but not run.

---

## 2. Error reason stale or empty

**Note of 130:** `Mkdir`, `Rmdir`, `Unlink`, `OpenRead`, `OpenWrite`, `Chmod`, `Chown` appear
never to set `LastErrorText`.

**Found: REAL**, all seven, plus `Symlink` and `SetMTime`, and the `Sftp == NULL` exit of
every operation (also of `ListDir` and `Rename`). Each returned the result of the libssh2 call
and nothing else (`session.cpp`, the bodies before the change). `LastErrorText` is otherwise
written only by the connect sequence, `ListDir` and `Rename`, so:

- a session that connected without any failure: the reason was **empty** - Czech
  `Nelze odstranit „x“: ` with nothing after the colon;
- after a failed rename or listing: **that** text (e.g. `opendir: SFTP Protocol Error`) under
  every later "Cannot delete / create directory / download / upload";
- after a key that needed its passphrase twice: the text of the unlock failure.

Reached by: F8 on a file in a directory without write permission (`IDS_ERR_DELETE`), F7 there
(`IDS_ERR_MKDIR`), F5 of an unreadable file (`IDS_ERR_DOWNLOAD`), F5 into a read-only
directory (`IDS_ERR_UPLOAD`), F8 on a non-empty directory whose content cannot be removed
(`IDS_ERR_RMDIR`); `IDS_ERR_CHMOD` / `IDS_ERR_CHOWN` go to the log only.

**Second finding:** even where the text was set, it said almost nothing. libssh2 reports
every refusal of the server as one session error - `"SFTP Protocol Error"`,
`"Failed opening remote file"` (`sftp.c:1306, 2001, 2859, ...`); *why* is in the SFTP status
code (`libssh2_sftp_last_error`), which the plug-in never read.

**Fix** (`session.cpp:182-224`, `session.h`):

- `SetLastErrorFromSftp(prefix)`: when the session's last error is `LIBSSH2_ERROR_SFTP_PROTOCOL`
  and the SFTP layer holds a status, the reason is
  - `IDS_ERR_PERMDENIED` "Permission denied." for status 3 (and 12, write protect),
  - `IDS_ERR_DISKFULL` for 14 / 15, `IDS_ERR_NOTADIR` for 19 - three strings that existed in
    the plug-in, translated, and were **used nowhere** (`grep`),
  - else `IDS_ERR_GENERIC` "SFTP error %d: %s" (also existing and unused) with the code and its
    English name from the new pure `SftpStatusName` (`sftputils.cpp:276`), e.g.
    `SFTP error 2: No such file`, `SFTP error 4: Failure`;
  - any other failure (transport, timeout, memory) goes to `SetLastErrorFromSsh` as before.
  UTF-8 at every step (`LoadStrU8`, ASCII names, trimmed only when cut) - feature 130's rule.
- `SetLastErrorNotConnected()`: `IDS_ERR_NOTCONNECTED` (existing, was unused) for `Sftp == NULL`.
- `Mkdir`, `Rmdir`, `Unlink`, `Symlink`, `Chmod`, `Chown`, `SetMTime`, `OpenRead`, `OpenWrite`
  call one of the two on every failing exit; `ListDir` and `Rename` now use the same function
  (`opendir: Permission denied.` instead of `opendir: SFTP Protocol Error`). `Chown` with
  nothing to change (the dialog refuses that earlier) leaves `IDS_OG_NEEDFIELD`.
- Stale text: every operation whose failure is shown writes the text on **each** failing exit,
  and each caller reads it right after the failing call with no other session call in between
  (`operats.cpp` `DownloadOneFile`, `UploadOneFile`, `DeleteRecursive`, `ChmodRecursive`,
  `ChownRecursive`, `DownloadDir`; `fs.cpp` `ListCurrentPath`, `QuickRename`, `CreateDir`).
  `Stat`, `ReadLink`, `RealPath`, `Read`, `Write` do not write it - their failures are never
  shown with the reason (`IDS_ERR_READREMOTE` / `IDS_ERR_WRITEREMOTE` have no `%s`).

**Probe rows** (container `tandem-sftp`, `localhost:2222`; prepare in the user's upload
directory: `mkdir ro && touch ro/f.txt && chmod 555 ro`, `touch secret.txt && chmod 000 secret.txt`;
language Czech, so the reused texts are visibly translated):

| # | Action | Expect (text of the message box, read with `GetWindowTextW` of the static) |
|---|---|---|
| R1 | first action of a fresh session: enter `ro`, F8 on `f.txt`, confirm | `Nelze odstranit „/…/ro/f.txt“: Oprávnění odepřeno.` - before: nothing after the colon |
| R2 | in `ro`: F7, name `nový` | `Nelze vytvořit adresář „nový“: Oprávnění odepřeno.` |
| R3 | F5 of `secret.txt` to a local directory | `Nelze stáhnout „…/secret.txt“: Oprávnění odepřeno.` |
| R4 | F5 of a local file into `ro` | the upload message with `Oprávnění odepřeno.` |
| R5 | **stale control**: F2 on `ro/f.txt` -> `g.txt` (fails), then go up and F8 on a directory that is not empty and holds an undeletable file | the second box carries its own reason (`... SFTP ...: Failure` or permission denied), not the rename's text; before the fix both boxes ended with the same text |
| R6 | Change Attributes on `ro/f.txt` as a user who does not own it, then Plugins > SFTP Client > Show Logs | a log line `Nelze změnit oprávnění …: Oprávnění odepřeno.` |
| R7 | F3 / F5 on a name that was removed on the server after the listing | reason `… 2: No such file` in the "SFTP error" sentence |

Unit cases: `SftpStatusName` 2, 3, 4, 21, 22 and `0xFFFFFFFF` (in the harness). The mapping of
status to string id sits in `session.cpp` (needs the resource ids) - 3 and 12 -> permission,
14 and 15 -> space, 19 -> not a directory, 0 -> the session's text, others -> generic.

**Not sure about:**

- Which status an OpenSSH server sends for each case was not measured (a non-empty directory
  is expected to be `4 Failure`, version 3 of the protocol has no finer code).
- libssh2 never clears the session's error code after a success (`misc.c:93`, `session.c:607`
  are the only writers). A failing call that returned without recording an error would let
  `SetLastErrorFromSsh` show the library's previous text. Every failing exit of the SFTP calls
  read in `sftp.c` records one; the SFTP status itself is reset at the start of each request
  (`sftp.c:1160, 2791, 2900, 3451, 3559, 3668, 3809`). Residual, in the library.
- The Czech translation of `IDS_ERR_GENERIC` is `"%d o chybě SFTP: %s"`
  (`translations/czech/sftp.slt:224`) - the placeholders are right, the wording is not. The
  string was unused until now; a pin in `translations/ui-overrides.json` is the maintainer's
  step (outside my directories).

---

## 3. Untranslated English literals

Checked against the 87 strings of `lang/lang.rc2` and the dialog services of `spl_gen.h`
(`DialogError`, `DialogOverwrite`, `DialogQuestion`).

| Literal | Where | Verdict |
|---|---|---|
| `"Downloading %s ..."` | `operats.cpp` `DownloadRecursive` (2 sites) | **REPLACED** by the existing `IDS_DOWNLOADINGFILE` "Downloading %s..." (the text `ViewFile` already shows; Czech `Stahování %s...`), as a UTF-8 sentence: `LoadStrU8` + `CSFTPMsgText(name)` (`operats.cpp:378, 385`) |
| `"Uploading %s ..."` | `operats.cpp:605, 698` | LEFT - no existing string |
| `"Deleting %s ..."` | `operats.cpp:798` | LEFT - no existing string (`IDS_CONFIRM_DELETE` is a question) |
| overwrite question `"The local file already exists:\n%s\n\nOverwrite it?\n(Yes = this file, No = skip; hold nothing - use Cancel to skip the rest)"` | `operats.cpp:204` | LEFT - no string of the plug-in says it (`IDS_RESUME_OVERWRITE` is the resume question). The core has a translated service, `CSalamanderGeneralAbstract::DialogOverwrite` (`spl_gen.h:917-920`, buttons Yes / All / Skip / Skip all / Cancel), which could replace it; not done here: it needs the size / date lines of both files and changes the answers the user can give - a change to verify in the GUI, not a text swap |
| `"Close"` | `dialogs.cpp:1301` (the Connect button in Organize Bookmarks) | LEFT - the only translated "Close" of the plug-in is the caption of a button inside the `IDD_LOGS` template, not a string |
| `"%d item(s)"` | `operats.cpp:866, 948` | LEFT |
| `"Server: %s\nPort: %d\nUser: %s\nPath: %s"` | `fs.cpp:936` | LEFT |
| `"Select the SFTP panel and use the Create Symbolic Link command from there."` | `sftp.cpp:788` | LEFT |
| `"Cannot initialize the SSH/Winsock subsystem."` | `sftp.cpp:148` (`MessageBox`, at load) | LEFT |
| `"Server did not present a host key."`, `"Cannot verify the server's host key: no fingerprint available."`, `"Cannot create SSH session."` | `session.cpp:485, 552, 851` (shown by the connect error box) | LEFT |
| `"Out of memory."` | `sftp.cpp:33` | LEFT |
| `"All files\0*.*\0Private keys\0..."` | `dialogs.cpp:1268` (file dialog filter) | LEFT |
| `"Path too long, item skipped: %s -> %s"` (new, feature 131) and all other log lines | `operats.cpp:173`, `session.cpp` | log only, English like the rest of the log |

Probe row: language Czech, F5 of a remote file large enough to take a few seconds: the wait
window's text is `Stahování <name>...`; before: `Downloading <name> ...` (`WaitText` creates
the window with delay 0, so it is up for the whole transfer).

Not sure about: the wait window was not seen; the sentence is built like `fs.cpp:1107`, which
feature 130 fixed and whose probe row was also "NOT DRIVEN".

---

## 4. Other notes of feature 130's record of this plug-in

| Note of 130 (`triage/sftp.md`, section 4) | Found | Done |
|---|---|---|
| `operats.cpp:529-530` `char name[1024]` from `WideToUtf8`, result not checked | real as written, **not reachable**: a name of the file system has at most 255 UTF-16 units = 765 bytes, and `WideCharToMultiByte(CP_UTF8, 0)` does not fail on an unpaired surrogate (it writes U+FFFD) | the result is checked now (`UploadDirRecursive`, `DeleteLocalTree`) |
| `Utf8ToWide` "strict: a local name with an unpaired surrogate does not convert; `MakeLocalWidePath` gives an empty path" | **half right**: with flags 0 the call does not fail - it replaces the surrogate's bytes by U+FFFD characters, so the path names a file that does not exist ("Cannot open local file"), and `WideToUtf8` did the same in the other direction (a local file with such a name could not be uploaded from inside a directory). Fails closed, no wrong file touched | `Utf8ToWide` tries `SplU8ToW` (WTF-8) first and keeps the lenient conversion for text that is not UTF-8 at all (a remote name in another encoding still downloads under a U+FFFD name, as before); `WideToUtf8` is `SplWToU8` (total). `fs.cpp` cache name: `SplU8ToW` |
| `SanitizeLocalName` byte clamp can cut inside a character | real | no cut any more (1.1) |
| `label[256]` | display only | `SplU8CopyTrunc` |
| log lines cut at 1,024 bytes; `SetWindowTextA` with a resource text alone; a remote name that is not UTF-8 is read as code-page text in messages while the panel shows `?` | as described, by design | unchanged |

Seen on the way, **not changed** (candidates for `specs/NEXT-WORK.md`):

- **A listing ends silently at the first name of 2,047 bytes or more** (`session.cpp` `ListDir`:
  `rc <= 0 -> break` also for `LIBSSH2_ERROR_BUFFER_TOO_SMALL`, and for any read error in the
  middle): the panel shows a shortened directory as if it were complete, `ListDir` returns
  `TRUE`. A recursive delete then fails on the non-empty directory; a recursive download is
  incomplete without a message, and a **move** deletes what it transferred (the rest stays on
  the server, nothing is lost). Needs a server with such names (not Linux).
- `CopyOrMoveFromFS` mode 2 takes what the user typed as the target directory without the
  core's path handling (returns `TRUE` at once): a relative path or a mask is used as it is
  (`fs.cpp:1168-1210`). Not examined further.
- Error boxes `msg[1200]` with a remote path of up to 4,095 bytes: the reason at the end is cut
  off for a path over about 1,100 bytes (display only; trimmed at a character since 130).
- A remote name that is not UTF-8: two different names can map to one local name (U+FFFD for
  each bad byte); the overwrite question appears for the second one.
- `ExecuteOnFS` builds `userPart + "/" + name`, which at the root gives `user@host:22//name`
  (the server's `realpath` normalises it).
- `MakeLocalWidePath` comment says "long-path-capable" but adds no `\\?\` prefix.

---

## Probe rows for item 1 (container `tandem-sftp`, a person or the maintainer's probe)

Preparation on the server (shell in the container, in the user's writable directory `U`):

```
# A: a directory about 2,900 bytes deep, reached through a short link
d=$(printf 'd%.0s' $(seq 1 240)); p=U; for i in $(seq 1 12); do p=$p/$d; done
mkdir -p "$p" && touch "$p/file.txt" && ln -s "$(realpath "$p")" U/deep
# B: a tree that passes 4,095 bytes: 16 levels of 250-byte names, created step by step
#    (relative, so the last directory - about 4,040 bytes - and its files can exist);
#    the files in it have 250-byte names: directory + "/" + name is about 4,290 bytes
e=$(printf 'e%.0s' $(seq 1 250)); f=$(printf 'f%.0s' $(seq 1 250))
cd U && mkdir tree && cd tree && for i in $(seq 1 16); do mkdir "$e" && cd "$e"; done
touch "$f" "${f}.txt"; pwd -P | wc -c        # must print less than 4096
```

| # | Action | Before | Expect now |
|---|---|---|---|
| P1 | Enter on `deep` in the panel | the panel lists the deep directory; the path line and what `GetCurrentPath` gives the core (history, the path offered to the other panel) are cut at 259 bytes | the panel lists the same directory, the path line shows `…/U/deep` (the requested path), nothing cut |
| P2 | in `deep`: F7, name of 250 `x` | (before, with the 2,900-byte current path) a directory with a shorter name appears, no message | the directory `xxx…` (250) is created under `U/deep` |
| P3 | in `deep`: F2 on `file.txt`, new name of 250 `y` | renamed to a cut name | renamed to all 250 bytes |
| P4 | F8 on `tree` (answer the confirmation) | the two files are addressed by paths cut at 4,095 bytes: a box `Nelze odstranit „…“` for each, naming a path that ends in a shortened `fff…` (the server is asked to delete that other name) | one box `Nelze dokončit operaci kvůli příliš dlouhé cestě.`, then `Nelze odstranit adresář …` for the directories that are not empty; the log has two lines `Path too long, item skipped: … -> fff…`; both files are still there (check on the server) |
| P5 | F5 of `tree` to `C:\t` | the cut remote paths are opened ("cannot download", or another file's content if a name equal to the cut one exists); local names are cut the same way when long local paths work | the same box once, the operation ends as failed, nothing stored under a shortened name in `C:\t` |
| P6 | command line of the SFTP panel: `cd ` + 3,100 characters | the panel changes to some shortened path or shows the core's error | box "too long path", no path change |
| P7 | NOT DRIVABLE on this server: a name of 512 bytes or more (needs a server without the 255-byte limit) | | |
| P8 | owed to a person: disk panel in a path of 3,072 UTF-8 bytes or more, F5 of one file to the SFTP panel | another local path is read | box "too long path", nothing uploaded |

P4 / P5 trigger only if the server lists the 16th level (its own path must stay under 4,096
bytes - the `wc -c` line of the preparation) while the files in it are beyond 4,095. In P5 the
local side reaches the limit of Windows paths long before (16 levels of 250 characters), so
the deep levels fail with "cannot open local file" on a machine without long paths; the row
that matters there is "no shortened name". The script and the rows were **not tried**.
