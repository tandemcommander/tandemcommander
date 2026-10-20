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

## Analyze

`speckit-analyze`: 0 CRITICAL, 0 HIGH. MEDIUM I1 (the spec's assumption named only nonspacing marks,
research R2 all marks) fixed. LOW C1 (no task for the CHANGELOG entry - written at closing) and A1
(SC-003 names no row counts - recorded per probe here) accepted. Second run: nothing above LOW.

Added row `ww-mark` (the plain "Whole words" search, FR-014) and measured it on the same build
(`probe/result_before_wwmark.txt`): "Cafe" -> "Tea" with Whole words on "Cafe" + U+0301 renamed
the file to "Tea" + U+0301 - the combining mark was judged no letter, so "Cafe" was a whole word and
the accent landed on another word. Before total: 17 of 19 RUN rows FAIL.

## Work

- `src/common/salu8letter.h` (new, header-only): units - `SalU8UnitLen` (a valid character, a
  WTF-8 lone surrogate, else one byte = `SALU8_INVALID_BASE + byte`), `SalU8UnitBack`,
  `SalU8IsUnitBoundary`; `SalU8LetterTypes` (C1 types of `GetStringTypeW` for the BMP;
  `icu.dll` `u_charType` - loaded from System32 at the first use - outside the BMP and for marks;
  without ICU a BMP mark by C3_NONSPACING / C3_VOWELMARK when the letter is not alphabetic - Windows
  calls a precomposed "e-acute" nonspacing too); `SalU8IsWordValue` (letter, digit, mark, `_`);
  the plain whole-word tests `SalU8IsAlnumAt` / `SalU8IsAlnumBefore` moved here from salu8fold.h
  (now letters, digits and marks, also outside the BMP).
- `src/common/salu8fold.h`: `SalU8FoldCodePoint` (210's same-length lower case + the final sigma
  as sigma), used by `SalU8FoldSameLength` - the plain and the regex search agree.
- `regexp.cpp` / `regexp.h` (the engine): `.` / classes consume a unit; a class is a
  variable-length operand (the bitmap of ASCII and of bytes that start no letter, NEG, type tests,
  code-point ranges); POSIX classes / `\w` no longer set bitmap bits >= 0x80 (the code page's
  meaning) - they test the letter's types; ranges of two ASCII (or byte) bounds keep the old byte
  loop exactly (also its quirks: an escaped end is exclusive, a reversed range wraps), a non-ASCII
  bound makes a code-point range; a literal run backs off its last unit before `*+?`, a one-unit
  literal is SIMPLE and repeated whole; EXACTLY ends only on a unit boundary; `\x` escapes that form
  one character are one unit (case-insensitive: folded); STAR / PLUS back off one unit at a time,
  UG* advance by the unit; `\b` / `\B` judge the unit before and at the position (ASCII by the
  engine's `IsWord` as before); look-behind widths count units; `RegExec` starts only at unit
  boundaries.
- `crenamer.cpp`: `RESubst` skips a whole unit after an empty match; whole words via salu8letter.h.
- `dialogs.cpp`: `HistoryComboBox` dedupes by `SalNameOrderEqualCI` (092) instead of the code-page
  `StrICmp`.
- `saltests.cpp`: `TestU8Letter254` (units over mixed text incl. torn, overlong, truncated, F5 and
  surrogate bytes - stepping back equals stepping forward and boundaries are exactly the forward
  positions; types of Cyrillic, Arabic digit, marks Mn / Mc / Me, e-acute, CJK / Deseret /
  mathematical letters and digits outside the BMP, an emoji; word values; whole words with a mark;
  the sigma fold).

Not changed (decided): the preview's sort (already by letters, see above).

## Checks

- Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Build: `.\build.cmd` -> first attempt `error C2440` (const char* from `SalU8UnitBack` into the
  STAR back-off pointer) - cast added; second -> `BUILD SUCCEEDED`.
- saltests: `saltests: 24439 checks, 0 failed`.

## Measured (after)

`probe/result_after.txt`: RUN 19 / 19 PASS, END 19 / 19 PASS (38 / 0), registry restored identical:
dot "Xluť", w-cyr "W", class "zluť", negclass "Nluť", range "Rluť", quant "Zluť", **wordb "ЖабA"**
(the last а), lookb "žLuť", esc "Zluť", sigma / bm-sigma "λόγοs", mark "W x", nonbmp "W x", posix
"P", ci-class "zluť", empty "-ž-", ww-mark nothing renamed, the ASCII controls as before.

Regressions (`probe/regress_*.txt`, hidden desktop, each registry restored identical): 210
`ren_search_probe` 16 / 0, 196 `ren_cs_probe` 8 / 0, 199 `ren_83_probe` 6 / 0, 206
`ren_dir83_probe` 10 / 0, 207 `ren_long_probe` 8 / 0, 208 `ren_case_probe` 12 / 0, 209
`ren_subdir_probe` 8 / 0. The before run of this probe is the negative control: 17 of 19 RUN rows
failed on the build without the fix.

Limits left: a case-insensitive class or range compares the folded (lower-case) letters, and a
letter whose two cases differ in UTF-8 length stays case-sensitive (210); no canonical equivalence
(precomposed "e-acute" is not "e" + U+0301); a look-behind of alternatives with the same byte width
but different letter counts (e.g. `(?<=ab|z-caron)`) is now refused as "not fixed width" - it is
fixed in letters only when the counts agree (the reverse, `(?<=a|z-caron)`, was refused before and is
accepted now); without icu.dll a letter outside the BMP is in no class (still one whole letter).

## Review

### Review 1 (refute-first, independent agent)

Sound: the fix-log measurement re-run in a standalone build of the engine (main reproduces, the
branch fixes); 79,616 non-ASCII cases - main 21,659 invalid-UTF-8 results, the branch 0; ASCII
4,928 pattern / name / option cases byte-identical to main (results and error codes); the
variable-length class sized alike in both passes, RegInsert / RegNext safe; back-off consistent;
RESubst skip; no data-loss path besides M1.

- **MUST M1** - a backslash before a non-ASCII letter (`\ž`, `[\ž]`, `[a-\ž]`): `GetEscapedUnit`
  returned the lead byte as a code point (U+00C5) - `[\ž]` renamed "Åluť.txt" to "Zluť.txt" (a
  wrong file name; reproduced on the hidden desktop), `\ž` no longer matched "žluť" (main did, byte
  by byte). **Fixed**: an escape of a byte >= 0x80 takes the whole letter (`ParseLiteralUnit`).
- **SHOULD S1** - a case-insensitive `\x` letter inside a bracket was not folded (`[\xC5\xBD]` missed
  "Žluť"). **Fixed**: `GetEscapedUnit` folds every escaped letter when case-insensitive (outside
  and inside brackets, range bounds too).
- **SHOULD S2** - the engine has no unit tests (it lives in the plug-in with its CType / LowerCase
  tables). Taken as probe rows instead: bs-lit, bs-class, esc-ci-cls, ungreedy (the probe now has
  23 rows).
- NOTE N1 - `(?<=ab|ž)` now refused "not fixed width" (fixed in letters only when the counts agree):
  kept, recorded under *Limits*. N2 - a range between a byte that starts no letter and a letter
  (`[\xC5-ž]`) made U+00C5..U+017E: **now no range** (both bounds members); an escaped ASCII end
  stays exclusive (the old byte loop, FR-012) while a letter end is inclusive - recorded. N3 - a
  latent uninitialised read in `ClassMatch` at the end of the text (unreachable): guarded. N4 - the
  history now treats "Ž" / "ž" as one entry (FR-011, as ASCII did): as designed.

Rebuilt: `BUILD SUCCEEDED`; saltests 24439 / 0.

After the fixes: `probe/result_after.txt` 46 / 0 (23 RUN + 23 END), registry restored identical -
bs-lit "Zluť", bs-class nothing renamed ("Åluť" stays), esc-ci-cls "Zluť", ungreedy "Xuť", the 19
earlier rows as before.
