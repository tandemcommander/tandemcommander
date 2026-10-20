# Closing report - 262-codeview-code-tables
Backlog item: codeview-code-tables-for-single-byte-files - Code Viewer reads single-byte files only in the system code page (no CP852 etc.)
Outcome: closed

## What changed

- `src/common/salcodetable.h` (new, header-only): the table pass (in place), the status-bar name,
  cycling, list position <-> encoding / table, which table a single-byte file gets, byte-exact
  name lookup.
- Code Viewer (`src/plugins/codeview/`): View > Encoding lists, after the five entries, every table
  `EnumConversionTables` hands out (the built-in viewer's Convert list, order and grouping); a choice
  re-reads the open file through the table and the system code page; the status bar names the table;
  F8 / Shift+F8 cycle the whole list; a table chosen from the menu is remembered (`DefaultConvert`,
  REG_SZ, UTF-8, in the plug-in's key) and applied to later single-byte files; *System code page*
  forgets it; cycling never changes it (review 1, S1). No remembered table = the old reading.
- No plug-in interface change, no UI string, no core change.

## Measurements (before / after, commands)

- Before (bf05ffc9): `intake.cpp` decoded single-byte files with `CP_ACP` only; the menu had five
  entries. The corpus `cp852.bat` read as CP1250: "Pý˘lię §luśouźkě k…ĺ Łpŕl Ô belsk‚ ˘dy" (correct:
  "Příliš žluťoučký kůň úpěl ďábelské ódy"); `iso8859-2.ini`: "Přílią ľlu»oučký".
- Probe `probe/cvtab262_probe.ps1` (hidden desktop, ACP 1250):
  - before: codeview sources of HEAD, rebuilt. MENU FAIL ("Encoding menu 5 items"), SAVED FAIL,
    RESTART FAIL, NONASCII NOT DRIVEN. See `result_before.txt`.
  - after: 16 PASS, 0 FAIL, 0 NOT DRIVEN. See `result_after.txt`.
- `TestCodeTable262`: with the shipped tables, the CP852 and ISO-8859-2 corpus lines give exactly
  "Příliš žluťoučký kůň úpěl ďábelské ódy".

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd`: `BUILD SUCCEEDED` (Debug x64).
- saltests: `saltests: 24659 checks, 0 failed`. Negative control: the wrong table gives 1 failed.
- `src\plugins\codeview\test\run_tests.cmd`: all codeview checks passed.
- Probe `cvtab262_probe.ps1`: 16 / 0 / 0. The registry was restored and is identical (SHA-256).

## Reviews (findings and what was done)

Review 1 (refute-first) found no MUST.
- **S1 (fixed):** F8 cycling stored the remembered table. One Shift+F8 on a UTF-8 file stored
  *ANSI - OEM* for every later file. Now only a choice from the menu is remembered; probe row KEEP
  covers it.
- **NOTE 1:** the letters are proven by the unit rule and by reading the code; a person reads them on
  screen.
- **NOTE 2 and NOTE 3** are limits (a UTF-8 convert.cfg, a UTF-8 system code page). They are
  recorded in the leftover item.
- **NOTE 4 and NOTE 6** were accepted.
- **NOTE 5:** the bookkeeping is done at closing.

There was no MUST finding, so no second review was needed.

## Owed to a person (with the new person-step items)

- `on-screen-check-of-the-code-viewer-conversion-tables-feature`: read the decoded letters in the
  page, press F8 / Shift+F8 on the real keyboard, check that the table is remembered across a restart
  (quickstart *By a person*).

## New Inbox items (slug - title)

- `code-viewer-no-auto-select-of-the-code-page-and-no-explicit` - Code Viewer: no Auto-Select of the
  code page and no explicit Set as default.
- `on-screen-check-of-the-code-viewer-conversion-tables-feature` - On-screen check of the Code Viewer
  conversion tables (feature 262).
