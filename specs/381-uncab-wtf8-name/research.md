# Research - 381 UnCAB WTF-8 names

## R1 - Which validity test

- **Decision**: `SplIsWtf8(s)` = `SplUnicodeDetail::Wtf8ToW(s, NULL, 0) > 0`.
- **Rationale**: it is the decoder every plug-in helper (`SplU8ToW`, `SplU8ToWAlloc`,
  `SplU8ToWExtAlloc`) falls back to since feature 089, and feature 089's saltests (plus its reviewer's
  brute force of 181,789,444 cases) show parity with the core's `SalU8ToW`. It accepts strict UTF-8
  plus 3-byte sequences that decode to a lone surrogate, and rejects everything else (overlong,
  above U+10FFFF, stray continuation, truncated). So the name UnCAB accepts is exactly a name the
  later conversions (`SplU8ToWExtAlloc` for the target file, `EqualNamesU8`) can convert.
- **Alternatives**: keep the strict probe and add a WTF-8 fallback inline (two calls, the scan's
  `strict-probe-rejects-wtf8` rule still fires); call `SplU8ToWAlloc` and free (an allocation per
  name for a yes/no answer).

## R2 - What happens to the accepted name downstream

- `ListFile` hands the UTF-8 name to the core (`CSalamanderDirectoryAbstract`), which is WTF-8 since
  066. `UnpackFile` builds the target path and opens it through `SplU8ToWExtAlloc` (WTF-8). The name
  buffers are `U8_MAX_CAB_NAME` = 3 x 256 + 1 bytes; the copy is refused when it does not fit
  (unchanged). No other strict conversion of the name exists in `uncab.cpp` (grep of
  `MultiByteToWideChar`: the probe and the two code-page reads).

## R3 - The unflagged guess (fdintPARTIAL_FILE)

- **Decision**: also WTF-8 (spec Clarification 1). The bytes `ED A0..BF xx` in a code page
  (cp1250: `í`, NBSP..., then a third high byte) as a real name are far less likely than the
  strict probe's existing acceptance of code-page text that happens to be UTF-8, and the continued
  entry then keeps the name it has where it starts.

## R4 - Fixture

- **Decision**: a Python MS-CAB writer (stored, one folder, CFDATA checksum as libmspack computes it).
  Windows `expand.exe -D` lists the control cabinet and extracts both files byte-exact, so the format
  is right. `makecab` cannot store chosen name bytes with the flag.

## R5 - Silent refusal

- Measured: a refused name returns -1 from the notify callback -> `FDIERROR_USER_ABORT` -> `FDIError`
  shows nothing. Out of scope (spec Clarification 2); recorded as a new backlog item.
