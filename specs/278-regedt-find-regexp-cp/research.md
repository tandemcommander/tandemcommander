# Research - 278-regedt-find-regexp-cp

## R1 - How big is the code-page form of a text?

- Decision: ask the API - `WideCharToMultiByte(codePage, 0, text, units, NULL, 0, NULL, NULL)` -
  and convert into a space of at least that size; the converted count is the searched length.
- Rationale: the item's *Expected*; the same counting call `SalHexPatternToBytes` (257) and the
  pattern conversion of `finddlg2.cpp` (191: `WStrToStr(NULL, 0, Pattern)`) use. A fixed factor
  (units * 4) would also fit but wastes memory for long values and still needs the converted
  count for the length.
- Alternatives considered: `units * 4` worst-case reservation (rejected: still needs the real
  count; UTF-8 needs up to 3 bytes a unit, DBCS 2 - a factor is a guess the API answers);
  converting to UTF-8 instead of the ANSI code page (rejected: the regexp pattern is in the ANSI
  code page - spec Clarifications).

## R2 - What if the conversion fails?

- Decision: the rule returns -1; the call site returns FALSE (no match) for that text.
- Rationale: FR-003 - never search leftover bytes; conservative (the search goes on). With flags
  0 the conversion fails only for an invalid code page or a too small space - both excluded by
  counting first - so -1 is a guard, not an expected path.
- Alternatives considered: search an empty text (rejected: an empty regexp is already answered
  before - `PatternALen == 0` - so "empty" would never match anyway; -1 is clearer).

## R3 - Lone surrogates and unrepresentable letters

- Measured (python ctypes, 2026-10-21), units `D800 0061 0436` (lone surrogate, `a`, `ж`):
  65001 → count 6, `EF BF BD 61 D0 B6`; 932 → count 4, `3F 61 84 77`; 1250 → count 3,
  `3F 61 3F`. Flags 0 replace and succeed - the count call and the conversion agree. Unchanged
  behaviour; no special case.

## R4 - Is the old length right on single-byte code pages?

- Yes: one byte a unit, so the counted size equals the unit count and the searched bytes are
  the same as before (SC-003). Checked in saltests under 1250.

## R5 - Can the GUI case be driven here?

- No: the ANSI code page is a system setting (1250 here); changing it needs a restart. The
  rule is proven with the code page as a parameter; 257's probe re-run shows the regexp branch
  still works on 1250. The GUI check under 65001 is a `person-step` item.
