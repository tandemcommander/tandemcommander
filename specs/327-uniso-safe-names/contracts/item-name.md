# Contract - `SalArcCleanItemName` (src/common/salarcname.h, N3, feature 327)

```cpp
inline bool SalArcCleanItemName(char* name, size_t size);
```

One name read from an image or archive (UTF-8 or raw bytes, terminated inside a buffer of `size`
bytes) is made safe in place:

1. every byte < 0x20 and `\`, `/`, `:`, `<`, `>`, `"`, `|`, `?`, `*` becomes `_`;
2. trailing dots and spaces become `_` (`.` -> `_`, `..` -> `__`);
3. a reserved device name (`con`, `prn`, `aux`, `nul`, `conin$`, `conout$`, `com0`-`com9`,
   `lpt0`-`lpt9`, `com`/`lpt` + superscript 1/2/3 - also with an extension, case-insensitive) gets a
   `_` prefix; when the prefix does not fit the buffer, its first character becomes `_` instead;
4. an empty name becomes `_`.

Bytes >= 0x80 are copied unchanged. A safe name is left byte for byte. Idempotent.

Returns false only when `name` is NULL, `size` is 0, the name is not terminated inside the buffer,
or an empty name meets a 1-byte buffer - the name is then unchanged.

`SalSuspCleanRockRidgeName` (salsusp.h, feature 326) is the same rule except at step 3: when the
prefix does not fit it returns false and leaves the name unchanged (its caller then lists the plain
ISO 9660 name).
