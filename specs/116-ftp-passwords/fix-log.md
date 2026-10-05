# Fix log: feature 116 - FTP passwords are the text that was typed

Branch `116-ftp-passwords`, from `115-undelete-leftovers` (79113272). Decisions by the author
(maintainer away, autonomy asked for): `spec.md` *Clarifications*. Measurements and code reading:
`research.md`. Pre-change build: `build\tandemcommander\Debug_x64_pre116` (copy of `Debug_x64` at
79113272, `Intermediate` folders removed). Not committed. Day mode: no GUI run (the installed
program was in use) - the probe is written, its runs are owed (`quickstart.md`).

## T001 - what was measured

- **The subclass primitive** (scratch `probe/m116_subclass.cpp`, result
  `probe/m116_subclass_result.txt`; an edit in a window that is never shown): winliblt's
  code-page attach (`SetWindowLongPtrA` + `CallWindowProcA`) on a Unicode edit - Cyrillic, CJK,
  an emoji, a lone surrogate become `?` whether typed (WM_CHAR through a W loop), set (WM_SETTEXT
  W) or read (WM_GETTEXT W); `voil<U+00E0>` typed is held by the edit but **read** as `voila`,
  set as `voila`; fullwidth `AB` -> `AB`; a typed `<U+0159>` depends on the keyboard layout's code
  page (`r` with this session's English layout). The kind-keeping attach of feature 102 and no
  subclass: everything exact through a W loop.
- **In the product, by code reading** (research 1-4): the Connect dialog's and the proxy server
  dialog's password fields had that subclass; the Connect dialog reads its password field on every
  `EN_KILLFOCUS` - so a stored UTF-8 password shown through the subclass (`????`) was **stored back
  as `????` by tabbing through the field** (new probe row `tab`); *Show password* read the field
  with `GetWindowText` A and copied code-page `CF_TEXT`; the login sends the buffer's bytes
  (UTF-8) verbatim - no `OPTS UTF8`; the stored blob (password manager scramble with a 3-digit
  length, optional AES) holds 999 bytes; older versions cut a decrypted password to 100 bytes;
  `ProcessProxyScript` expanded login commands into 301-byte buffers and `ExpandText` cuts
  silently (CRLF included); the worker passed its 1,001-byte buffer as 501.

## T003-T007 - changes

| Where | What |
|---|---|
| `src/common/salftpsecret.h` (new, header-only, includes `splunicode.h`) | `SAL_FTP_SECRET_MAX_CHARS` 100, `SAL_FTP_UTF8_MAX_BYTES_PER_UNIT` 3, `SAL_FTP_SECRET_BUF` 301, `SalFtpWorstUtf8Bytes`, `SalFtpFieldShowsStored(stored, fieldText, codePage)` - the field shows exactly what the stored bytes are shown as (UTF-8/WTF-8 as itself, else through the code page); empty stored never matches; temporary copies wiped |
| `ftp.h` | `PASSWORD_MAX_SIZE`, `ACCOUNT_MAX_SIZE`, `USERPASSACCT_MAX_SIZE` = `SAL_FTP_SECRET_BUF` (was 101); `USER_MAX_SIZE` 101, `HOST_MAX_SIZE`, `FTP_MAX_PATH` unchanged; `FTPLOGINCMD_MAX_SIZE` (1,818) and `FTPLOGIN_LONGEST_BUILTIN_LINE` (608) with a static_assert; `ProcessProxyScript`'s comment |
| `precomp.h` | includes `../../common/salftpsecret.h` before `ftp.h` |
| `ftp2.cpp` | `ProcessProxyScript` expands commands into `FTPLOGINCMD_MAX_SIZE` |
| `ctrlcon1.cpp`, `operats2.cpp` | the login command buffers `FTPLOGINCMD_MAX_SIZE`; `PrepareNextScriptCmd` wipes its command copy (it holds `PASS <password>`) |
| `operats6.cpp` | the worker passes its real buffer size (`700 + FTP_MAX_PATH`) to `PrepareNextScriptCmd`; static_assert against the longest built-in line |
| `dialogs.h`, `dialogs1.cpp` | `CPasswordEditLine` attaches with `AttachToWindowKeepKind` (no code-page `GetWindowText` for its emptiness test); `FTPSecretEditLine` (EditLine + `EM_LIMITTEXT` 100 when filling); `FTPFieldKeepsStoredValue` / `FTPFieldKeepsEncryptedValue` (decrypts, compares, wipes); `FTPShowPasswordOfEdit` (UTF-16 read, template from `LoadStrW`, composition in UTF-16, box text UTF-8, `CopyTextToClipboardW`, every copy wiped). Connect dialog: the password field filled through `FTPSecretEditLine` (the plain copy wiped), its kill-focus handler reads the field only when it does not show the stored password; Configuration's anonymous password through `FTPSecretEditLine`; the *Show password* handler calls the helper |
| `dialogs8.cpp` | `CEnterStrDlg` (a hidden field = a secret) through `FTPSecretEditLine`; `CLoginErrorDlg::Transfer` reads each of its five fields only when it does not show the value the connection used, secrets through `FTPSecretEditLine`, the backup copy wiped; `CProxyServerDlg` password field filled through `FTPSecretEditLine` (four sites in DialogProc + Transfer), the stored-bytes rule on OK (`keepStoredPassword`), the plain copy wiped after filling; its *Show password* handler calls the helper |
| `saltests.cpp`, `saltests.vcxproj` | `TestFtpSecret116` (39 checks); the header listed |

No plug-in interface change (107), no new string, no registry format or configuration version
change.

## T007 - the stored-bytes rule: first version replaced before any review

The first implementation used the edit's "modified" flag (`EM_GETMODIFY`, as 104's
`ConnectFieldFits`): an unmodified, non-empty field kept the stored bytes. Rejected by the
author's own re-read: `WM_SETTEXT` clears that flag, so a password filled in by another program
(UI Automation `ValuePattern.SetValue` - screen readers, password managers) would have been
ignored silently and the OLD password used - and this probe's own `set` rows would have failed.
Replaced by the text comparison (`SalFtpFieldShowsStored`), which changes behaviour only for a
stored value that is not UTF-8 (for UTF-8, keeping and reading give the same bytes).

## T008 - tests

saltests 14,401 -> **14,440 / 0** (`TestFtpSecret116`): 100 units of every worst kind (a, c-caron,
CJK, U+FFFF, lone high / low surrogates) convert into 301 bytes - plug-in and core converters
agree, round trip; 50 surrogate pairs = 200 bytes; 99 CJK + a lone high surrogate = exactly 300
bytes (`ED A0 BD` at the end); 20,000 random texts of 1-100 units over 12 kinds of units + pairs
all fit; 101 CJK units do NOT fit (the field limit is what makes "too long" impossible); 51
c-caron do not fit the old 101 bytes; the 0.1.8 form (60 x 0xE8) is shown as 60 c-caron in CP 1250
and re-reads as 120 other bytes; the rule's table (code-page form in 1250 / 1252, retyped text,
UTF-8, WTF-8, empty either side, NULL, case).

A Python escape trap was caught before the build: a test block written through a non-raw Python
string turned `\x01` + `0D` into a control byte and `\xC5\x99` into two characters - rewritten
through a raw string, and every added line of the diff checked for control bytes and non-ASCII
(none).

## T009 - the probe (written, runs owed)

`probe/ftppwd_probe.ps1` with `probe/ftplog_server.py` (104's server + ACCT + a CONN line per
connection): rows `uni`, `type` (7 scripts), `set` (4), `show` (box + optional clipboard), `long`
(CZ100, CJK100, LIMIT, OVER, USER), `prompt`, `tab`, `legacy` (KEEP, RETRY, RETYPE), `compat`
(FORMAT, DOWNGRADE with `-OldExe`); `-Expect before` asserts the defects on the build before;
refuses the Default desktop and a running instance; registry exported / restored / verified.
The legacy fixture is 0.1.8's scrambled blob written by the probe (`Scramble`, a port of
`ScramblePassword` with a fixed padding) - checked: the product's own `UnscramblePassword`
(compiled from `src/pwdmngr.cpp` in a scratch program) decodes the probe's blobs (60 x 0xE8,
`a`), and the probe's `Unscramble-Blob` round-trips 1 / 60 / 86 / 300 bytes. The script parses
(`Parser::ParseFile`, 0 errors).

## T010 - gates

- Debug build (`build.cmd`): exit 0, BUILD SUCCEEDED; warnings only the pre-existing C4267 in
  untouched `fs2.cpp` / `parser2.cpp` (recompiled because `precomp.h` changed).
- saltests **14,440 / 0**.
- `python tools\check_encoding.py --strict`: TOTAL 0.
- Full Release build (`build.cmd full release`): exit 0, BUILD SUCCEEDED, 189 language modules,
  runtime closure OK; the same pre-existing warnings only.
- BOM + CRLF of every touched source as at HEAD (the new header BOM + CRLF; `saltests.cpp` no BOM
  as before); clang-format: no new finding in a changed line (`ftp.h`'s macro block realigned by
  clang-format itself).

## T011 - hostile re-read of the diff

- **Password bytes never logged**: the log keeps `(hidden)`; no new `TRACE` or call-stack message
  carries a password.
- **Not left in memory longer than before**: every new copy is wiped (`SalFtpFieldShowsStored`,
  `FTPFieldKeepsStoredValue`, `FTPFieldKeepsEncryptedValue`, `FTPShowPasswordOfEdit`); copies that
  were never wiped are now (`SelChanged`'s and the proxy dialog's plain copy after filling, the
  login-error dialog's backup struct, the workers' copy of the login command in
  `PrepareNextScriptCmd`; after review T015 also the worker's `buf` after the send, `EditLine`'s
  UTF-16 copy, the SOCKS 5 login request, and what `SplWToU8` leaves after `buf[0]` on a refusal).
  **Corrected by review T015** - still not wiped (pre-existing, recorded): the panel login's
  `proxySendCmdBuf` in `StartControlConnection` (`ctrlcon1.cpp`), and the `CProxyScriptParams`
  stack copies that hold the passwords (`operats2.cpp` `PrepareNextScriptCmd` and the
  connection's start, `dialogs5.cpp` solve-error login, `ctrlcon1.cpp` `StartControlConnection`).
  The first version of this paragraph said the workers' login command was wiped as a whole - only
  `PrepareNextScriptCmd`'s copy was; the worker's own `buf` (`operats4.cpp`, holds `PASS
  <password>` after the send) was not (now it is).
- **104 B1 (a refusal never stores an empty or garbled value)**: a secret field cannot exceed its
  buffer through typing or pasting (100 units, 3 bytes each); a longer text set from outside is
  refused by the pre-check before anything is read (row `long OVER`); the rule only ever KEEPS a
  stored value or reads the field - it never stores something the field does not show.
- **The rule's edge cases**: an empty field is always read (Clear password, an undecryptable
  password - the dialogs empty the field); a locked (undecryptable) field is excluded before the
  comparison (Connect: the existing master-password condition; proxy dialog: the Unlock button's
  visibility); the comparison uses `CP_ACP`, what `EditLine` uses to show non-UTF-8 text.
- **Encryption state**: keeping the stored blob instead of re-encrypting on focus loss leaves it
  scrambled or AES-encrypted as it was; the configuration save normalises it as before
  (`ContainsUnsecuredPassword` -> `EncryptPasswords`).
- **Buffer audit** for `PASSWORD_MAX_SIZE` / `ACCOUNT_MAX_SIZE` (82 occurrences): array sizes and the bounds
  of copies, reads and wipes of those same arrays - consistent; no literal-sized password buffer exists;
  passwords in operations and proxy servers are heap strings. `ProcessProxyScript`'s four callers:
  two pass NULL buffers, two were widened.
- **Show password with a translation**: the template keeps `%s` (wide `%s` = `wchar_t*` in MSVC,
  as codeview's status line); a template with other conversions would be undefined as before.

## T015 - code-only review: ACCEPT pending GUI, fixes

The reviewer checked the stored-bytes rule against a real hidden edit (65,280 byte pairs + 200,000
random strings - the comparison matches what the field shows), the probe's scrambler round trip
for 1-999 bytes, every `PASSWORD_MAX_SIZE` / `ACCOUNT_MAX_SIZE` buffer, and PRIVACY.md (no change
needed). Fixed:

- **S1 - SOCKS 5 cut the proxy password at 255 bytes** (`sockets.cpp` `Socks5SendLogin`,
  RFC 1929 carries one length byte): reachable since 116 (the proxy password holds 300 bytes) - a
  silent cut, possibly inside a UTF-8 character, and a failed login. Now: the proxy server dialog
  refuses, for the SOCKS 5 type, a user name or password whose UTF-8 form exceeds 255 bytes
  (Windows' "too long" text, the field focused - no new string; a password the field shows from
  storage counts with its stored bytes; a locked password is not measured); and the send never
  cuts - a longer value (typed into a prompt or the login-error dialog) fails the connection with
  the proxy's "error sending request" message and the system's "too long" text
  (`pecSendingBytes` + `ERROR_FILENAME_EXCED_RANGE`). The request buffer is wiped after the send.
  The other proxies: HTTP 1.1 builds `user:password` in 500 bytes (100 + 1 + 300 fit); SOCKS 4
  sends only the user name (at most 100 bytes); the FTP-command proxies go through the login
  script (`FTPLOGINCMD_MAX_SIZE`).
- **N2 - the login-error dialog after a refusal**: `EditLine`'s backstop empties the refused value
  in place, so the stored-bytes rule then compared with "" - even restoring the original text was
  refused, only Cancel worked (e.g. a 0.1.8 code-page user name with one letter typed). Now a
  refused transfer restores the values the connection used (`proxyScriptParamsBackup`) and
  `LoginChanged` is FALSE.
- **104 B1 leftover - the proxy server dialog stored after a refusal** (pre-existing since 104):
  `Transfer` went on to `SetProxyServer` after `EditLine` had refused a field, so a 0.1.8
  code-page proxy user name of over 100 bytes that was then edited was stored EMPTY. Now nothing
  is stored when the transfer was refused (the proxy keeps its values, the field is focused) -
  104's rule "a refusal is never stored".
- **N1 - wipes**: the worker's command buffer after the send (`operats4.cpp`; `Write` keeps its
  own copy of an unsent rest), `EditLine`'s UTF-16 copy (`winliblt.cpp`, both paths - a shared
  file: no behaviour change for any plug-in), `SplWToU8`'s whole buffer on a failed conversion
  (`splunicode.h`, shared, header-only: the contract was "0 and buf[0] = 0"; the rest of the
  buffer held part of the text - saltests checks that nothing is left). The record above is
  corrected.
- **N3 (recorded)**: a kept blob keeps its encryption state - toggling *Save password* in the
  proxy server dialog no longer re-encrypts it on OK (the Connect dialog never did on the toggle);
  the configuration save normalises it as before (`ContainsUnsecuredPassword` ->
  `EncryptPasswords`).
- **N4 (CHANGELOG precision)**: the anonymous password of over 100 bytes is not cut by 0.1.8 - its
  `GetValue` into 101 bytes fails (`ERROR_MORE_DATA`), 0.1.8 uses its default and saves the default
  over it on exit. CHANGELOG says so.
- **N5 - probe**: the `show` row restores the user's clipboard in a `finally`; `-Clipboard` is
  refused while Windows clipboard history (Win+V) or the cloud clipboard is on (they would keep
  the test password - on the maintainer's machine `EnableClipboardHistory` = 1, so the quickstart
  runs without `-Clipboard`); a Master Password in use is detected up front and refused.
- **N6 (recorded, by design)**: in the Connect dialog a 0.1.8 code-page password that the user
  edits (a typo while the focus leaves the field, then corrected back to the same visible text)
  becomes the UTF-8 bytes of that text - the field's text was read once it differed; the rule
  keeps the old bytes only while the field shows exactly the stored value.

Gates after T015: Debug build exit 0 (plug-ins recompiled because `winliblt.cpp` /
`splunicode.h` changed - only pre-existing warnings, none in a changed file); saltests 14,441 / 0
(+1: the refusal leaves nothing in the buffer); strict guard TOTAL 0; full Release build exit 0;
clang-format: no new finding in a changed line; BOM / CRLF as at HEAD.

## Recorded, not changed

`research.md` 5: a password in a typed Change Directory path over 300 bytes is cut (possibly
inside a character); a custom proxy-script line over 1,000 / 1,817 bytes is still cut without
CRLF; the panel login's command buffer and the `CProxyScriptParams` stack copies are not wiped
(T015 N1); log and wait-window texts cut a long user
name inside a character; code-page subclasses on server-text displays; user name, address and
initial path keep 104's refusal (not widened - they are parts of the plug-in's paths).

## PRIVACY.md - unchanged, and why

The statement's claims about FTP: bookmarks store address, port, user name, starting folder; a
password only with *Save password*; protection by the Master Password (AES) or scrambling; FTP
is unencrypted; histories never keep a password typed in an address. None changes: the same
password manager form, the same place, the same protection; what is stored is the password as
typed (before: `?` for some characters) and now up to 300 bytes. *Show password* copies to the
clipboard as before (Unicode text instead of code-page text).

## Owed

- T013: the probe on `Debug_x64_116` (with `-OldExe Debug_x64_pre116`; `-Clipboard` only where
  clipboard history is off) and on `Debug_x64_pre116` (`-Expect before`) - `quickstart.md`.
- Optional, a person: a real keyboard / IME pass; *Show password* with a Master Password; a real
  FTP server with a non-ASCII password.

## Commit before the GUI runs

Committed after the code-only review (ACCEPT; S1 SOCKS 5 limit, N2, the 104 B1 leftover in the
proxy dialog and the cheap wipes applied) with the GUI runs still owed; the build is preserved as
`build\tandemcommander\Debug_x64_116` (ftp.spl 13:11:57). Results follow in a separate commit.

## Proposed CLAUDE.md entry (Recent Changes)

- 116-ftp-passwords: **FTP passwords are the text that was typed, in any script and up to 100
  characters.** Measured first (`research.md`; scratch `probe/m116_subclass.cpp`): the password
  fields' `CPasswordEditLine` was a code-page subclass - every character outside the code page
  became `?` or a best-fit look-alike when typed, shown or read (`voil<U+00E0>` reads as `voila`),
  and since the Connect dialog re-reads its password field on every focus loss, a password stored
  correctly (typed as `ftp://user:password@host`) was saved back as `????` by tabbing through the
  field. Now `AttachToWindowKeepKind`; *Show password* reads, composes (`LoadStrW`) and copies
  (`CopyTextToClipboardW`) UTF-16. The secrets (password, account, proxy and anonymous passwords)
  hold `SAL_FTP_SECRET_BUF` = 301 bytes - the UTF-8 of any 100 UTF-16 units their fields accept
  (`FTPSecretEditLine` keeps the 100-unit limit), so they are never "too long" or cut; login
  commands are built in `FTPLOGINCMD_MAX_SIZE` buffers (static_assert: the longest built-in line,
  `PASS $(Password)@$(ProxyPassword)`, 608 bytes) and the workers pass their real 1,001-byte
  buffer. Wire unchanged (UTF-8 bytes in USER / PASS / ACCT, no UTF8 negotiation); stored format
  unchanged (the scramble's length field takes 999 bytes) - a password over 100 bytes is cut to
  100 by 0.1.8 and older (documented). **The stored-bytes rule** (`SalFtpFieldShowsStored`,
  `src/common/salftpsecret.h`): a field that still shows exactly what the stored value is shown
  as keeps the stored BYTES, any other text is read, an empty field is always read - so a 0.1.8
  code-page password works in Connect, the proxy dialog and the login-error dialog's *Retry* (104
  T012). Do NOT use `EM_GETMODIFY` for such a decision: `WM_SETTEXT` (UI Automation, password
  tools) clears it and the filled-in text would be ignored. User name, address and initial path
  NOT widened (parts of the plug-in's paths) - 104's refusal stays. SOCKS 5 carries 255 bytes
  (RFC 1929): the proxy dialog refuses more, the send never cuts. A refused transfer never stores
  (the proxy dialog had stored an empty value since 104) and the login-error dialog restores its
  values. Shared wipes: `EditLine`'s UTF-16 copy, `SplWToU8`'s buffer on failure. Plug-in
  interface 107, no new string, PRIVACY.md unchanged (reason in fix-log). saltests 14,401 ->
  14,441. Code-only review ACCEPT pending GUI. Probe
  `probe/ftppwd_probe.ps1` (+ `ftplog_server.py`, 127.0.0.1) written, GUI runs owed. Records:
  `specs/116-ftp-passwords/fix-log.md`.
