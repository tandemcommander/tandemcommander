# Fix log: 180 - the text of a system error with inserts

Backlog: NEXT-WORK section D, "Found by the second verification of 124-128", item 5.

## Measured (before)

- `probe/formatmessage_check.ps1` (`probe/formatmessage_result.txt`): `FormatMessageW` with the
  flags the program used (`FORMAT_MESSAGE_FROM_SYSTEM` only) fails with 87 for 193, 216 and 34 -
  the texts with inserts ("%1 is not a valid Win32 application."); with an argument array it gives
  the text.
- In the program (`probe/errtext_probe.ps1`, the build at 168): Plugins Manager > Add of
  `fake.spl` (a text file - `LoadLibrary` fails with 193): "Unable to load plugin (...) Error:
  **System error 193, text description is not available.**"; the Debug handles box "(193)" with no
  text (`err`). An Enter on a fake `.exe` in the panel goes to the shell (its own window) - not this
  text.

## Work

`src/common/salfmtinserts.h` (header-only): `SAL_FM_SYSTEM_FLAGS` (FROM_SYSTEM | ARGUMENT_ARRAY)
and arrays of 99 pointers to "..." (A, W; `SalFmInserts` by `UNICODE`) - not
`FORMAT_MESSAGE_IGNORE_INSERTS`, which would leave a '%' in a text that callers put into messages.
Used by the core's `GetErrorText` / `GetErrorTextW` (`salamdr2.cpp`), the plug-in service
`CSalamanderGeneral::GetErrorText` (`zip.cpp`), the FTP client's `FTPGetErrorText`, and the trace
helpers `err` / `errW` (`common/messages.cpp`, `plugins/shared/mhandles.cpp`).

Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

## Measured (after)

`probe/errtext_probe.ps1`: "Error: (193) ... není platná aplikace typu Win32." (`result_after.txt`,
PASS; before `result_before.txt`, FAIL). Registry identical.

## Review

Independent refute-first review: nothing CRITICAL / SHOULD-FIX in the change - x64 argument slots,
%99, `%0` / `%n` / `%%`, the inline functions' static arrays, the cast, the TCHAR choice, buffers,
and that no caller uses the text as a format checked. Taken: the narrow placeholders end in three
zero bytes (a wide string insert format of the A function stops there); a saltests check
(`TestFormatMessageInserts180`: 193 / 216 / 34 and four plain codes format, A and W, no '%'; the
control without arguments fails with 87) - 22,339 checks, 0 failed. Recorded in NEXT-WORK: the
plug-ins that use `FORMAT_MESSAGE_IGNORE_INSERTS` show a literal "%1 ..." (cosmetic); the 7-Zip SFX
stub (`sfx7zip/extract.c`) and the translator tool still lack it.
