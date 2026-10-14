# Fix log: 189 - the end of a Registry Editor text value

Backlog: NEXT-WORK section D, "Registry Editor: a malformed `REG_MULTI_SZ` with one terminator
shows a trailing space (124)".

## Measured (before)

The panel's loop (`regedt/fs2.cpp`) took only an exact two-NUL end as the end of a list: one NUL
(or three) became a trailing space. Looking at it found a worse defect in the same code of the
Find window (`regedt/finddlg.cpp`, `CFoundFilesData`): it copied the text without a terminator
whenever the data had none at the end of what it kept (its loop dropped the single NUL of a
one-NUL list; a `REG_SZ` with an odd byte count; a list with no NUL), and the list view then read
the copy as a NUL-terminated string - past the heap block.

Probe `probe/multisz_probe.ps1` (the build at 188): values written with `RegSetValueExW` (raw
bytes), Find "probe189", every cell read exactly (`probe/result_before.txt`, 3 PASS / 4 FAIL):
- one NUL: `alpha beta` + U+FDFD U+FDFD (the debug heap's fence) + garbage;
- "no NUL" (`delta\0epsilon`, 26 bytes): Windows hands it back with a NUL added (28 bytes), so it
  is a second one-NUL case - `delta epsilon` + the same (a list with no NUL at all reaches the
  plug-in only in theory; saltests covers it);
- three NULs: `zeta` + two spaces;
- `REG_SZ` "eta" + one byte: `eta` + U+FD00 U+FDFD ...;
- passed: the proper two-NUL list; a `REG_SZ` without NUL (Windows hands it back with one).

The panel's own preview is bounded (it converts a counted length), so there it was only the
trailing space. Negative control of the rule: `probe/old_loop_control.py` replays the saltests
cases through the old panel loop - wrong in 3 of 8 (one NUL, three NULs, a single NUL).

## Work

- `src/common/salmultisz.h` (new, header-only): `SalMultiSzToLine` - the NULs at the end of the
  data are the end, the ones inside become spaces; returns the units with one terminator when
  the data had one. saltests `TestMultiSzToLine189` (17 checks).
- `regedt/fs2.cpp`: the panel uses it.
- `regedt/finddlg.cpp`: the Find window uses it, and its copy of a text value is always
  terminated (`units + 1`), "..." when cut as before (after a whole character). Its regular-
  expression search trimmed a fixed 4 bytes (lists) / 2 bytes (texts) as the terminator: now the
  NULs at the end, however many (review SHOULD-FIX).

Build: BUILD SUCCEEDED; saltests 22,361 / 0; `check_encoding.py` TOTAL 0.

## Measured (after)

All six exact (`probe/result_after.txt`, 7 / 0); exit clean, no report, registry identical.
The panel's trailing space is not visible to OCR - covered by saltests (the same rule), not
driven on screen.

## Review

Refute-first review: sound (bounds of both buffers, the fall-through and `cut` in the panel, the
Size columns keep the raw size, ownership). Taken: SHOULD-FIX 1 - the regexp branch of
`CFindThread::Test` cut a one-NUL list to `alpha\0bet` (a search for "beta" missed it); SHOULD-FIX
2 - the test's `memcpy` read one unit past the literals (now `units` and a sentinel); NIT - the
"..." cut kept a whole surrogate pair; NIT - the redundant `units >= 4`; NIT - the "no NUL" row
was a one-NUL row (above).

The probe got a row RX for the regexp search (Keys, Values off; Data, Regular expression on;
"beta"). Measured on the build with the first part only (`probe/result_before_rx.txt`) and after
(`probe/result_after.txt`): both **found nothing and the search hit a Debug run-time check**
"The variable 'number' is being used without being initialized" (`finddlg2.cpp`: `number` /
`useNumber` are never set in regexp and hex mode, yet go to the search thread). A separate defect
- feature 190; the RX row is measured there. All other rows 6 / 0.
