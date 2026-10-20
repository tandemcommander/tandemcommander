# Contract: `src/common/salu8letter.h` (internal, header-only, saltests)

Not a plug-in interface: shared by the Renamer and saltests (plug-ins may include it - header-only,
`windows.h` only). Every function takes `const char*` and works the same with signed or unsigned
`char`.

| Function | Rule |
|---|---|
| `int SalU8UnitLen(const char* p, const char* end, unsigned* value)` | length (1-4) of the unit at `p` (`p < end`) and its value (R1); never 0 |
| `const char* SalU8UnitBack(const char* start, const char* q)` | start of the unit ending at `q` (`q > start`), never before `start`; consistent with forward stepping from any boundary at or before `start` |
| `BOOL SalU8IsUnitBoundary(const char* start, const char* end, const char* q)` | `q` is not inside a valid multi-byte unit (`q == start` or `q == end` -> TRUE) |
| `unsigned SalU8LetterTypes(unsigned value)` | C1 type bits (`C1_UPPER` ... `C1_ALPHA`) + `SALU8_TYPE_MARK` for a non-ASCII code point (R2); 0 for invalid bytes and lone surrogates; ASCII by `GetStringTypeW` too (the engine keeps its own table for ASCII) |
| `BOOL SalU8IsWordValue(unsigned value)` | regex word: ALPHA, DIGIT or MARK, or `_` |
| `BOOL SalU8IsAlnumAt(const char* text, int len, int pos)` / `SalU8IsAlnumBefore(...)` | plain whole words (moved from `salu8fold.h`): the unit at / ending at `pos` is ALPHA, DIGIT or MARK (now also outside the BMP and marks) |

`salu8fold.h` gains `unsigned SalU8FoldCodePoint(unsigned cp)` (same-length lower case, U+03C2 ->
U+03C3) used by `SalU8FoldSameLength`.
