# Contract - the listing field rule (feature 269)

`src/common/salftplisting.h`, header-only, pure (no Windows call):

```text
BOOL SalFtpListingFieldIsU8(const char* s, int len)
```

- `s` NULL or `len <= 0` -> TRUE (the empty field is kept, as before).
- TRUE when every byte of `s[0..len)` belongs to a valid WTF-8 sequence: 00..7F (NUL included);
  C2..DF + 1 continuation; E0..EF + 2 continuations with a code point >= U+0800 (a surrogate
  D800..DFFF allowed); F0..F4 + 3 continuations with a code point U+10000..U+10FFFF. A continuation
  is 80..BF. A sequence cut by the end of the field is invalid.
- For every NUL-free byte string `b`: `SalFtpListingFieldIsU8(b, n)` ==
  (`SplUnicodeDetail::Wtf8ToW(b + "\0", NULL, 0) > 0`) - checked exhaustively in saltests for short
  strings over a byte alphabet covering every class.
- Consumer: `FTPListingFieldToU8` (`src/plugins/ftp/ftputils.cpp`) keeps the bytes when TRUE;
  otherwise the code-page branch of feature 224 runs unchanged.

Not a plug-in interface; no plug-in relies on it.
