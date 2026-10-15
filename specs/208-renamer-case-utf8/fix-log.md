# Fix log: 208 - The Renamer's case changes work on letters of UTF-8 names

Found by the review of 207: the Renamer's `ChangeCase` (`src/plugins/renamer/crenamer.cpp`) applies
the code-page byte tables `LowerCase` / `UpperCase` (from `CharLowerA`) to the bytes of UTF-8
names (interface 104), and "strip diacritics" converts the bytes through `CP_ACP`.

## Measured (before)

Probe `probe/ren_case_probe.ps1` (199's driver; the new name a pattern with a case argument; the
expected names spelled with code points, the result compared as UTF-8 hex), the build at 207
(`probe/result_before.txt`, 5 / 5), the file "Zlutoucky kun.txt" with its Czech letters
(Z-caron, t-caron, c-caron, y-acute, u-ring, n-caron):
- **low** (`$(OriginalName:lower)`), **mix** (`:mixed`), **dia** (`:stripdia`): the rename failed
  **"(123) The file name is incorrect"** - the lead bytes were changed (C5 -> E5 ...), invalid UTF-8;
- **up** (`:upper`): only the ASCII letters changed ("ZLuTOUcKY KUN" with the Czech letters as
  they were);
- **cjk-up** ("<2 CJK letters>a.txt", `:upper`): "(123)" as well.
No name was mangled on the disk (Windows refused them), but the case functions did not work for
any name with non-ASCII letters.

## Work

- `crenamer.cpp` `ChangeCase` -> `int ChangeCase(change, dst, dstSize, src, start, end)`: the part
  is converted to UTF-16 (`CP_UTF8`, `MB_ERR_INVALID_CHARS` - text that is not valid UTF-8, a WTF-8
  lone surrogate or a legacy name, is copied unchanged), `CharLowerBuffW` / `CharUpperBuffW`;
  mixed: a capital after a non-alphanumeric character (`IsCharAlphaNumericW`, the character before
  the part decoded from `src`); strip diacritics: `NormalizeString` D, the combining marks
  U+0300-U+036F dropped, `NormalizeString` C. The UTF-8 length may change (c-caron 2 bytes -> c 1):
  it returns the bytes written, -1 when they do not fit.
- Its callers: `CVarAlterableString::DoExpand` (`crename2.cpp`), `SafeCopy` with a case
  (`crenamer.cpp`), and `CRenamer::Rename`'s name / extension case options - the name is rebuilt
  in a heap buffer of the capacity it had and its new length returned.
- `rendlg2.cpp`: the script's comparators (`CompareOldNames`, `CompareOldName`,
  `CompareNewNames`) and the duplicate check by the file system's rule (`SalNameOrderCompareCI`,
  092) instead of the code-page `StrICmp` - a case change of a non-ASCII name was not recognised
  as the file itself and asked "Confirm File Overwrite" for it (seen on the first after-run).

Build: BUILD SUCCEEDED.

## Measured (after)

`probe/result_after.txt` 12 / 0: low "zlutoucky kun.txt", up "ZLUTOUCKY KUN.TXT", mix "Zlutoucky
Kun.Txt" (with their Czech letters), dia "Zlutoucky kun.txt" (ASCII), cjk-up "<CJK>A.TXT", opt
(the dialog's name combo "lower", extension combo "upper" - added after: measured on the fixed
build only; its function is the one measured above) "zlutoucky kun.TXT"; no box in any row.
Regressions: 199's probe 6 / 0, 196's 8 / 0, 206's 10 / 0, 207's 8 / 0.

## Review

Refute-first review: accept - sizes bounded in every caller (also a result that grows, U+0250 ->
U+2C6F); `ChangeCase` decodes the whole part before writing, no caller overlaps; no caller relied
on the length staying the same (`BMSubst` / `RESubst` offsets are in the source, `pos` moves by the
bytes written; `Rename`'s capacity and returned length right); mixed case cannot overflow on a
damaged prefix; `SalNameOrderCompareCI` is a total order, `qsort` and `bsearch` share it. The
comparators also close an older data loss (by reading, not driven): `a.txt -> Z-caron.txt` and
`z-caron.txt -> b.txt` in one run - the code-page `CompareOldName` did not find the new name among
the old ones, no dependency chain, the overwrite question named `z-caron.txt`, and the script ran
`a -> Z-caron` first: "already exists", the target deleted, `z-caron.txt` lost. Taken: strip
diacritics emptied the part when the second `NormalizeString` failed - left unchanged now
(re-measured 12 / 0). Recorded as **feature 210** (older): `rendlg3.cpp` ~169 the code-page
`StrICmp` "nothing to do" shortcut (folders C-dot / E-caron compare equal: a move reported done
without moving); case-insensitive search folds UTF-8 bytes through the code-page table (the BM
search `common/moore.cpp` ~146, the regex `Caseles` code) - with "Match case" off a search can
replace another letter (a wrong name written) or cut a CJK letter (refused, 123); the whole-words
test judges single bytes; the cut arguments (`$(OriginalName:0,1)`) count bytes - a split letter
is refused (123). NITs: letters outside the BMP and combining marks break words in mixed case; NFC
also maps compatibility singletons (U+F900, U+2126, U+212A); a WTF-8 / legacy name gets no case
change at all; a failed `malloc` reads as "name too long"; probe gaps (regex subexpression with a
case, extension only, `IncludePath`, the chain above, a length-changing case).
