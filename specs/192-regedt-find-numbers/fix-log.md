# Fix log: 192 - the Registry Editor's Find compares numbers as its help says

Found by the review of 190 (NEXT-WORK D, "Registry Editor Find", items 4 and 5).

## Measured (before)

Probe `probe/find_numbers_probe.ps1` (the build at 191; DWORD 255 and 10 in the probe key, an
empty REG_DWORD alone in a subkey - that key's value buffer is `malloc(0)`; Keys and Values off,
Data and Include subkeys on), `probe/result_before.txt`, 2 / 3:
- NUM "255" (the control): the DWORD 255 - PASS;
- NUM-0X "0xff": nothing - the help says "hexadecimal number prefixed by 0x", but
  `HexStringToNumber` stops at the `x` and the pattern is searched only as text;
- NUM-17 "1000000000000000a" (17 hex digits): **the DWORD 10** - the overflow test divided by
  10, the 17th digit was taken and the top one fell off;
- EMPTY "4261281277" (0xFDFDFDFD): **the empty DWORD** - compared with the 4 bytes after its
  0-byte buffer, the Debug heap's fence (in a Release build: whatever follows; a value shorter
  than 4 bytes with the bytes of the value read before it).

## Work

- `regedt/utils.cpp` `HexStringToNumber`: refuses a digit that does not fit 64 bits
  (`ret >> 60`).
- `regedt/finddlg2.cpp` `StartSearch`: "0x" / "0X" before a hexadecimal number (after leading
  spaces); a decimal number still comes first ("10" is ten).
- `regedt/finddlg.cpp` `CFindThread::Test`: a DWORD / big-endian DWORD is compared as a number
  only with exactly 4 bytes, a QWORD with exactly 8 (as they are shown; review NIT);
- the Find list's item (`CFoundFilesData`) and the panel listing (`fs2.cpp`) read a DWORD /
  QWORD only from a value that has its bytes (review SHOULD-FIX: both read 4 / 8 bytes whatever
  the size - past a 0-byte or 1-byte buffer; not visible, the display shows only the exact size;
  not driven); "0x" must be followed by a digit ("0x 1f" is not a number, review NIT).

Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

## Measured (after)

`probe/result_after.txt` 5 / 0; with the build after the review: 192 5 / 0, the 190 probe
6 / 0, the 124 probe (English, the panel listing) 9 / 0.

## Review

Refute-first review: sound. The `ret >> 60` test is exact; the value editor's callers cap the
text at 16 characters, so nothing changes for them; `DecStringToNumber`'s test is right; "0x"
cases ("0x", " 0x1f ", "0X1F", "00x1") behave; the length guards see the real value size and the
name tests are not affected. Taken: SHOULD-FIX - `CFoundFilesData` (and, the same pattern, the
panel's `fs2.cpp`) read the number past a short value's buffer; NIT - "0x 1f"; NIT - exact sizes.
