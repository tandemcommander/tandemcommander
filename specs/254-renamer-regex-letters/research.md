# Research: 254 - Renamer regular expressions by whole letters

## R1 The unit

- **Decision**: a unit is (a) a valid UTF-8 character (salu8fold's `SalU8DecodeChar`: no overlong,
  no surrogate, <= U+10FFFF), (b) a WTF-8 lone surrogate `ED [A0-BF] [80-BF]`, or (c) one byte that
  starts neither. Its value: the code point for (a)/(b), `0x110000 + byte` for (c).
- **Rationale**: names are WTF-8 (CLAUDE.md 066); a lone surrogate must not be split. Lead bytes
  are never continuation bytes, so units never overlap: stepping BACK from a boundary (look up to 3
  bytes for a lead whose unit ends exactly there, else one byte) gives the same segmentation as
  stepping forward - the engine can back off by units without remembering positions.
- **Alternatives**: remember every position in an array during `RegRepeat` (memory per attempt,
  no gain); decode to UTF-16 and run a wide engine (the engine, its offsets and 210's folded copy
  are byte-based - a rewrite).

## R2 Classification

- **Decision**: ASCII - the engine's `CType` table as today (unchanged results). Non-ASCII BMP -
  `GetStringTypeW(CT_CTYPE1)` (the same C1 types the POSIX classes are defined by); MARK when
  `CT_CTYPE3` has `C3_NONSPACING` or `C3_VOWELMARK`, or `icu.dll` says Mn / Mc / Me. Outside the
  BMP - `icu.dll` `u_charType` mapped to C1 types (Lu -> ALPHA|UPPER, Ll -> ALPHA|LOWER, Lt ->
  ALPHA|UPPER, Lm/Lo/Nl -> ALPHA, Nd -> DIGIT, No/P*/S* -> PUNCT, Zs -> SPACE|BLANK, Zl/Zp ->
  SPACE, Cc -> CNTRL, Mn/Mc/Me -> MARK, others none). Lone surrogates and invalid bytes: no type.
- **Measured**: `GetStringTypeW` on a surrogate pair = C1_DEFINED only; U+093E (Mc) = no C1 type,
  C3_VOWELMARK; U+0903 (Mc) nothing at all; `icu.dll` present, `u_charType` exported (P/Invoke
  cdecl): U+20000 5, U+1D400 1, U+1F4C1 27, U+0301 6, U+093E 8, U+20DD 7.
- **Rationale**: keeps POSIX semantics consistent with today's ASCII; ICU fills only what Windows
  types cannot say. `icu.dll` is part of every supported Windows; loaded from System32 only
  (`LOAD_LIBRARY_SEARCH_SYSTEM32`), never freed, a missing export = no class (fallback).
- **Word** (`\w`, `\b`) = ALPHA | DIGIT | MARK, or `_`. **Plain whole words** = ALPHA | DIGIT |
  MARK (no `_`, as `IsCharAlphaNumericW` today).
- **Alternatives**: ICU for everything (changes BMP results against today's Windows types for no
  reported defect); link `icu.lib` (a load-time dependency of the plug-in and saltests).

## R3 Classes

- **Decision**: operand = the 32-byte bitmap (bits 0-127 ASCII as today; bits 128-255 now mean
  invalid single-byte units and are set only by an explicit `\xHH` in the class) + flags (NEG) +
  type tests (`mask`, `neg`) + code-point ranges. Membership of a non-ASCII unit: in a range, or a
  test passes (`neg ? !(types & mask) : types & mask`); the bracket's `^` inverts (NEG). POSIX
  classes no longer set bitmap bits >= 128 (they were the code page's meaning of a byte).
  `[:ascii:]` = test with mask 0. Case-insensitive: an UPPER or LOWER test means both (the name is
  folded).
- **Ranges**: both bounds ASCII, or both `\x` bytes forming no character (or ASCII + such a byte)
  -> today's byte loop, unchanged (also its result for a reversed range); otherwise a code-point
  range (a byte bound counts as its byte value), its ASCII part in the bitmap; reversed -> nothing.
- **Rationale**: FR-012 for ASCII; a byte loop over UTF-8 lead/continuation bytes means nothing.

## R4 Literals and escapes

- A literal run before `*+?` backs off its last UNIT (today one byte); a run that is one unit stays
  whole and is SIMPLE (STAR / PLUS repeat a unit of any length).
- Consecutive `\xHH` (up to 4) forming one valid character (or WTF-8 surrogate) = one unit;
  otherwise one byte. Case-insensitive: a valid character is folded by `SalU8FoldCodePoint` (210's
  same-length rule + final sigma).
- **EXACTLY** succeeds only when its end is a unit boundary of the name - a lone `\xC5` never
  matches the lead byte of "ž".

## R5 Matching

- `RegExec` tries starts only at unit boundaries (the `RegStart` memchr candidates are checked;
  the general loop steps by units). `RESubst` passes a boundary offset (skip = the unit's length).
- `ANY` / `ANYDOT` / `ANYOF` consume a unit; `RegRepeat` counts units; STAR / PLUS back off one
  unit at a time (bounded by the start); `RegMatchSimple` returns the unit length for UG*.
- `\b` / `\B`: the unit before (`SalU8UnitBack`) and at the position.
- Look-behind: the fixed width is counted in units (literals count their units); it steps back
  that many units, failing at the start of the name.

## R6 Final sigma

- `SalU8FoldCodePoint(cp)`: the lower case of the same UTF-8 length (210), and U+03C2 -> U+03C3
  (both 2 bytes: CF 82 / CF 83). `SalU8FoldSameLength` uses it - the plain search and the regex
  search agree.

## R7 History and sort

- History: `SalNameOrderEqualCI(a, -1, b, -1)` (092) instead of `SG->StrICmp`.
- Preview sort: unchanged - `RegSetStrICmp` already compares non-ASCII by `SalCompareNamesUTF8`
  (core `sort.cpp`, feature 004).
