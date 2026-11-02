# Contract - `SalFindSeedDecodeW` (src/common/salfindseed.h, feature 398)

Internal core rule (not plug-in ABI).

```text
int SalFindSeedDecodeW(const unsigned char* bytes, int n, bool atEnd, int enc, unsigned int codePage,
                       wchar_t* out, int outCap, int maxUnits, int maxU8Bytes)
```

- `enc`: 0 = code page `codePage`, 1 = UTF-8, 2 = UTF-16 LE, 3 = UTF-16 BE (the viewer's VCE_*).
- Decodes character by character from `bytes[0]`; appends a character only while the units written
  stay `<= maxUnits`, `< outCap` (room for the terminator) and the UTF-8 length of the text stays
  `<= maxU8Bytes`; the first character that does not fit ends the text (whole characters only).
- Ends at a NUL character; at an incomplete character at the end of `bytes` when `atEnd` is false
  (the read limit fell inside the selection). With `atEnd` true (the bytes are the whole
  selection) such a character is U+FFFD for its first byte (an odd UTF-16 byte, a trailing high
  surrogate, a trailing lead byte likewise), as the viewer draws it.
- UTF-8: invalid lead / continuation, overlong, surrogate or > U+10FFFF -> U+FFFD for one byte.
- UTF-16: a pair is one character (2 units, 4 UTF-8 bytes); a lone surrogate -> U+FFFD.
- Code page: a lead byte (`IsDBCSLeadByteEx`) takes the next byte; a lead byte as the last byte ends
  the text; each character via `MultiByteToWideChar(codePage, 0, ...)` (a failure -> U+FFFD).
- Returns the units written; `out[ret] == 0`. `out == NULL` or `outCap <= 0` -> returns -1;
  `bytes == NULL` or `n <= 0` -> empty text, 0.
