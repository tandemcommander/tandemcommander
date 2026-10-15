# Fix log: 190 - the Registry Editor's regexp and hex searches run

Found by feature 189 (its probe row RX): a regular-expression search of the Registry Editor's
Find window found nothing and a Debug build stopped it with "Run-Time Check Failure #3 - The
variable 'useNumber' is being used without being initialized" (then 'number').

## Measured (before)

`finddlg2.cpp` (starting a search): `useNumber` and `number` are set only in the plain-text
branch (`DecStringToNumber` / `HexStringToNumber`), yet passed to the search thread in every mode.
Probe `probe/find_number_probe.ps1` (the build at 189; values written with `RegSetValueExW`;
Keys and Values off, Data on; the found names read exactly), `probe/result_before.txt`, 3 / 3:
- NUM "255", NUM-MID "32768", NUM-TOP "2147483648" (plain searches, run first): PASS;
- RX (regexp "beta"), HEX (`62 00 65 00 74 00 61 00`): nothing found, the run-time check box;
- END: the program did not exit (the boxes), ended by the probe.

In a Release build the two are whatever the stack held: a regexp search is not affected (it
does not compare numbers), a hex search compared DWORD / QWORD values with a garbage number.

**Refuted on the way:** the big-endian comparison `text[3] | (text[2] << 8) ...` on a `char*`
looked like a sign extension of bytes from 0x80 on; NUM (00 00 00 FF) and NUM-MID (00 00 80 00)
were found before - the plug-ins build with `/J` (`plugin_base.props`: `char` is unsigned). The
change made for it (and unmeasured length guards next to it) was reverted; the rows stay as the
control.

## Work

`src/plugins/regedt/finddlg2.cpp`: `useNumber = FALSE`, `number = 0` - in regexp and hex mode
numbers are not searched for as numbers.

Build: BUILD SUCCEEDED; saltests 22,361 / 0; `check_encoding.py` TOTAL 0.

## Measured (after)

`probe/result_after.txt` 6 / 0 (RX and HEX find both lists, END clean). The 189 probe with this
build: 8 / 0, RX included (`../189-regedt-multisz-end/probe/result_after_with_190.txt`).
Negative control of 189's regexp trim (the old fixed 4-byte trim put back, built, run):
RX found only the proper list, not the one-NUL one (`probe/result_negative_control_189_trim.txt`,
5 / 1) - the trim of 189 is what finds it.

## Review

Refute-first review: sound. FALSE is right in hex mode: `CFindThread::Test` compares DWORD /
QWORD / big-endian values only as numbers (hex patterns are byte patterns, searched in texts and
binary values), so before the fix a Release build matched a number value only when the stack's
garbage equalled it - nothing that ever worked changes; a regexp search never read the number
(Debug box only). No other uninitialized value on the path; `patternALen` counting the NUL in
regexp mode is needed (it is the terminator of the member copy). Recorded (NIT): no probe row
shows that a hex search does not find a DWORD by its bytes - by design, as above.

Older defects the review found on the way, recorded in `specs/NEXT-WORK.md` (D, Registry Editor
Find) and fixed one by one: the time fields read up to 512 bytes into `char[20]`; a quoted hex
pattern overruns `patternA[512]`; a plain pattern that does not fit 512 bytes in the code page
gives length -1 to a `memcpy`; the "0x" number prefix the help promises is rejected, and a
17-digit hex number loses its top digit; a DWORD / QWORD value shorter than 4 / 8 bytes is
compared with stale bytes (`malloc(0)` when the key's largest value is empty); regexp with Whole
words tests the wrong characters on the second and later lines of a list; an empty regexp is not
"everything".
