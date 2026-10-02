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
| `lossy` | what the old code produced: `GetDlgItemTextA` of the field, i.e. `WideCharToMultiByte(CP_ACP, 0, ...)` with the default character and best-fit mapping | not representable |

For a representable text the old read equals `acp`, so `lossy` is not a
separate form there.

## Z3 - packing (new archive, add, update)

One form: `acp` if representable, otherwise `utf8`. The AES limit of 128
bytes applies to that form.

## Z4 - unpacking, testing, viewing

Candidates in order: `acp`, `oem`, `utf8`, `lossy` - those that exist, each
distinct byte string once. For an ASCII text there is exactly one candidate.

- **AES**: a candidate is accepted when the 2-byte verifier matches; if the
  authentication code then fails, the item fails as before (no further
  candidates: 1 in 65536).
- **Classic encryption**: a candidate is accepted when the 1-byte check
  matches. If the item's checksum then fails and candidates remain, the item
  is restarted with the next candidate that passes the check; only when none
  is left is the error reported, as before.
- A byte string is remembered for the rest of the operation / session only
  after an item verified with it (AES: authentication code; classic:
  checksum).
- When no candidate passes the check the behaviour is the old "incorrect
  password" path, unchanged.

## Z5 - hygiene

No password in call-stack or trace text. Password buffers (wide and byte
forms, dialog buffers, the session cache on release) are wiped with
`SecureZeroMemory` when no longer needed.

## Z6 - not changed

The self-extractor stub and its prompt; the archive format; any user-visible
string.

## S1 - SFTP secrets

The password and passphrase fields are read wide and converted to UTF-8 into
a buffer of at least 4 bytes per accepted UTF-16 unit plus the terminator
(or the field's limit is set so that the existing buffer always suffices);
the code-page fallback is unreachable for them.
