# Fix log: 169 - Change Case renames accented names correctly

Backlog: `specs/NEXT-WORK.md` item 19, B-4 (068 review F-P5-13: "`AlterFileName` byte-folds UTF-8
names"; "the highest-risk fix of the review - it also drives Change Case, which renames files on
disk").

## Measured

`probe/change_case_probe.ps1` (hidden desktop, English UI, ACP 1250): a folder with one file, all
selected, Change Case (747) with the case radio button and "Whole filename", OK; the folder read
afterwards.

| Row | Build before (`Debug_x64_pre169`) | After |
|-----|-----------------------------------|-------|
| CTRL-LOWER `ASCII.TXT` -> `ascii.txt` | PASS | PASS |
| CZ-LOWER `ŠÁRKA.TXT` -> `šárka.txt` | Error Moving File (123), unchanged | PASS |
| CZ-UPPER `žluťoučký kůň.txt` | **renamed to `żLUťOUďKý Kůň.TXT`** | `ŽLUŤOUČKÝ KŮŇ.TXT` |
| GR-UPPER `ελληνικα.txt` | **renamed to `ελληνΥΪα.TXT`** | `ΕΛΛΗΝΙΚΑ.TXT` |
| RU-MIXED `привет мир.txt` | unchanged (no message) | `Привет Мир.Txt` |
| CZ-PARTMIX `ČERNÁ KOČKA.TXT` | Error Moving File (123) | `Černá Kočka.txt` |

Before 7 / 5, after 12 / 0 (`probe/result_before.txt`, `result_after.txt`). The defect does more
than refuse: the byte-folded UTF-8 is sometimes valid and **names a different file** - the file
was renamed to it.

Two probe errors on the way, both found by their own diagnostics: `fix_probe_lib`'s `Find-Ctl`
finds only edits and combo boxes (the radio buttons were never set - every row ran as "Lower
case", the preselection); the probe has its own button lookup and clicks with `BM_CLICK`.

## Cause

`AlterFileName` (`salamdr2.cpp`) mapped every byte through `LowerCase` / `UpperCase` - the code
page's tables (`CharLowerA` per byte) - and the names are UTF-8.

## Work

- `src/common/salaltername.h`: `SalU8CaseChar` (one UTF-8 character mapped as a whole with
  `LCMapStringEx(LOCALE_NAME_INVARIANT, LCMAP_UPPERCASE / LCMAP_LOWERCASE)`, only when the mapped
  character has the same UTF-8 length; ASCII by its own rule; invalid bytes, overlong forms and
  WTF-8 surrogates copied) and `SalAlterFileNameU8` - the old algorithm, every format and mode,
  on whole characters. The name keeps its byte length: the callers' buffers (sized for the
  source; Change Case writes into `BuildName`'s at an offset) and the name / extension split stay
  exact. The explorer style (format 5) recognises an 8.3 capital name in ASCII only.
- `src/salamdr2.cpp`: `AlterFileName` calls it (174 lines of the old body removed). The plug-in
  service `CSalamanderGeneral::AlterFileName` goes through it too (FTP passes panel names, UTF-8).
- saltests `TestAlterName169`: a port of the old algorithm (ASCII tables) against the new one on
  168,000 random ASCII cases - 0 differ; the probe's UTF-8 names, only-name / only-extension,
  dotted / dotless i and sharp s (kept: another length), an emoji, an invalid byte, a WTF-8 lone
  surrogate, a cut sequence, the explorer style, no growth.

Build: BUILD SUCCEEDED; saltests 22,321 / 0; `check_encoding.py` TOTAL 0.

## Regression

163 temp_selection (uses Change Case) 12 / 0, 158 cs_overwrite 10 / 0.

## Review

Independent refute-first review (read-only): nothing CRITICAL; correctness, buffer bounds (the
output is exactly the input's length; `SeqLen` stops at the terminator) and the plug-in contract
(`spl_gen.h`: a result no longer than the source, `srcName` restored) not refuted; the old
algorithm's port in saltests faithful; the invariant non-linguistic mapping is the file system's
kind (a difference from a volume's `$UpCase` would fall into 158's identity check).
- SHOULD-FIX, taken: the cost was unmeasured - `RefreshListBox` maps every item when the name
  format is not "as is". Measured in saltests: 100,000 names of 20 CJK letters 151 ms, of 20 Czech
  letters 148 ms (Debug, about 1.5 microseconds a name) - no change needed.
- SHOULD-FIX, taken: the length guard was not shown to act - now a check that Windows maps
  U+023A (2 bytes) to U+2C65 (3 bytes) and that the letter is kept.
- NIT, accepted: format 5 leaves an all-capital 8.3 name with a non-ASCII letter unchanged
  ("ČTI.TXT"; it was made into wrong bytes before); title-case digraphs as before.
- NIT, recorded (NEXT-WORK): `zip.cpp` ~4041 `lstrcpyn(nameBuf, fileOrDirName, MAX_PATH)` can cut a
  name inside a character (older, unrelated).

saltests 22,323 / 0.
