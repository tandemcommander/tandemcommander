# Fix log: 191 - the Registry Editor's Find refuses input that does not fit

Found by the review of 190 (NEXT-WORK D, "Registry Editor Find", items 1-3).

## Measured (before)

Probe `probe/find_input_probe.ps1` (the build at 190; Keys and Values off, Data on; each row
sets the fields, presses Find and records the windows):
- HEX-OK (the control, hex `"beta"`): finds the list - PASS;
- TIME-BAD (the control, Min time `x`): the "Invalid date/time format" box - PASS;
- TIME-LONG (Min time of 40 digits): **"Run-Time Check Failure #2 - Stack around the variable
  'buffer' was corrupted"** - `char buffer[20]` read with `ti.EditLine(..., MAX_KEYNAME)` in
  `CFindDialog::Validate` and `::Transfer` (`probe/result_before.txt`);
- HEX-LONG (hex: a quote and 300 letters, run alone with `-Only HEX-LONG`): **fatal
  "_sal_safe_memcpy: source and destination of memcpy overlap"** - `ConvertHexToString` wrote
  2 bytes per quoted letter into `patternA[512]`, ran into `patternW` next to it, and the copy
  `memcpy(patternW, patternA, 600)` overlapped (`probe/result_before_hexlong.txt`).

Item 3 (a plain pattern whose code-page form does not fit 512 bytes: `WStrToStr` fails, length
-1 reaches a `memcpy`, 0 in regexp mode = everything) needs a UTF-8 or DBCS system code page;
this machine has 1250, where the 511 letters the field holds always fit - not driven.

## Work

`src/plugins/regedt/finddlg2.cpp`, `utils.cpp`, `utils.h`:
- the time fields' buffer is `char[MAX_KEYNAME]` - the size given to `EditLine`; a long value is
  refused as a bad format; `ValidateTimeString`'s trim of trailing spaces stops at the start (a
  field of spaces read the bytes in front of the buffer - from reading, not driven);
- `ValidateHexString` reports the number of bytes the pattern makes (now counting the hex
  bytes too); `Validate` refuses more than `MAX_KEYNAME` with `IDS_LONGDATA` ("Unable to finish
  operation because of too long data."); `ConvertHexToString` takes the buffer size and gives
  length -1 instead of writing past it, which `StartSearch` refuses as well;
- `Validate` refuses a plain / regexp pattern whose code-page form needs more than `MAX_KEYNAME`
  bytes (the field focused); `StartSearch` refuses it too, as a backstop (review SHOULD-FIX);
- the time fields get `EM_LIMITTEXT` 100 (review NIT).
No new string.

Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

## Measured (after)

`probe/result_after.txt` 5 / 0: TIME-LONG - the bad-format box; HEX-LONG - the "too long data"
box; the controls as before; END clean. With the build after the review: 191 5 / 0, the 190
probe 6 / 0, the 189 probe 8 / 0.

## Review

Refute-first review: no critical finding; the three overruns closed, the boundaries exact (512
bytes pass both the check and the conversion, 513 neither; a 2-byte letter at 510 fits, at 511
not), `ValidateHexString`'s count equals `ConvertHexToString`'s length for every accepted
pattern, nothing downstream needs a terminator in hex mode (`CSearchData::Set` adds its own; hex
and regexp exclude each other), the early return leaves the dialog consistent. Taken: SHOULD-FIX
- the plain / regexp refusal was only in `StartSearch` (after the list was cleared, no field
focused, and `Error()` appends the text of `GetLastError()` - stale): now in `Validate`, the
backstop clears the last error; NIT 1 - a 0 from the size query fails closed; NIT 2 - a time
field over 511 bytes got the system "file name too long" box: `EM_LIMITTEXT` 100; NIT 4 - the
comment. Recorded (NIT 3, older): a letter that needs 2 bytes in the code page inside `'...'` of
a hex pattern becomes a 0x00 byte (`utils.cpp` `ConvertHexToString`) - with a UTF-8 code page
every non-ASCII letter.
