# Fix log: 210 - The Renamer's search, whole words and cut work on letters of UTF-8 names

Found by the review of 208: the Renamer's case-insensitive search folds the BYTES of UTF-8 names
through the code page's table - the core's Boyer-Moore (`CSalamanderBMSearchData` without
`SASF_CASESENSITIVE`) and the plug-in's own regular expressions (`regexp.cpp`: `LowerCase`,
`MemChrI`, `MemCmpI`, `InvertCase`); whole words judge single bytes (`IsAlnum`); the cut arguments
count bytes; `MoveFile`'s "nothing to do" shortcut compares paths with the code-page `StrICmp`.

## Measured (before)

Probe `probe/ren_search_probe.ps1` (199's driver; Search 108 / Replace 109 and the check boxes
Case sensitive 112, Whole words 113, Regular expression 115 set per row; names compared as UTF-8
hex), the build at 209 (`probe/result_before.txt`, 7 / 5; the regex rows on the build without the
fix, `probe/result_before_regex.txt`, 2 / 2):
- **bm-wrong** ("C-dot x.txt", U+010A = C4 8A; search "E-caron", U+011A = C4 9A, -> "E",
  case-insensitive): **renamed to "Ex.txt" - another letter replaced** (cp1250 folds the
  continuation bytes 8A and 9A as one letter's two cases); **re-wrong** (the same as a regular
  expression): **"Ex.txt"** too;
- bm-cz / re-cz ("z-caron lut-caron.txt", search "Z-caron" -> "Z", case-insensitive): "Nothing to
  do" - one letter's two cases did not match; re-sub ("^(z-caron)" -> "[$1]" on "Z-caron..."):
  "Nothing to do";
- ww (whole words "k u-ring n-caron" -> "pes" in "z-caron lut y-acute k u-ring n-caron.txt"):
  "Nothing to do" - the last byte of n-caron was judged no letter;
- cut (`$(OriginalName:0,1)_.txt` on "Z-caron..."): **"(123) the name is incorrect"** - half of
  the letter;
- bm-cs (the control, case-sensitive): fine.
(The first run of the probe shared one variable for "z-caron" and "Z-caron" - PowerShell names
ignore case - so two rows searched the same case; fixed and re-measured.)

## Work

- `src/common/salu8fold.h` (header-only, saltests 30 checks): `SalU8FoldSameLength` folds by
  characters - each valid UTF-8 character whose lower case (`CharLowerBuffW`) has the same UTF-8
  length is replaced by it, everything else copied: the length is kept, an offset in the folded
  text is the original's, a match lies on whole characters, two letters fold to one only when they
  are one letter's two cases; `SalU8IsAlnumAt` / `SalU8IsAlnumBefore` (whole words by
  characters, `IsCharAlphaNumericW`); `SalU8Advance` / `SalU8Back` (cut by characters).
- `crenamer.cpp`: Boyer-Moore always case-sensitive; a case-insensitive search folds the pattern
  (`SetOptions`) and searches a folded copy of the name (`BMSubst`), the offsets used on the name;
  whole words by characters. Regular expressions: the pattern's non-ASCII characters folded before
  `RegComp` (the syntax is ASCII), the name's in `RESubst` (a folded copy executed; the parts and
  the subexpressions copied from the name - `ExecSource` / `ExecFolded`).
- `regexp.cpp`: the engine folds ASCII only (`REG_LOWER`, `REG_INVERT`, `RegMemChrI`,
  `RegMemCmpI` instead of the code-page `LowerCase`, `InvertCase`, `MemChrI`, `MemCmpI`).
- `crename2.cpp`: the cut positions count characters.
- `rendlg3.cpp`: the "nothing to do" shortcut only for the very same bytes - the code-page
  `StrICmp` took two folders "C-dot" / "E-caron" for one and the move was reported done without
  moving (by reading); a case-only difference of a folder goes to the move: measured, `MoveFileW`
  of `dir\a.txt` to `DIR\a.txt` in an ordinary folder succeeds and changes nothing.

Build: BUILD SUCCEEDED; saltests 22,428 / 0.

## Measured (after)

`probe/result_after.txt` 14 / 0: bm-wrong and re-wrong - "Nothing to do", the name kept; bm-cz and
re-cz - "Zlut-caron.txt"; re-sub - "[Z-caron]lut-caron.txt" (the name's own letter); ww - "z-caron
lut y-acute pes.txt"; cut - "Z-caron_.txt"; bm-cs as before (16 / 0 with the regex rows
re-wrong and re-sub). Regressions: 199's probe 6 / 0, 196's 8 / 0, 206's 10 / 0, 207's 8 / 0,
208's 12 / 0, 209's 8 / 0.

## Review

Refute-first review: accept - the folding premise holds (a character is replaced only by its own
lower case of the same length: K-sign, Ohm, Angstrom, the Turkish I with dot, capital sharp s stay
unfolded; theta's two capitals fold to one theta - one letter); ASCII never changes in the pattern,
so the syntax, counts, escapes and error positions are untouched; every remaining fold in the
engine is ASCII-only, `RegStart` / `RegMust` come from the folded pattern; the folded copy covers
the engine's read at `RegEol`; the frees run on every return; the preview and the rename both go
through `CRenamer::Rename`; the decoder rejects overlong forms, surrogates and C0 / C1 / F5+;
whole words for ASCII names unchanged. Taken: (1) the shortcut by `SalNameOrderEqualCI` made a
case-sensitive folder worse ("zh" -> "ZH" Cyrillic: a separate folder created, the move reported
done, the file left) - now only byte-identical paths (above); (2) a group that took no part in the
match (`Startp == NULL`) is not copied; the header includes `windows.h` / `string.h` itself.
Recorded (older, not of this fix): regular expressions still judge `\b`, `\w`, `\d`, `\s`, POSIX
classes, '.', bracket classes and a quantifier after a multi-byte letter by single bytes - a split
letter is refused "(123)"; a `\xC5\xBD` escape matches neither case when case-insensitive (it
matched the capital before); bracket ranges with non-ASCII bounds are meaningless over UTF-8;
the history dedupe (`dialogs.cpp` ~259) and the preview's sort use the code-page `StrICmp`
(nothing renamed); letters outside the BMP and combining marks break words; the Greek final sigma
does not fold with sigma (a match missed, never a wrong letter).
