# Data model - 338

All in `src/common/salisounpack.h` (header-only).

## Result codes

`SAL_ISO_UNPACK_ERROR 0`, `SAL_ISO_UNPACK_OK 1`, `SAL_ISO_UNPACK_CANCEL 2`, `SAL_ISO_UNPACK_AUDIO_UNSUP 3` -
the values of uniso's `UNPACK_*` (`isoimage.h` asserts the equality).

## Rules

- `SalIsoFileUnpackResult(ret, complete)`: `OK` with `!complete` -> `ERROR`; else `ret`.
- `SalIsoUnpackItemWhole(ret)`: TRUE only for `OK`.
- `SalIsoWholeUnpackSucceeded(const CSalIsoWholeUnpackTally&, listingLeftOut)`: TRUE only when not cancelled,
  nothing not whole, nothing written over its own, the listing complete.

## CSalIsoWholeUnpackTally

| Field | Meaning |
|---|---|
| `Cancelled` | the user cancelled / an error that stops the unpack |
| `NotWhole` | a file asked for was not extracted whole, or a folder was not created |
| `WroteOverOwn` | a file was written over a file this unpack wrote (twins) |

## CSalIsoWrittenFiles (identities of written files)

| Member | Meaning |
|---|---|
| `Note(const CSalFileIdentity&)` | remember a written file; no usable id or no memory -> `Lost` |
| `WrittenBefore(BOOL read, const CSalFileIdentity&)` | is this existing target one we wrote? TRUE when `Lost`, or the identity was not read / has no usable id while something was written, or a key matches |
| keys | `'Q' + Vsn64 + Id128` (usable 128-bit id), `'D' + Vsn32 + Index64` (usable 64-bit index) |
