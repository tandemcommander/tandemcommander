# Research - 269-ftp-wtf8-listing

## R1. Where a listing name is decoded

- Decision: fix only `FTPListingFieldToU8` (`src/plugins/ftp/ftputils.cpp`).
- Rationale: it is the one intake of server text - `AssignStringToColumn` (`parser2.cpp`) for every
  column of every listing (the panel's listing and the cached listings the operations use:
  `CUploadPathListing` is filled through the same parser), and `FTPDecodeServerReplyPathInPlace`
  for the PWD path. Grep of `MB_ERR_INVALID_CHARS` / `CP_ACP` in `src/plugins/ftp`: no other decode
  of names. `FTPU8NameToServer` already sends the WTF-8 bytes verbatim (a WTF-8 name is ASCII-free
  and not in the code-page set) - measured: UP-NEW stored `a<U+D800>.txt` byte for byte.
- Alternatives: decode in each consumer - rejected, the decode is at intake by design (feature 052).

## R2. The validity rule

- Decision: a length-bounded WTF-8 check equal to `SplUnicodeDetail::Wtf8ToW`'s accepted set
  (lead C2..DF / E0..EF / F0..F4, continuation 80..BF, no overlong 3-byte (< U+0800), 4-byte in
  U+10000..U+10FFFF; a 3-byte sequence may encode any surrogate); a NUL byte is a valid 1-byte
  character (the strict call with an explicit length accepted it).
- Rationale: the item's approach ("probe with `SplU8ToW`"); `SplU8ToW` = strict UTF-8 (a subset of
  this set) or `Wtf8ToW`. A listing field is not NUL-terminated, so `SplU8ToW` itself cannot be called
  on it without a copy, and it would stop at an embedded NUL.
- Alternatives: copy + `SplU8ToW` - rejected (an extra allocation per field, different NUL
  behaviour); `SalCslIsWtf8` (`salcsumlist.h`) - the same set but a checksum-list header; reusing it
  from the FTP plug-in would tie two unrelated features.

## R3. Ambiguity with code-page names

- Decision: accepted, recorded as a limit. In cp1250 a WTF-8 surrogate needs `í` (ED) followed by
  A0..BF and 80..BF (e.g. `í` + no-break space + `€`); other code pages likewise need the lead
  byte ED. Feature 224 already takes every name that is valid UTF-8 for UTF-8 (e.g. `Ă©`-like pairs).
- Rationale: the item chooses WTF-8 (spec Clarifications).

## R4. Test server

- Decision: 215's `ftpmini.py` gets ENC `wtf-8` = UTF-8 with Python's `surrogatepass` both ways
  (FEAT announces UTF8). Python on Windows lists and opens names with a lone surrogate (measured:
  `os.listdir` returns `'a\ud800.txt'`, `.encode('utf-8', 'surrogatepass')` = `61 ED A0 80 ...`).
- Rationale: Docker is not running on the machine; a byte-transparent UNIX server (vsftpd) does the
  same with the bytes. The other modes are unchanged (`WIRE, ERRS = ENC, 'surrogateescape'`).
