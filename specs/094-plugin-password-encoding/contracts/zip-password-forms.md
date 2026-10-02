# Contract: ZIP password forms (feature 094)

The typed password is UTF-16 text `T` (as read from the field with a wide
call). ACP = the system code page, OEM = the system OEM code page.

## Z1 - representable

`T` is representable when `WideCharToMultiByte(CP_ACP, WC_NO_BEST_FIT_CHARS,
T, ..., &usedDefault)` succeeds with `usedDefault == FALSE`. (Best-fit
mapping is off: a character the code page only approximates is not
representable.)

## Z2 - forms

| Form | Bytes | Exists when |
|---|---|---|
| `acp` | `T` in ACP, strict (Z1) | representable |
| `oem` | `acp` converted with `CharToOemBuffA` - what earlier versions tried second | representable |
| `utf8` | `T` in UTF-8 (WTF-8 for a lone surrogate) | always |
| `oldread` | what the code up to 0.1.8 read: `GetDlgItemTextA` of the field with a count of 255, i.e. `WideCharToMultiByte(CP_ACP, 0, ...)` (best-fit mapping, `?` for the rest) **cut to 254 bytes** | always; a candidate only when its bytes differ from the earlier ones |

For a representable text of up to 254 bytes `oldread` equals `acp`. It
differs for a text that is not representable and for a representable text of
255 characters.

## Z3 - packing (new archive, add, update)

One form: `acp` if representable, otherwise `utf8`. The AES limit of 128
bytes applies to that form.

**Self-extracting archive** (the operation creates one): `oldread`. The stub
is a separate, unchanged program whose own prompt reads the password that
way, so nothing else would open with the typed text.

## Z4 - unpacking, testing, viewing

Candidates in order: `acp`, `oem`, `utf8`, `oldread` - those that exist, each
distinct byte string once. For an ASCII text of up to 254 characters there
is exactly one candidate. The forms are tested **per item**; the form an
earlier item verified with is tried first.

- **AES**: the first candidate whose 2-byte verifier matches is used; if the
  authentication code then fails, the item fails as before (no further
  candidates: 1 in 65536).
- **Classic encryption - verify first, write once**:
  - no candidate passes the 1-byte check: the old "incorrect password" path;
  - exactly one passes: it is used, the old path (a wrong one ends in the
    checksum error after unpacking, as before);
  - more than one passes: each is verified by decoding the item without
    output (decrypt, unpack, compare the checksum). The first that verifies is
    used. **None verifies -> a wrong password**: the incorrect-password
    message and the prompt, before the target file is created or the
    overwrite question asked.
  - Fallbacks, where the verification cannot run (a method other than stored
    / deflate / deflate64, a multi-volume archive, a read error): the first
    passing candidate is used, the old path. Cancel during the verification
    ends the operation.
- The typed text is kept for the operation once one of its forms passed a
  check (as before). Which form is tried first is remembered only after an
  item with content verified with it (AES: authentication code; classic:
  checksum).

## Z5 - hygiene

No password in call-stack or trace text. Password buffers (wide and byte
forms, dialog buffers, the session cache on release) are wiped with
`SecureZeroMemory` when no longer needed.

## Z6 - not changed

The self-extractor stub and its prompt (so a password outside the code page
stays `?` in a self-extracting archive); the archive format; any user-visible
string.

## S1 - SFTP secrets

The password and passphrase fields are read wide and converted to UTF-8 into
buffers of 4 bytes per accepted UTF-16 unit plus the terminator: the fields
accept 511 units (`SFTP_SECRET_MAX_CHARS`), every buffer of the chain has
2048 bytes (`SFTP_SECRET_BUF`). The secret reads have no code-page fallback;
a text put into a field past its limit by a program gives an empty secret.
