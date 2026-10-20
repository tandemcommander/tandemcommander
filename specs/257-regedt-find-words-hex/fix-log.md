# Fix log - 257 Registry Editor Find: whole-word regexp, empty regexp, letters in quoted hex

From backlog item `regedit-find-whole-words-and-quoted-hex-letters` (review of 190, items 6 and 7).

## Before (main at 2437c4dd, Debug x64 build up to date)

Code reading:

- `CFindThread::Test` (finddlg.cpp), regexp branch: `pos` from `SearchForward` is relative to the
  line `start..end`, the whole-word test read `text[pos - 1]` / `text[pos + matchLen]` (the value).
- `CFindDialog::StartSearch` (finddlg2.cpp): a regexp's `patternALen` counts its NUL - an empty
  regexp has 1, `Test`'s "empty = everything" exit is not taken, `regcomp("")` matches the empty
  string, Whole words refuses `matchLen == 0`.
- `ConvertHexToString` (utils.cpp): `WStrToStr(hex + len, 1, s++, 1)` per quoted unit - a letter of
  2+ bytes in the code page fails and `WStrToStr` stores 0x00; `ValidateHexString` counts 1 per unit.
- Only callers: `ConvertHexToString` <- `StartSearch`; `ValidateHexString` <- `Validate`.

Probe (hidden desktop, ACP 1250):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\257-regedt-find-words-hex\probe\find_words_hex_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect before -OutFile specs\257-regedt-find-words-hex\probe\result_before.txt"
```

`probe/result_before.txt`: **7 PASS / 2 FAIL** - WW-LINE2 found [ww1, ww3] instead of [ww1, ww2]
(both directions wrong); EMPTY-RX-WW found nothing instead of all 5; controls RX-BAR, EMPTY-TXT,
EMPTY-TXT-WW, EMPTY-RX, HEX-CP, HEX-CP-BYTES pass. The quoted C-caron is 1 byte (E8) in 1250, so
the HEX rows are controls here; the 2-byte case is proven by saltests with code page 65001 / 932.
Registry restored identical.

## Decisions

- `'...'` = the program's code page (item, clarification 1); a letter the code page lacks: its
  replacement, unchanged (clarification 2); a failed conversion: refused as a bad hex string.
- Whole-word boundary stays `isspace`; the help says "punctuation" too - Inbox item (clarification 4).

## Analyze

- Run 1: CRITICAL D1 (no CHANGELOG task, constitution MUST) and MEDIUM D2 (no formatting task) -
  fixed with T014 / T015. LOW C1: the CR LF edge case has no own check - the line splitter is
  unchanged; accepted.
- Run 2: 0 CRITICAL, 0 HIGH.
