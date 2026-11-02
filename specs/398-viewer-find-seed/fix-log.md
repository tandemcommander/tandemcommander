# Fix log - 398-viewer-find-seed

Backlog item `viewer-find-pre-fills-a-non-ascii-selection-as-code-page`.

## Measurement before (main 58dcca07)

- Sites at HEAD: `src/viewer.cpp` `CFindSetDialog::Transfer` - `SendMessage(..., WM_SETTEXT, 0, (LPARAM)buf)`
  (ANSI) with `buf` from `CViewerWindow::GetFindText` (`src/viewer2.cpp`, at most `FIND_TEXT_LEN - 1`
  = 200 bytes of the selection). Reached from the viewer's Find (Ctrl+F / F7, `CM_FINDSET`) whenever a
  block is selected. The only caller of `GetFindText` (the DB Viewer plug-in has its own copy).
- The field is read back as UTF-8 (`HistoryComboBox` -> `SalGetWindowTextU8`), `InitFindDialog` gives
  those bytes to `SearchData.Set`, the search compares them with the viewer's `Buffer`.
- `ContentEncoding` is set only to `VCE_LEGACY` or `VCE_UTF8` at HEAD (UTF-16 is left to the old path).
  Code-page content: `Buffer` holds the bytes after the conversion table (`CodeCharacters` at load).
- `/J` (sal_base.props): `char` unsigned, so the hex pre-fill `%02X` of `(unsigned)buf[i]` is right.
- Probe `probe/seed398_probe.ps1` (written for this run; 397's driver, 098's library), Debug build at
  HEAD, ACP 1250, through `tools\run_on_hidden_desktop.ps1`: `probe/result_before.txt` -
  PASS 8 / FAIL 4:
  - u8-word: UTF-8 `café` pre-filled `cafĂ©` (U+0102 U+00A9), OK: "Cannot find the string".
  - u8-long: 199 `a` + `é…` pre-filled 200 units / 201 bytes ending `Ă`, OK: "The path specified is too long."
  - u8-cjk: 70 CJK letters pre-filled 200 units of mojibake (418 bytes), OK: "too long".
  - u8-astral: 198 `a` + U+1F600 + `b` pre-filled 200 units / 202 bytes, OK: "too long".
  - legacy (code-page 1250 `café`): field `café` (right) - but OK: "Cannot find the string 'café'"
    (the search's UTF-8 bytes against the file's code-page byte E9; a search-engine limit, not this item).
  - hex control: `63 61 66 C3 A9` (right).
  Registry restored, identical hash.

## Decisions

- The rule in `src/common/salfindseed.h` (`SalFindSeedDecodeW`), checks in saltests.
- Limits: 200 UTF-16 units (the combo's `CB_LIMITTEXT`) and 200 UTF-8 bytes (311's
  `DlgItemTextFitsU8(..., FIND_TEXT_LEN)`): the seed fits both, so OK never refuses it.
- Read `2 * (FIND_TEXT_LEN - 1) + 2` bytes (UTF-16 needs 400 for 200 units); hex keeps the first 66 bytes.
- Code-page content decoded with `CP_ACP` passed as the code page (what the old ANSI `WM_SETTEXT` did) -
  file content in the code page the viewer draws, not a name.
- Deviation (stop-rules §2.14): "a selected non-ASCII word is found" holds for UTF-8 content; for
  code-page content the search engine compares UTF-8 bytes with code-page bytes - Inbox item.

## Implementation

- `src/common/salfindseed.h` (new): `SalFindSeedDecodeW(bytes, n, atEnd, enc, codePage, out, outCap,
  maxUnits, maxU8Bytes)` - character by character, whole characters only, limits in UTF-16 units and
  UTF-8 bytes; NUL ends; invalid UTF-8 byte / lone surrogate -> U+FFFD.
- `src/viewer.h` / `src/viewer2.cpp`: `GetFindText(buf, bufSize, len)` (was a fixed `FIND_TEXT_LEN - 1`),
  `GetContentEncoding()`.
- `src/viewer.cpp` `CFindSetDialog::Transfer`: reads 402 bytes; hex as before (first 66 bytes, ASCII
  digits); otherwise the seed through `SetWindowTextW` on the combo box, `atEnd` = the whole selection
  was read.
- `src/saltests/saltests.cpp`: `TestFindSeed398` (60 checks incl. a brute force over every 1- and 2-byte
  UTF-8 input and the longest-prefix property for every byte limit).

### Attempt 1 of the probe (after) - one row failed

`result_after.txt` run 1: PASS 11 / FAIL 1 - row `legacy` pre-filled `caf` (the E9 dropped). Cause: the
fixture `caf` + E9 ends with a lone UTF-8 lead byte, and `ViewerDetectEncoding` accepts a sequence cut by
the end of its sample - the viewer shows that file as UTF-8 (E9 drawn as U+FFFD), not in the code page.
The rule dropped "an incomplete character at the end" even when the selection itself ends there.
Fix (a different rule, not a repeat): `atEnd` - an incomplete character at the read limit is left out,
one at the end of the selection is U+FFFD as the viewer draws it (also for an odd UTF-16 byte, a
trailing high surrogate, a trailing DBCS lead byte). The probe got a true code-page row (`legacy`:
`café au lait`, E9 followed by a space) and the cut-file row `u8-tail` (expects `caf` + U+FFFD).

## Measurements after

- `.\build.cmd` -> BUILD SUCCEEDED.
- saltests: 282,226 checks, 0 failed. Negative control (the UTF-8 branch disabled, bytes decoded as the
  code page - the old ANSI behaviour): 28 failed; restored, 0 failed.
- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- Probe `seed398_probe.ps1` after (`probe/result_after.txt`): PASS 14 / FAIL 0 (7 rows RUN + END):
  u8-word `café` found; u8-long 199 `a`; u8-cjk 66 letters / 198 bytes; u8-astral 198 `a` - all OK with
  nothing asked and found; legacy `café au lait` (search "Cannot find": known limit, Inbox);
  u8-tail `caf` + U+FFFD; hex `63 61 66 C3 A9`. Registry restored, identical hash.
  Before (main 58dcca07, `probe/result_before.txt`, the first 6 rows; its `legacy` row is the cut file
  that is now `u8-tail` - field `café` by the ANSI decoding, an accident of the code page): PASS 8 / FAIL 4.
- Regressions: 397's probe 8 / 0 (`probe/regress_397.txt`), 311's probe 26 / 0 (`probe/regress_311.txt`).

## Deviation (stop-rules §2.14)

*Expected* "a selected non-ASCII word is found by the search it pre-fills": reached for UTF-8 content
(rows u8-*). For content shown in a code page the search engine compares the field's UTF-8 bytes with
the file's code-page bytes (row `legacy`: "Cannot find" before and after) - a search change outside this
item: Inbox `viewer-find-does-not-find-non-ascii-text-in-a-file-shown-in` (leftover:398). UTF-16 content
is decoded by the rule (saltests) but not reachable: the viewer does not detect UTF-16 into a wide mode.

## Translations

No UI string, menu or dialog changed - no `.slt` refresh.
