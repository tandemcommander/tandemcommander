# Research - 313 quick search ignores diacritics

## R1 Which marks are dropped

- **Decision**: the code points of the generic diacritical-mark blocks U+0300-036F, U+1AB0-1AFF,
  U+1DC0-1DFF, U+20D0-20FF, U+FE20-FE2F, as they occur in the canonical decomposition of a
  character (or stand alone in a name).
- **Rationale**: every precomposed Latin, Greek and Cyrillic letter decomposes to a base letter and
  marks from U+0300-036F (Czech `ž` = z + U+030C, Vietnamese `ệ` = e + U+0323 + U+0302, Greek `ά` =
  α + U+0301, Cyrillic `й` = и + U+0306, `ё` = е + U+0308). The other blocks hold further marks of
  the same kind. Marks of other scripts are in their script's block (Hebrew U+0591-05C7, Arabic
  U+064B-065F, Devanagari U+0900-097F, Thai U+0E31-0E4E, Japanese voiced marks U+3099/309A) and
  often tell letters or syllables apart (`が` vs `か`, a virama joining consonants).
- **Alternatives**: all of Unicode category Mn (the item's first wording) - makes Japanese,
  Indic and Thai searches noisy, which the item's *Notes* flagged as unverified; rejected
  (conservative). `CompareStringEx(NORM_IGNORENONSPACE)` - linguistic, locale-dependent, would
  bring back a per-position comparison (the 244 slowness); rejected.

Note on Cyrillic: `й` folds to `и` and `ё` to `е` (their decomposition marks are in U+0300-036F).
This is the symmetric "ignore diacritics" the maintainer decided; a user typing `й` still finds
`й` names (and `и` names too).

## R2 The fold table

- **Decision**: after lower-casing, `ł`->l, `ø`->o, `đ`->d, `ß`->ss, `æ`->ae, `œ`->oe, `ı`->i;
  the capitals `Ł Ø Đ ẞ Æ Œ` map the same (they lower-case to the small letters, but the table
  lists them so the result does not depend on the system's case table).
- **Rationale**: the item's list (+ capital sharp s, the same letter). These letters have no
  canonical decomposition, so dropping marks does not reach them.
- **Alternatives**: a full "Latin-ASCII" folding (ð, þ, ħ, ŧ, ŀ, ĸ, …) - beyond the item; rejected
  (conservative, spec Clarifications).

## R3 Empty keys (a lone mark)

- `CharKey` returned 0 for "does not fit", and `SalQFBuildKey` treated 0 as overflow; the cache
  used `Count == 0` for "not computed".
- **Decision**: `CharKey`/`CharKeySystem` return **-1** for "does not fit" and 0 for an empty key;
  the cache marks an empty key with `0xFE` (0 = not computed, 0xFF = longer than 4 units).
  `SalQFBuildKey` adds no unit for an empty key; the character's bytes are then covered by the
  previous unit's character for match ends (`Offsets[end]` is the byte offset of the next unit's
  character, or the text length), so a match that ends on a letter includes the marks after it.
- A mask segment whose key is empty is dropped (`SalQFBuildMaskKeys`), so `KeySegAt` never sees an
  empty segment (it would read `Starts[Count]`); a mask with no non-empty segment behaves as one
  of wildcards only (every name, `PREFIX`, as `/` does). `LastNoDot` (the last segment without
  its final dot) may be empty as before; it is built from a non-empty segment only.

## R4 Boundaries and offsets

- `Starts[i]` = 1 for the first unit of a character with a non-empty key, 2 for a later unit of a
  folded letter (`ß` -> `ss`: 1, 2), 0 for other later units (`が` -> `か` + U+3099: 1, 0). A later
  ASCII unit can only come from the fold table (a decomposition's later units are marks), so
  `SalQFBuildKey` sets 2 for a later unit < 0x80. A match may end before a 2 (review 313: else
  `strasse` typed letter by letter stuck at `stra`, every partial text being refused); the
  reported end then moves behind the whole letter (`KeyEndOffset`).
- `MatchStart = Offsets[s]` is the first byte of a character; `MatchEnd = Offsets[end]` is the
  first byte of the next character that has units (marks in between included) or the length. The
  caret (`QFMatchEnd`) and Right (appends the character at `QFMatchEnd`) therefore stay on whole
  characters of the name.

- Left/Backspace (review 313): the match of a decomposed name now ends behind the marks, so the
  old "remove the last code point" removed only an ignored mark and the match came back the same
  (Left stuck). `SalQFCutLastLetter` removes trailing marks of R1 and then the letter.

## R5 Tests that change

- `"x" + ú` against `u`: was no match (`ú` = u + mark), now a SUBSTRING 1..3.
- `"xu" + U+0301` against `u`: the match end moves from 2 to 4 (the mark belongs to the letter).
- M3 compares the new mode with the 0.1.10 rule (which keeps accents). New form: for pairs where
  neither the name nor the typed text holds a character the folding changes (a mark of R1 in its
  NFD, or a table letter), M3 stays exact; for the others M3 checks the superset property - every
  0.1.10 match is still found, a 0.1.10 prefix match is still `PREFIX` - and new explicit cases
  give the exact folded answers. The 244 "`strasse` against `Straße`" exception disappears (it now
  matches, as the 0.1.10 rule does).

## R6 Performance

- The fold runs inside the cached per-character computation: a BMP character's key is computed
  once per process, then copied. Per name, the key is built once per search (244). Expected cost:
  unchanged within noise; measured with the 244 `-Perf` probe on a scratch Release build.
