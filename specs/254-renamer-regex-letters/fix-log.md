# Fix log: 254 - The Renamer's regular expressions work on whole letters of UTF-8 names

From backlog item `renamer-regex-single-byte-classes` (recorded by 210's review). The Renamer's
regular-expression engine (`src/plugins/renamer/regexp.cpp`, Henry Spencer's) steps, classifies and
counts BYTES: `.`, bracket classes, `\w \d \s`, POSIX classes, a quantifier after a multi-byte
literal, `\b`, look-behind and the empty-match skip of `CRenamer::RESubst`.

## Measured (before, 3ea24ab5)

Probe `probe/ren_regex_probe.ps1` (210's driver; Search 108, Replace 109, the check boxes 112 Case
sensitive, 113 Whole words, 114 "Only once in each name" (= NOT Global), 115 Regular expression, 123
Exclude extension set on every row - the Renamer keeps its options between runs). Run:

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log <log> -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\254-renamer-regex-letters\probe\ren_regex_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect before -OutFile <rows>"
```

`probe/result_before.txt` (ACP 1250): RUN rows 16 FAIL / 2 PASS (the ASCII controls asc-wb,
asc-dot); every END row PASS; registry restored identical.
- refused "(123) the name is incorrect": dot, w-cyr, class, negclass, range, posix, mark, nonbmp,
  ci-class, empty;
- **wrong name written**: wordb - `а\b` (Cyrillic а) -> "A" on "Жаба.txt" gave "ЖAба.txt" (byte B0
  of а judged no letter, D0 of б a letter: a "boundary" inside the word);
- missed: quant (`^ž+` on "žžluť" replaced one ž), lookb (`(?<=^.)l`), esc (`\xC5\xBD`
  case-insensitive), sigma and bm-sigma ("Σ" case-insensitive vs "ς").
(The first run set box 114 as if it were Global - every row ran global; re-run with the inverted
box, the record above is the second run.)

Not present at HEAD: the preview's sort (`preview.cpp` `CompareFunc`) calls `SG->RegSetStrICmp` =
the core's `RegSetStrICmp` (`sort.cpp`), which compares a non-ASCII name by `SalCompareNamesUTF8`
(feature 004) - not the code page. Not changed.

By reading: `dialogs.cpp` `HistoryComboBox` dedupes with `SG->StrICmp` (the code page's byte
table; cp1250 and cp1252 fold 8A / 9A, so "Ċ" (C4 8A) and "Ě" (C4 9A) are one entry).

Classification measured with PowerShell P/Invoke: `GetStringTypeW(CT_CTYPE1)` on a surrogate pair
gives only C1_DEFINED (U+20000, U+1D400, U+10400); U+0301 is C3_NONSPACING; `icu.dll` (System32)
`u_charType`: U+20000 = 5 (Lo), U+1D400 = 1 (Lu), U+1F4C1 = 27 (So), U+0301 = 6 (Mn).
