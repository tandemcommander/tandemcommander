# Contract - cabinet name decoding (UnCAB, feature 381)

Internal to the UnCAB plug-in; no plug-in interface change.

## `SplIsWtf8` (`src/plugins/shared/splunicode.h`)

`BOOL SplIsWtf8(const char* s)` - TRUE when the NUL-terminated `s` is valid WTF-8: strict UTF-8, or
UTF-8 whose 3-byte sequences may encode a lone surrogate (U+D800..U+DFFF). FALSE for NULL and every
other malformed input. Agrees with `SplU8ToWAlloc(s) != NULL` and with the core's `SalU8ToW`.

## `CabNameReadAs` (`src/plugins/uncab/cabname.h`)

`CCabNameRead CabNameReadAs(const char* name, int attribs)`:

- `attribs >= 0` and `attribs & CABNAME_A_NAME_IS_UTF` (0x80 = `_A_NAME_IS_UTF`): `CABNAME_UTF8` when
  `SplIsWtf8(name)`, else `CABNAME_REFUSE`;
- `attribs >= 0` without the flag: `CABNAME_CODEPAGE`;
- `attribs < 0` (not reported): `CABNAME_UTF8` when `SplIsWtf8(name)`, else `CABNAME_CODEPAGE`.

## `CabNameToU8` (`src/plugins/uncab/uncab.cpp`)

`CABNAME_UTF8`: the bytes are copied verbatim when they fit (`lstrlen < bufSize`), else FALSE.
`CABNAME_REFUSE`: FALSE. `CABNAME_CODEPAGE`: `CP_ACP` -> UTF-16 -> `SplWToU8`, FALSE when it fails or
does not fit. A name is never cut.
