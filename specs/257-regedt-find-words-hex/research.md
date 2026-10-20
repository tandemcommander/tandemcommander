# Research - 257 Registry Editor Find: whole-word regexp, empty regexp, letters in quoted hex

## R1 - Where the whole-word test reads its characters

`CFindThread::Test` (src/plugins/regedt/finddlg.cpp), regexp branch: the value (converted to the
code page for texts) is split into lines `start..end`; `SalRegExp->SetLine(start, end)` and
`SearchForward(pos, matchLen)` return `pos` **relative to the line**. The whole-word test read
`text[pos - 1]` and `text[pos + matchLen]` - relative to the value. Correct on the first line only.

- Decision: a pure rule `SalRegFindWholeWordInLine(line, lineLen, pos, matchLen)` in
  `src/common/salregfind.h`, called with `start` and `end - start`. Boundaries stay "a space
  character (isspace) or the line's start / end", `matchLen > 0` required (unchanged).
- Rationale: the line pointer and its length are passed together; the rule is testable.
- Alternatives: replacing `text` by `start` inline - the same effect, no saltests check.

## R2 - The empty regular expression

`CFindDialog::StartSearch` (finddlg2.cpp) regexp branch: `patternALen = WStrToStr(...)` counts the
terminating NUL (1 for an empty pattern; the thread's `memcpy` needs the NUL for
`SalRegExp->Set(PatternA)`). So `Test`'s "empty pattern = everything" exit
(`PatternALen == 0 && PatternWLen == 0`) is never taken; `regcomp("")` compiles a pattern that
matches the empty string, which Whole words refuses (`matchLen > 0`). Measured: probe EMPTY-RX
finds all, EMPTY-RX-WW finds nothing.

- Decision: in the regexp branch, an empty converted pattern gets length 0 - the thread then skips
  the regexp set-up (`Init`: `if (PatternALen || PatternWLen)`) and `Test` returns TRUE, exactly
  as for the empty plain text.
- Alternatives: letting the whole-word rule accept zero-length matches - changes the meaning for
  non-empty patterns that can match empty (`a*`), rejected.

## R3 - Quoted letters of a hex pattern

`ConvertHexToString` (utils.cpp): `'...'` text goes one UTF-16 unit at a time through
`WStrToStr(hex + len, 1, s++, 1)`. `WideCharToMultiByte(CP_ACP, ...)` with a one-byte buffer fails
(ERROR_INSUFFICIENT_BUFFER) for a letter of 2+ bytes; `WStrToStr` then writes 0 into that byte.
A surrogate pair converted unit by unit gives two replacement characters instead of one letter.
`ValidateHexString` counts 1 byte per unit, so the length check before the search did not match
the bytes.

- Decision: one pure function `SalHexPatternToBytes(text, codePage, strict, out, outSize, &len)` in
  `salregfind.h` with both modes of today (strict = `ValidateHexString`'s grammar: two digits,
  only spaces between; lenient = `ConvertHexToString`'s), converting each `'...'` run as one text
  with `WideCharToMultiByte(codePage, 0, ...)` - the same call `WStrToStr` makes for the plain
  pattern - and counting / writing exactly those bytes. `out == NULL` counts only. The plug-in
  wrappers pass `CP_ACP`; saltests pass 65001, 932, 1250.
- A conversion that fails outright (returns 0 for a non-empty run) → BAD (Validate shows the
  existing "bad hexadecimal string" box); a run that does not fit `outSize` → TOOLONG (the
  existing `IDS_LONGDATA` path, `len = -1`).
- Hex digits: ASCII `0-9 a-f A-F` - the old `towlower(c) in a..f` accepts no other character
  (no non-ASCII character lowercases into `a`-`f`).
- Alternatives: UTF-8 for `'...'` - the help documents only `"..."`; the item names the code page
  first; the plain-text byte pattern uses the code page. Rejected.

## R4 - Callers (enumerated)

- `ConvertHexToString`: `CFindDialog::StartSearch` only.
- `ValidateHexString`: `CFindDialog::Validate` only.
- `CFindThread::Test` whole-word regexp test: the one site in the regexp branch.
- `PatternALen` in regexp mode: `Init` (non-zero test, then `Set(PatternA)`), `Test` (empty exit).
  The constructor `memcpy`s `patternALen` bytes - with 0 nothing is copied and nothing reads
  `PatternA`.
