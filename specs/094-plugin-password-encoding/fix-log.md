# Fix log: feature 094 - ZIP and SFTP password forms

Branch `094-plugin-password-encoding`, from `main` (492aca7a).
Decisions by the author (maintainer away): `spec.md` *Clarifications*.

## T001 - measurement

See `research.md`. In short: neither plug-in has the 7zip plug-in's defect.
ZIP reads the field through the code page: a password outside the code page
is used as `?` characters (confirmed through the product); archives keyed
with UTF-8 bytes never open; AES archives keyed with OEM bytes do not open.
SFTP sends exact UTF-8 below 512 bytes and code-page bytes at or above.
FTP: UTF-8 bytes verbatim, not changed.

## S1 - ZIP

**The typed text is UTF-16 from the field to the place that keys or opens an
item; byte forms are derived there** (`src/common/salzippwd.h`, header-only,
saltests `TestZipPassword094`).

| What | Where |
|---|---|
| forms `acp` / `oem` / `utf8` / `oldread`, representability (no best fit, no default character), the pack form, the ordered distinct candidates, wipe | `src/common/salzippwd.h` |
| pack options: both fields read wide (`GetDlgItemTextW`, all 255 characters), exact comparison, buffers wiped on every exit | `dialogs.cpp` `CPackDialog::OnOK` |
| prompt: wide read into the caller's `WCHAR[MAX_PASSWORD]` | `dialogs.cpp` `CPasswordDialog::OnOK`, `PasswordDialog`; `dialogs.h` |
| the typed text in the options (`WCHAR Password`), wiped in the destructor | `common.h` `CExtendedOptions` |
| the pack form, derived once per operation, wiped in the destructor | `add_del.h/.cpp` `CZipPack::GetPackPassword`, `PackPassword`; used in `add.cpp` (`CryptHeader`, `AESInit`) |
| the passwords of one operation: `CZipPwdEntry` (all forms + `Preferred`), wiped when released | `extract.h`, `CZipUnpack::Passwords` |
| AES: every form of every typed password against the verifier | `extract.cpp` `CZipUnpack::AESTryPassword`, `ExtractSingleFile` |
| classic: every form that passes the check byte; when more than one passes, the one the content verifies with | `extract.cpp` `ClassicCollect`, `ClassicChoose`, `ClassicVerify` (+ `VerifyRead`, `VerifyRefill`, `VerifyFlush`), `ExtractSingleFile` |
| a form is remembered (`Preferred`) only after the item verified | `extract.cpp` `ExtractSingleFile`, at the "checksum is right" branch |
| `InitKeys` tests ONE byte string (the OEM retry is a candidate now); no password in the call-stack text | `crypt.cpp` `InitKeys`, `init_keys`, `testkey`; `crypt.h` |

**Forms.** `oldread` is what versions up to 0.1.8 read from the field: the
code-page conversion with best fit and `?`, **cut to 254 bytes**. The
contract calls it `lossy` and says it exists only for a text that is not
representable; the 254 cut makes it differ for a representable text of 255
characters too, so it is simply added whenever its bytes are new. Without it
an archive an earlier version made with a 255-character password would stop
opening.

**Packing.** `acp` when representable, else `utf8`. The AES limit of 128
bytes is tested by `AESInit` on that form, with the existing message. A
consequence that follows from the specification: 65 or more Cyrillic letters
(130 bytes of UTF-8) are now refused for AES with "Password too long", where
the old code keyed with 65 question marks.

**Self-extracting archives keep the old read**, including `?` and the 254
cut (`SalZipPwdPackForm(..., selfExtractor)`): the stub is a separate program
with its own prompt (`selfextr/extended.cpp:430`, `GetDlgItemTextA`, count
255), which is not changed, so the archive must be keyed with what that
prompt will produce. A password outside the code page is therefore as weak in
a self-extractor as before; recorded, not fixed. Correction of `research.md`:
the stub does **not** retry with OEM bytes - `CHECK_OUT_OEM_PASWORD` came
from `crypt.h`, which the stub never included.

**The stub is untouched.** Its projects (`vcxproj/selfextr`, `sfxmake`,
`zip2sfx`) compile `selfextr/*`, `sfxmake/*`, `zip2sfx/*` and from the
plug-in's folder only `bits.cpp`, `deflate.cpp/.h`, `trees.cpp`,
`chicon.cpp/.h`, `iosfxset.cpp/.h`, `config.h`, `typecons.h` - none of them
is in this change (`crypt.cpp` is not shared). `zip2sfx` is in the solution
and built; `selfextr` and `sfxmake` are not part of `salamand.sln`.

**Unpacking - the design, and where it departs from the plan.** The plan
described a restart: unpack with the first form that passes the check and,
when the checksum fails, discard the output and start again with the next
one. Implemented instead: **verify first, write once.**

1. Per item, every form of every password typed in this operation is tested
   against the item's check (AES: verifier; classic: check byte), the form an
   earlier item verified with first.
2. Classic encryption only, and only when **more than one** byte string
   passes the check byte: `ClassicVerify` reads the item, decrypts and
   unpacks it into the sliding window **without any output, question or
   progress** and compares the checksum - the same comparison the real
   unpacking makes. The first form that verifies is used. When none does, or
   the routine cannot tell (a method other than stored / deflate / deflate64,
   a multi-volume archive, a read error), the first passing form is used: the
   behaviour before this feature.
3. Then the unchanged path runs exactly once: overwrite question, output
   file, unpacking, checksum, the old error handling.

Why this and not the restart: nothing is ever written with a wrong form, so
there is no partial file to discard, no overwrite question that could be
asked twice and no error prompt inside the decompressors to suppress - the
things the 093 reviews found wrong in a restart. The price is reading the
item twice in the rare case (two forms pass: 1 in 256 per extra form). State
added: `CurPwdEntry` / `CurPwdForm` (which form the current item uses) and
`Preferred` per typed password. Prompts: one per password, as before. Cancel
during the verification (the progress window is called every 4 MB) ends the
operation before any file is created.

An ASCII password has one form: one test, no verification pass, the old
path. A wrong password that passes the check byte alone ends in the checksum
error as before.

**Remembered only after verified.** The typed text (all its forms) is kept
for the operation from the moment one form passed the check - as the old
code kept the password - so that Skip at the overwrite question does not
cause a second prompt. Which *form* is tried first for the next item is
recorded only at the "checksum is right" branch (for AES that is after the
authentication code).

**Evidence**

| Gate | Result |
|---|---|
| Debug build (`build.cmd`) | exit 0, no error, no warning in the changed projects |
| saltests | 12,973 -> **13,032**, 0 failed |
| `python tools\check_encoding.py --strict` | TOTAL: 0 |
| `git diff --stat` | source: 15 files changed and one new (`salzippwd.h`); no whole-file diff (line ends and BOM kept) |
| `probe/zipfix.py` self-test | forms of `heslo-` U+0159 as in research; a fixture with two forms passing the check byte by chance is found in 60,084 tries; 7-Zip lists the three-item fixture |

**GUI probe** `probe/zip_gui_probe.ps1` (hidden desktop; fixtures by
`probe/zipfix.py`, each item keyed with an exact byte form; every row carries
the specified result). Results `zip_gui_result.txt` (this build, after the
review fixes below) and `zip_gui_result_pre094.txt` (`Debug_x64_pre094`); the
measurement of T001 is kept as `zip_gui_result_measurement.txt`.

| Build | as specified | different |
|---|---|---|
| 094 | **56** | 1 (X1, not drivable - see below) |
| before 094 | 33 | 24 |

| Rows | What | 094 | before 094 |
|---|---|---|---|
| U1-U12 | one item keyed with `acp` (ASCII, `heslo-` U+0159), `oem`, `utf8` (both texts), `oldread` (`??????`), ZipCrypto and AES-256; the typed text | all unpack, content equal, one prompt | fails on `utf8` (U4, U5, U10, U11) and on AES `oem` (U9) |
| U13, U14 | deflated: ZipCrypto `utf8`, AES `oem` | unpack | fail |
| W1-W5 | wrong passwords (ASCII, Cyrillic against a `utf8` key, accented) | "incorrect password", prompt again, nothing unpacked | the same |
| W6 | an archive an EARLIER version keyed with `??????`; another six-letter Cyrillic word | unpacks - the old archive's weakness, not repairable | the same |
| W7 | a wrong ASCII text that passes the check byte (one form) | checksum error, nothing left - the old behaviour | the same |
| F1-F4 | the right form is `oem` / `utf8` / `oldread` while one or two EARLIER forms pass the check byte by chance (stored and deflated) | unpack, one prompt, no message | F1-F3: "Error in compressed data" / checksum error, nothing unpacked |
| K1 | a wrong accented text, two of whose forms pass the check byte; the target folder holds the user's own `plain.txt` | the file is untouched, no overwrite question, "incorrect password", prompt again | overwrite question, "Error in compressed data", **the user's file is deleted** |
| M1-M3 | several items keyed with different forms of ONE text (M3: with a chance pass of the preferred form) | all unpack, one prompt | 1 of 2 / 1 of 3 |
| M4-M6 | two items under two different passwords (ZipCrypto, AES): two prompts; three ASCII items: one prompt | as specified | the same |
| P1-P6 | new archive, ZipCrypto and AES-256: ASCII, `heslo-` U+0159, Cyrillic | keyed `acp`, `acp`, **`utf8`**; 7-Zip opens the first two; the Cyrillic archive unpacks through the product with the typed word and is **refused for another six-letter word** | Cyrillic: keyed `oldread`, another word unpacks it |
| A1-A4 | a file added to an existing archive (ASCII; code page; an OLD `??????` archive, ZipCrypto and AES) | the new item `acp` / `acp` / `utf8`, the old item unchanged; the whole archive unpacks with one prompt | Cyrillic: the new item `oldread` |
| L1 | 255 characters | keyed with all 255 | keyed with 254 |
| L2 | AES, 129 ASCII characters | "Password too long", no archive | the same |
| L3, L4 | AES, 65 two-byte letters (65 bytes in the code page); 43 Cyrillic letters (86 bytes of UTF-8) | `acp`; `utf8` | `acp`; `oldread` |
| L5 | AES, 65 Cyrillic letters (130 bytes of UTF-8) | "Password too long", no archive (the limit applies to the form used) | an archive keyed with 65 `?` |
| X1 | new self-extracting archive | **not drivable**: the Debug output tree holds no self-extractor packages ("Cannot open or create file") - on both builds | the same |

**After the independent review (ACCEPT, no blocker)** - changes made after
the reviewed state, all in `extract.cpp` / `extract.h`, followed by a
rebuild, saltests 13,032 / 0, strict guard 0 and the whole probe again:

1. *Several forms pass the check byte and the content verifies with none*:
   `ClassicChoose` returns `ZIPPWD_CHOOSE_NONE` and `ExtractSingleFile` treats
   it as a wrong password - the incorrect-password message and the prompt -
   **before** the target file is created or the overwrite question asked
   (row K1). Only when the verification really ran for every passing form;
   the fallbacks (other methods, multi-volume, read error) and Cancel are as
   before. A password typed for the item is put into the operation's list
   only once a form of it is going to be used. Passing forms that come only
   from passwords typed earlier lead to the prompt without a message.
   **With ONE passing form nothing is known in advance and the old behaviour
   remains: overwrite question, unpacking, checksum error, the file deleted**
   (row W7) - as before this feature. A side effect to know: a *damaged* item
   for which two forms of the right password pass the check byte is reported
   as "incorrect password" instead of a checksum error.
2. `Preferred` is not set from an item of size 0 (it "verifies" with any key).
3. The comment of `ClassicVerify` says that a read failure shows the ordinary
   I/O error dialog.
4. The contract (`contracts/zip-password-forms.md` Z2-Z4, S1) is rewritten to
   what the code does.

**Not done / not covered**

- Not driven through the product: a self-extracting archive (X1); Test
  archive and viewing a file (F3) - the same `ExtractSingleFile`; Cancel
  during the verification; the fallbacks of the verification (imploded,
  shrunk, reduced, bzip2 items, multi-volume archives, a read error); an
  overwrite answered with Skip; real keyboard input.
- Adding encrypted items to an EXISTING self-extracting archive runs as a
  normal archive and keys with `acp` / `utf8`, while the stub reads the old
  way: it differs only for a password that is not representable or has 255
  characters. Whether that operation is reachable was not confirmed.
- System code pages other than 1250 / 852 (double-byte, UTF-8) were not
  tested; the helper has unit tests for the UTF-8 case only.
- A form of the old code that is no longer tried: OEM bytes of the old read
  (old classic path: `CharToOem` of a text with `?` or a best-fit letter).
  It matters only for a DOS-keyed archive whose password is typed with a
  wrong or approximated character.
- `Keys[3]` (the cipher state) and the AES context are not wiped.
- The verification pass handles stored, deflate and deflate64 on a
  single-volume archive. Imploded, shrunk, reduced and bzip2 items, and
  multi-volume archives, keep the first passing form.
- Whether `ProgressAddSize(0, TRUE)` really keeps the progress window
  responsive during the verification pass was not observed.
- *Create SFX* from an existing archive: the archive's key is not touched;
  the stub opens only code-page keys.
- Release build: not built in this stage.

## S2 - SFTP

**Chosen: a field limit and larger buffers together**, because neither alone
is safe. A limit that makes the old 512-byte buffers always sufficient would
be 127 characters and would refuse a 200-character ASCII passphrase that
works today; larger buffers alone cannot be sized for an unlimited field.

| What | Where |
|---|---|
| `SFTP_SECRET_MAX_CHARS` 511, `SFTP_SECRET_BUF` 2048 (4 bytes per unit + terminator) | `sftp.h` |
| secret read without the code-page fallback; the wide copy is wiped | `dialogs.cpp` `GetDlgItemSecretU8` (new, static) |
| the three reads use it; the fields are limited (`EM_LIMITTEXT`) | `dialogs.cpp` `PasswordPromptProc`, `ConnectReadFields` (password, passphrase), `ConnectProc` `WM_INITDIALOG` |
| every buffer of the chain: the dialog locals, `ConnectPlainPassword` / `ConnectPlainPassphrase`, `CSFTPConnectParams::Password` / `Passphrase` | `dialogs.cpp`, `dialogs.h`, `session.h` |

Before: the fields had no limit; an ASCII secret worked up to 511 characters,
a non-ASCII one up to 511 bytes of UTF-8, anything longer was sent as
code-page bytes cut to 511. After: the fields accept 511 characters and every
text they accept reaches libssh2 as its UTF-8 form (at most 1533 bytes).
Nothing that worked is refused. A text put into the field past the limit by a
program (not by typing or pasting) gives an empty secret, never other bytes.
The password manager stores a byte string of any length (`pwdmngr.cpp`
`EncryptPassword`); a secret longer than 511 bytes stored by this version is
refused by an older version's `DecryptInto`, which prompts instead.
`GetDlgItemTextU8` and its fallback are unchanged for the name fields.

**GUI probe** `probe/sftp_gui_probe.ps1` with the logging server
(`sshlog_server.py`, paramiko 5.0.0 in a scratch environment): Change
Directory to `sftp:probe@127.0.0.1:2223/`, the text set into the prompt, the
bytes the server received. Results `sftp_gui_result.txt`,
`sftp_gui_result_pre094.txt`; the measurement of T001 is kept as
`sftp_gui_result_measurement.txt`.

| Row | Text | UTF-8 bytes | 094: received | before 094: received |
|---|---|---|---|---|
| S1 | `heslo123` | 8 | equal | equal |
| S2 | `heslo-` U+0159 | 8 | equal | equal |
| S3 | six Cyrillic letters | 12 | equal | equal |
| S4 | 255 x U+0159 | 510 | equal | equal |
| S5 | 256 x U+0159 | 512 | **equal (512 bytes)** | 256 x `F8` (code page) |
| S6 | 256 x U+0416 | 512 | **equal** | 256 x `?` |
| S7 | 511 x U+0159 (the field's limit) | 1022 | **equal** | 511 x `F8` |
| S8 | 511 x U+65E5 | 1533 | **equal** | 511 x `?` |
| S9 | 255 x U+1F4C1 (510 units) | 1020 | **equal** | 510 x `?` |
| S10 | 511 x `a` | 511 | equal | equal |
| S11 | 700 x U+65E5, SET into the field past its limit | 2100 | an **empty** password | 511 x `?` |

S11 cannot be typed or pasted (the field takes 511 characters); a program
that sets a longer text gets an empty secret, never other bytes. In the
Connect dialog an empty field with a stored secret means "keep the stored
one".

**Not covered**: the Connect dialog's two fields and a key passphrase through
the product (the same read function as the prompt); a stored bookmark with a
secret longer than 511 bytes; the SFTP test harness (`src/plugins/sftp/test`)
was not run.

## Registry and leftovers of the probe runs

Every run exported `HKCU\Software\Tandem Commander` before the first start
and restored it afterwards; each restore verified identical, SHA-256
`1AB614304771DBE00A71EAB448FDF988EA7BCC409DE1D48407F2BB6CE63BF769` before and
after (the value differs from the morning's `F5305AEA...` because the
installed program ran and saved its configuration in between). All test
instances ended with exit code 0; no fixture folder and no test process left.

## S3 - gates

- Debug build and full Release build (`build.cmd full release`): no errors.
- saltests 13,032 checks, 0 failed; `check_encoding.py --strict` TOTAL: 0.
- ZIP probe (hidden desktop): 56 of 57 rows as specified on the new build
  (the 57th needs self-extractor packages, absent from a Debug tree), 33 on
  the build before the feature. SFTP probe: 11 rows, all as specified.
- Independent review: ACCEPT, then ACCEPT of the changes made after it (the
  "none verifies" path). Its note, recorded: a damaged item for which two
  forms of the right password pass the check byte is reported as "incorrect
  password"; the earlier versions never let the user keep data of such an
  item either (the output was deleted on the checksum error), so nothing
  that could be extracted before is lost.
- `PRIVACY.md`: the validity paragraph now lists, for 0.1.8, that a crash
  while the ZIP plug-in uses a password can write it into the crash report.
- The installed program saved its configuration while the feature was being
  made, so the registry key's clean state changed twice during the work; each
  probe run restored the state it had found (last: SHA-256 `1AB61430...`).

Owed to a person: `quickstart.md`.

