# Research: password and passphrase encoding in the ZIP, SFTP and FTP plug-ins

Measured 2026-10-02 on the Debug build of the current tree
(`build\tandemcommander\Debug_x64`, exe built 2026-10-02 10:02, `zip.spl` and
`sftp.spl` built 2026-10-01 18:05), system code page 1250, OEM code page 852,
7-Zip 22.01 (x64). No product source was changed, nothing was rebuilt.

Labels: **[code]** read in the source, **[measured]** observed in an
experiment recorded here, **[not verified]** neither.

Test passwords (built from character codes in every probe):

| name | text | UTF-8 | code page 1250 | OEM 852 |
|---|---|---|---|---|
| ascii | `heslo123` | same | same | same |
| typed-r | `heslo-` U+0159 | `68 65 73 6c 6f 2d c5 99` | `68 65 73 6c 6f 2d f8` | `68 65 73 6c 6f 2d fd` |
| typed-c | U+043F 0430 0440 043E 043B 044C | `d0 bf d0 b0 d1 80 d0 be d0 bb d1 8c` | `3f 3f 3f 3f 3f 3f` (lossy) | `3f 3f 3f 3f 3f 3f` (lossy) |

## 1. Summary

| Plug-in | Path | What is entered | What reaches the consumer | Verdict |
|---|---|---|---|---|
| ZIP | pack, password inside the code page | Unicode edit, read with `GetDlgItemTextA` | code-page bytes into ZipCrypto keys / AES PBKDF2 | **CORRECT** (not the 7-Zip plug-in's defect): the same bytes 7-Zip 22.01 uses to open [measured] |
| ZIP | pack, a character outside the code page | same | every such character becomes `?` (0x3F), silently | **CONFIRMED DEFECT** (different from 093): the archive is encrypted with a weaker password than typed; any other text with `?` in the same places opens it; 7-Zip refuses the typed text [measured] |
| ZIP | unpack, inside the code page | same | code-page bytes; ZipCrypto also retried as OEM bytes; AES not | **CORRECT** for archives of this product and for what 7-Zip opens; **DIFFERENT ISSUE**: UTF-8-keyed archives never open, AES has no OEM retry [measured] |
| ZIP | 255-character password (the field's limit) | same | the 255th character is dropped (read count 255 includes the terminator) | **CONFIRMED DEFECT**, minor [measured] |
| SFTP | all three prompts, UTF-8 form up to 511 bytes | Unicode edit, read wide, converted to UTF-8 | UTF-8 bytes to `libssh2_userauth_password_ex` | **CORRECT** [measured for the prompt, code for the rest] |
| SFTP | UTF-8 form of 512 bytes or more | same | fallback `GetDlgItemTextA`: code-page bytes (`?` outside the code page) | **CONFIRMED DEFECT**, practically unreachable [measured] |
| SFTP | key passphrase | same function | UTF-8 bytes to `libssh2_userauth_publickey_frommemory` | **CORRECT** [code]; decryption of a key with a non-ASCII passphrase **NOT VERIFIED** by experiment |
| FTP | all password fields | `winliblt` `EditLine`: wide read, UTF-8 | UTF-8 bytes verbatim in `PASS` | **DIFFERENT, by design / unclear**: no mismatch inside the plug-in; no server-encoding option; code-page fallback above 100 bytes [code only] |
| 7-Zip | - | - | - | fixed in 093 |
| others | - | - | - | no other enabled plug-in takes a password [code] |

## 2. ZIP plug-in

### 2.1 Where the password is entered [code]

The project is an ANSI build (no `UNICODE` in `zip.vcxproj` or the shared
property sheets), so `GetDlgItemText` is `GetDlgItemTextA` and
`DialogBoxParam` is the A variant.

| Dialog | Read call | Buffer |
|---|---|---|
| Extended Pack Options (`IDD_EXPACKOPTIONS`) | `dialogs.cpp:714-715` `GetDlgItemText(Dlg, IDC_PASSWORD1 / IDC_PASSWORD2, pwd, MAX_PASSWORD - 1)`, compared with `lstrcmp`, copied to `PackOptions->Password` (`:717`) | `char[MAX_PASSWORD]`, `MAX_PASSWORD` = 256 (`config.h:26`) |
| Enter ZIP Password (`IDD_PASSWORD`) | `dialogs.cpp:1144` `GetDlgItemText(Dlg, IDC_PASSWORD, Password, MAX_PASSWORD - 1)` | caller's `char pwd[MAX_PASSWORD]` (`extract.cpp:1327`, `:1429`) |
| the self-extractor's own prompt | `selfextr/extended.cpp:430`, same call | same |

Both fields get `EM_SETLIMITTEXT, MAX_PASSWORD - 1` = 255 characters
(`dialogs.cpp:326-327`, `:1136`).

The dialogs are ANSI windows, the edit controls are Unicode windows
[measured: `dialog IsWindowUnicode=False, edit IsWindowUnicode=True` in every
row of `probe/zip_gui_result.txt`]. A code-page read from a Unicode edit gives
code-page bytes with `?` for every character the code page does not have.

The password is not passed on in the 093 way: there is no UTF-8 step and no
second conversion. The 7-Zip plug-in's defect (UTF-8 bytes read as code-page
text) does not exist here.

### 2.2 From the buffer to the cipher [code]

| Operation | Hop | Bytes |
|---|---|---|
| pack, ZIP 2.0 | `add.cpp:1624` `CryptHeader(Options.Password, ...)` -> `crypt.cpp:54-63` `init_keys` (one `update_keys` per byte) | buffer as read: code-page bytes |
| pack, AES | `add.cpp:1634` `SalamanderCrypt->AESInit(..., Options.Password, strlen(...))` (PBKDF2 in the core) | code-page bytes; more than 128 bytes -> `IDS_PWDTOOLONG` (`SAL_AES_MAX_PWD_LENGTH` 128, `spl_crypt.h:32`) |
| unpack, ZIP 2.0 | `extract.cpp:1441-1463` -> `crypt.cpp:86-103` `InitKeys`: `testkey` with the bytes as read, then, because `CHECK_OUT_OEM_PASWORD` is defined (`crypt.h:6`), `CharToOem` and `testkey` again | code-page bytes, then OEM bytes |
| unpack, AES | `extract.cpp:1344-1382` `AESInit(..., pwd, strlen(pwd), salt, &pwdVer)`, verifier compared | code-page bytes only |
| self-extractor | `selfextr/extended.cpp:514-530`, same pair as ZIP 2.0 | code-page bytes of the machine that runs the SFX, then OEM |

Check strength [code]: ZIP 2.0 has one check byte (`crypt.cpp:67-83`), so a
wrong byte string passes with probability 1/256; the plug-in then stores the
password in its cache (`extract.cpp:1463`), unpacks, reports a CRC error
(`:1608-1611`, `IDS_ERRCRC`) and deletes the file (`:1619-1620`). AES has the
2-byte verifier (1/65536) and afterwards the authentication code
(`extract.cpp:780-786`, `IDS_MACERROR`).

History [code]: `git diff v0.1.0 HEAD` for `dialogs.cpp`, `extract.cpp`,
`add.cpp` has no line with a password in it; `crypt.cpp` changed only in
feature 086 (salts). Every released version 0.1.0-0.1.8 and the current tree
use the same rule, and it is the upstream Open Salamander code.

### 2.3 What other tools do [measured]

`python probe\measure_7zip.py <scratch>` - output `probe/measure_7zip_result.txt`.

Part 1, `7z a -tzip -mem=<method> -p<typed>` (also with `-mcu=on`):

| Method | ascii | typed-r | typed-c |
|---|---|---|---|
| ZipCrypto | created | **refused**, exit 2, "System ERROR: the parameter is incorrect" | **refused** |
| AES256 | created (AE-2) | **refused** | **refused** |

7-Zip 22.01 does not create a ZIP archive with a non-ASCII password at all.
The same rule is in the 7-Zip 16.04 source this repository carried until
feature 087: `ZipHandlerOut.cpp:252` `if (!IsSimpleAsciiString(password))
return E_INVALIDARG;` [code, `git show v0.1.8:src/plugins/7zip/7za/cpp/7zip/Archive/Zip/ZipHandlerOut.cpp`].

Part 2, archives written by `probe/zipkey.py` with an exact byte string, then
`7z t -p<typed text>` and Windows' `tar.exe -xOf <arc> --passphrase <typed text>`:

| Key bytes of the archive | typed | 7z t, ZipCrypto | 7z t, AES-256 | tar, both |
|---|---|---|---|---|
| ASCII | ascii | opens | opens | opens |
| code page 1250 | typed-r | **opens** | **opens** | opens |
| OEM 852 | typed-r | refused | refused | refused |
| UTF-8 | typed-r | refused | refused | refused |
| UTF-16LE | typed-r | refused | refused | refused |
| UTF-8 read as code page, UTF-8 again (the 093 legacy form) | typed-r | refused | refused | refused |
| `??????` (lossy code page) | typed-c | refused | refused | opens |
| UTF-8 | typed-c | refused | refused | refused |

So 7-Zip 22.01 opens ZIP archives with the **code-page bytes** of the typed
text, for both methods, and refuses a password the code page cannot represent.
(16.04 used OEM for ZipCrypto and the code page for AES - `ZipHandler.cpp:739-761`,
with the comment "pkzip25 / WinZip / Windows probably use ANSI for some files" [code].)
`tar.exe` receives its arguments as code-page text, so its result says nothing
more than that.

[not verified] WinZip, Windows Explorer and 7-Zip newer than 22.01 are not
installed here and were not measured. Tools on Linux and macOS and most
libraries feed the bytes of the terminal's encoding, UTF-8 today (Python's
`zipfile` takes bytes from the caller) - known practice, not measured here.

There is no standard: APPNOTE and the WinZip AES specification define the key
derivation over password bytes and are silent about how text becomes bytes.

### 2.4 The plug-in through the product [measured]

`tools\run_on_hidden_desktop.ps1 ... zip_gui_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe`
- output `probe/zip_gui_result.txt`. The password is put into the edit by a
wide `WM_SETTEXT`, OK by `BM_CLICK`.

Unpack: the archive is written by `zipkey.py` with the byte string named in
the second column; "typed" goes into the plug-in's prompt.

| Row | Method | Archive key bytes | Typed | Result |
|---|---|---|---|---|
| U1 | ZipCrypto | ASCII | ascii | extracted, content equal |
| U2 | ZipCrypto | code page of typed-r | typed-r | extracted |
| U3 | ZipCrypto | OEM of typed-r | typed-r | extracted (the OEM retry) |
| U4 | ZipCrypto | UTF-8 of typed-r | typed-r | "The password is incorrect" |
| U5 | AES-256 | ASCII | ascii | extracted |
| U6 | AES-256 | code page of typed-r | typed-r | extracted |
| U7 | AES-256 | OEM of typed-r | typed-r | "The password is incorrect" (no OEM retry) |
| U8 | AES-256 | UTF-8 of typed-r | typed-r | "The password is incorrect" |
| U9 | ZipCrypto | `??????` | typed-c | extracted |
| U10 | ZipCrypto | `??????` | **another** six Cyrillic letters | **extracted** |
| U11 | AES-256 | `??????` | another six Cyrillic letters | **extracted** |
| U12 | ZipCrypto | UTF-8 of typed-c | typed-c | "The password is incorrect" |
| U13 | AES-256 | UTF-8 of typed-c | typed-c | "The password is incorrect" |
| U14 | ZipCrypto | ASCII | wrong ASCII text | "The password is incorrect" |

Pack: Pack dialog, packer "ZIP (Plugin)", Extended Pack Options, Encrypt,
method, password and confirmation; `zipkey.py which` then names every candidate
byte string that really decrypts the archive (check byte or verifier, then the
whole content: CRC-32 or HMAC).

| Row | Method | Typed | The archive opens with | `7z t -p<typed>` |
|---|---|---|---|---|
| P1 | ZIP 2.0 | ascii | ASCII | opens |
| P2 | ZIP 2.0 | typed-r | code page only | opens |
| P3 | ZIP 2.0 | typed-c | `??????`; the same archive also "opens" for another six Cyrillic letters | **refused** |
| P4 | AES-256 (AE-1) | ascii | ASCII | opens |
| P5 | AES-256 | typed-r | code page only | opens |
| P6 | AES-256 | typed-c | `??????`; also for another six Cyrillic letters | **refused** |
| P7 | ZIP 2.0 | `ab` U+0416 `cd` | the bytes of the ASCII text `ab?cd` | refused |
| P8 | ZIP 2.0 | 255 x `a` | **254 x `a`**; not 255 | refused |
| P9 | AES-256 | 129 x `a` | no archive; "Password too long. The maximum password length for AES encryption is 128 characters." | - |

No message is shown in P3, P6, P7, P8: the user is not told that the password
was changed.

### 2.5 Overflow and long passwords

- The read count `MAX_PASSWORD - 1` = 255 includes the terminator, so at most
  254 bytes are copied; the buffers are 256 bytes: no overflow [code]. The edit
  accepts 255 characters, the last one is dropped on packing (P8) and, by the
  same call, on unpacking - consistent inside the plug-in, wrong for every
  other tool [measured for packing, code for unpacking].
- On a double-byte system code page 255 characters can be up to 510 bytes; the
  read cuts at 254 bytes [code, not verified].
- `CharToOem(password, buffer)` in `InitKeys` writes the same number of bytes
  into `char[MAX_PASSWORD]`: no overflow [code].
- AES: more than 128 bytes is refused with a message on both sides [measured P9, code `extract.cpp:1396`].

### 2.6 Wiping (note) [code]

Nothing is wiped: no `SecureZeroMemory` or `memset` on a password anywhere in
`src/plugins/zip`. `pwd1`/`pwd2`, `PackOptions->Password`, the prompt buffer
and the per-archive cache `Passwords` (`_strdup` copies, `extract.cpp:1382`,
`:1463`) stay in memory; `init_keys` and `testkey` also put the password into
the call-stack text (`CALL_STACK_MESSAGE2("init_keys(%s, )", password)`,
`crypt.cpp:56`, `:70`), which a crash report would print.

### 2.7 Who is affected

- **Passwords inside the system code page: nobody.** Every version writes and
  reads code-page bytes, 7-Zip opens them.
- **Passwords with a character outside the system code page** (Cyrillic or
  Greek on a Central European system, emoji anywhere): every archive made by
  any version of this product (and by Open Salamander) is encrypted with `?` in
  place of each such character. It is weaker than the user believes (U10, U11),
  7-Zip refuses the real password (P3, P6, P7; it opens with literal `?`
  typed), and on a machine whose code page *does* have those characters this
  product also refuses the real password, because there it sends the real
  code-page bytes [code].
- **Another system code page than the one that made the archive**: the bytes
  differ, the password is refused. Inherent in the code-page rule, the same in
  7-Zip [code, not verified by experiment].
- **Archives keyed with UTF-8 bytes** (other platforms): never open (U4, U8, U12, U13).
- **AES archives keyed with OEM bytes**: do not open (U7); ZipCrypto ones do (U3).

### 2.8 Recommended fix (smallest safe scope)

Reading: read the fields wide (`GetDlgItemTextW`, count `MAX_PASSWORD`), keep
the typed text as UTF-16 and derive byte strings from it; this also ends the
254-character cut.

Packing - which bytes new archives should use:

1. Text the system code page can represent: **code-page bytes, unchanged**.
   It keeps every archive of every earlier version compatible in both
   directions and is the form 7-Zip 22.01 opens (2.3). Moving to UTF-8 here
   would make new archives unreadable by 7-Zip and by every installed earlier
   version of this product.
2. Text the code page cannot represent
   (`WideCharToMultiByte(CP_ACP, WC_NO_BEST_FIT_CHARS, ..., &usedDefault)`):
   never write the `?` form again. Either **refuse with a message** (what
   7-Zip does, for all non-ASCII) or encrypt with the **UTF-8 bytes**. Refusing
   is the smaller change and cannot produce an archive no installed tool opens;
   UTF-8 is the more useful one if the unpack side below is done in the same
   change. A decision for the specification.

Unpacking - ordered candidates derived from the typed text, identical byte
strings tried once, an ASCII password has exactly one:

| # | Bytes | Opens archives made by |
|---|---|---|
| 1 | code page, strict | this product (all versions), Open Salamander, what 7-Zip writes and opens |
| 2 | OEM (`CharToOem` of 1) | DOS-era and console tools; today for ZipCrypto only - extend to AES |
| 3 | UTF-8 | other platforms; this product's new archives if 2. above chooses UTF-8 |
| 4 | code page with `?` (today's lossy read) - only when the text is not representable | **this product's existing archives with out-of-code-page passwords**; without it they stop opening |

Where: `extract.cpp:1344-1410` (AES: cache, prompt, verifier),
`extract.cpp:1441-1470` and `crypt.cpp:86-103` `InitKeys` (ZipCrypto),
`dialogs.cpp:714-717` and `:1144`. The cache `Passwords` can keep holding the
byte string that worked.

False positives: with AES every candidate costs 1/65536 and the authentication
code catches it. With ZipCrypto each extra candidate adds 1/256: four
candidates let a wrong password through the check in about 1.6 % of cases
(today 0.8 %), ending in a CRC error instead of "incorrect password", and an
earlier candidate can pass by chance although a later one is the right one.
Today's code already has that property with two candidates and stores the
falsely accepted password in the cache. The safe form is the 093 rule: when an
encrypted ZipCrypto item ends in a CRC error, try the remaining candidates
before reporting, and cache a byte string only after the content verified.

Out of the smallest scope, recorded: the self-extractor stub (a separate ANSI
program with its own prompt, ZipCrypto only), wiping, the password in the
call-stack text.

## 3. SFTP plug-in

### 3.1 Where secrets are entered [code]

All three sites call the plug-in's own `GetDlgItemTextU8`
(`dialogs.cpp:33-58`): `GetWindowTextW`, then `SplWToU8`
(`shared/splunicode.h:221-234`: strict UTF-8, WTF-8 for an unpaired surrogate,
0 when the buffer is too small); **when the result is 0 it falls back to
`GetDlgItemTextA`** (`dialogs.cpp:56-57`).

| Site | Call | Buffer |
|---|---|---|
| password / passphrase prompt (`ShowPasswordPrompt`, `IDD_PASSWORD`, `IDE_PROMPTPASSWORD`) | `dialogs.cpp:121` | caller's: `Params.Password` / `Params.Passphrase`, `char[512]` (`session.h:64`, `:66`) |
| Connect dialog, password | `dialogs.cpp:835` | `char pwd[512]` -> `ConnectPlainPassword[512]` (`:848`) |
| Connect dialog, passphrase | `dialogs.cpp:887` | `char pass[512]` -> `ConnectPlainPassphrase[512]` (`:893`) |

The prompt is used for: a path opened without stored parameters
(`fs.cpp:562`), a connection with no password yet (`fs.cpp:114`), an encrypted
key (`fs.cpp:129`), and the feature-051 retries `cpPassphrase`
(`session.cpp:985`) and `cpPassword` (`session.cpp:996`). No field has a text
limit. The same code is in v0.1.0, v0.1.2 and v0.1.8 (`git show <tag>:src/plugins/sftp/dialogs.cpp`);
it dates from feature 024, before the first release.

### 3.2 From the buffer to libssh2 [code]

| Consumer | Call | Bytes |
|---|---|---|
| password | `session.cpp:720-721` `libssh2_userauth_password_ex(..., Params.Password, strlen(...))` | UTF-8 |
| keyboard-interactive | `session.cpp:730`, callback `:96-110` copies the same buffer | UTF-8 |
| key passphrase | `session.cpp:669-671` `libssh2_userauth_publickey_frommemory(..., Params.Passphrase)` | UTF-8 |

RFC 4252 section 8 requires the password in UTF-8; OpenSSH derives key
encryption from the passphrase bytes as typed, UTF-8 on current systems.

Storage: `EncryptPassword(pwd, ...)` (`dialogs.cpp:865`, `:906`) and
`DecryptPassword` (`fs.cpp:41`) of `CSalamanderPasswordManagerAbstract`
(`spl_gen.h:767-798`) carry a zero-terminated byte string in and out
unchanged, so a stored secret is the UTF-8 form it was typed as, in every
released version. `DecryptInto` refuses a secret that does not fit (`fs.cpp:46-49`).

### 3.3 Experiment [measured]

Docker is not available: no `docker.exe` on the machine (not on `PATH`, not in
`C:\Program Files\Docker`), both WSL distributions stopped; nothing was
started. Instead `probe/sshlog_server.py` (paramiko 5.0.0 in a scratch
environment, 127.0.0.1:2223) logs the bytes of every password offered and
refuses the login. `probe/sftp_gui_probe.ps1` drives the product: Change
Directory to `sftp:probe@127.0.0.1:2223/`, host key trusted, the text set into
the plug-in's prompt (edit 630). Output `probe/sftp_gui_result.txt`.

| Row | Typed | UTF-8 length | The server received |
|---|---|---|---|
| S1 | ascii | 8 | `68 65 73 6c 6f 31 32 33` - equal |
| S2 | typed-r | 8 | `68 65 73 6c 6f 2d c5 99` - equal to UTF-8 |
| S3 | typed-c | 12 | `d0 bf d0 b0 d1 80 d0 be d0 bb d1 8c` - equal to UTF-8 |
| S4 | 255 x U+0159 | 510 | 510 bytes `c5 99 ...` - equal to UTF-8 |
| S5 | 256 x U+0159 | 512 | **256 bytes `f8 f8 ...`** - code-page bytes, not UTF-8 |
| S6 | 256 x U+0416 | 512 | **256 bytes `3f 3f ...`** - question marks |

The prompt is an ANSI dialog with a Unicode edit (`dialog IsWindowUnicode=False,
edit IsWindowUnicode=True`).

### 3.4 Verdict and fix

Correct for every realistic secret. The one defect is the fallback: a secret
whose UTF-8 form needs 512 bytes or more is sent as code-page text, silently,
and cut at 511 bytes. Smallest fix: the three secret reads must not fall back -
when the UTF-8 form does not fit, say "too long" and send nothing (or read into
a heap buffer and compare with the limit). The fallback inside
`GetDlgItemTextU8` also serves name fields; that is outside this question.

Wiping (note) [code]: done in most places (`dialogs.cpp:871`, `:912`,
`fs.cpp:51`, `:88-106`, `session.cpp:984`, `:995`); the wide heap copy inside
`GetDlgItemTextU8` is freed without being wiped (`dialogs.cpp:54`).

### 3.5 Not verified

- The Connect dialog's two fields through the product (same function as the
  measured prompt) [code only].
- A key with a non-ASCII passphrase actually being decrypted (classic PEM and
  the openssh-key-v1 path of feature 051) - no experiment; the bytes handed to
  libssh2 are UTF-8 by the measured read.
- Keyboard-interactive, and a stored bookmark's round trip through the
  password manager with and without a Master Password [code only].
- Acceptance by a real OpenSSH server (the logging server shows the wire bytes
  only).

## 4. FTP plug-in [code only]

- Every password field goes through the shared `CTransferInfo::EditLine`
  (`shared/winliblt.cpp:1128-1142`): wide read, strict UTF-8 into the caller's
  buffer, and when that does not fit, a code-page `WM_GETTEXT`. Sites:
  `dialogs1.cpp:1002`, `:1867` (`IDE_PASSWORD`), `dialogs8.cpp:1151`, `:1156`,
  `:1636` (proxy), `dialogs1.cpp:103` (anonymous). Buffers are
  `PASSWORD_MAX_SIZE` = 101 bytes (`ftp.h:15`).
- The bytes replace `$(Password)` in the login script (`ftp2.cpp:1583`,
  scripts `ftp2.cpp:2021-2081` "PASS $(Password)") and are sent as they are.
  The server-name conversion `FTPU8NameToServer` (`ftputils.h:312-331`) is
  applied to names in commands (`ctrlcon2.cpp:77-144`), not to the password.
  There is no server-encoding option; `ftputils.h:312-315` says so for names.
- So `PASS` carries UTF-8, the encoding RFC 2640 asks for. No hop decodes the
  buffer with the code page: **not the 093 defect**. What is unclear: a server
  whose accounts were created with code-page passwords cannot be logged in to
  with a non-ASCII password (Open Salamander sent code-page bytes; the change
  came with feature 005, before 0.1.0), and nothing documents it.
- Same family as SFTP row S5: the field is limited to 100 *characters*, the
  buffer to 100 *bytes*, so a password with 51 or more two-byte characters
  takes the code-page fallback [not verified].
- Display only: "show password" reads the field with `GetWindowText` (A) at
  `dialogs1.cpp:1363` and `dialogs8.cpp:1992` and shows or copies those
  code-page bytes [not verified].
- Stored bookmarks: bytes in, bytes out through the password manager, like SFTP.

## 5. Other enabled plug-ins [code]

`grep -i "assword\|assphrase"` over the 20 enabled plug-ins of `plugins.cfg`:
only 7zip (093), zip, sftp and ftp take a secret. `uncab.h:120` declares an
unused `Password` field; uniso only detects a protected `.isz`; checksum and
undelete match in vendored library text.

## 6. Probes

| File | What |
|---|---|
| `probe/zipkey.py` | candidate byte strings of a password (Windows conversions), which of them open each item of an archive, archives written with an exact byte string |
| `probe/measure_7zip.py`, `measure_7zip_result.txt` | section 2.3 |
| `probe/zip_gui_probe.ps1`, `zip_gui_result.txt` | section 2.4 (23 instances, all exit code 0) |
| `probe/sshlog_server.py`, `probe/sftp_gui_probe.ps1`, `sftp_gui_result.txt` | section 3.3 (needs a python with paramiko: `-Python`) |

The GUI probes ran only through `tools\run_on_hidden_desktop.ps1`; no
`tandemcommander.exe` from `C:\Program Files` was running. Registry
`HKCU\Software\Tandem Commander`: SHA-256 of the export before each run, after
each restore and in a final independent export:
`F5305AEA4A533D939417C4FA2978D09BA56654DF17C3E82DB7C473ACD1987DC1`.
Scratch (`%TEMP%\tc094_pwd`, `tc094_zip`, `tc094_sftp`, `tc094_sftp_run`, the
two registry backups) removed; no test process left.
