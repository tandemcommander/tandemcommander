# Feature Specification: Quick search ignores diacritics

**Feature Branch**: `313-quick-search-diacritics`
**Created**: 2026-10-22
**Status**: Draft
**Input**: From backlog item quick-search-ignores-diacritics. Backlog item `quick-search-ignores-diacritics` (backlog/items/quick-search-ignores-diacritics/desc.md) - implement exactly what it describes: "Quick search ignores diacritics: typing zlut finds a name with žluťoučký".

## Current behaviour (baseline, measured at 9b79bd82)

Quick search in the new mode of feature 244 (*Configuration > Panels > Quick search finds text
anywhere in names and shows only the matches*, on by default) ignores case and the difference
between composed and decomposed accented letters, but not the accents themselves. Measured on the
Debug build with the hidden-desktop probe `probe/qs313_probe.ps1` (`probe/result_before.txt`):

- typing `zlut` shows only `zlutý.txt`, not the folder `žluťoučký`;
- typing `ž` + `lut` shows only `žluťoučký` (the `t` is refused, because `ť` differs from `t`);
- typing `cesky` keeps only the `c` (which finds `Übersicht.doc`) and never reaches `Český.txt`;
- `ubersicht`, `lodz`, `reka` (a name stored decomposed, `r` + combining caron + `eka.txt`) do not
  find `Übersicht.doc`, `Łódź.txt`, `řeka.txt`;
- with the option off, `zlut` focuses `zlutý.txt` (the 0.1.10 prefix rule).

Release timing over 100,000 names (`probe/result_perf_before.txt`): ASCII names 9-14 ms per
character; Czech names 16-29 ms per character after the first keystroke (291 ms, the panel layout
filed as `quick-search-first-keystroke-over-100-000-non-ascii-names`).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Find an accented name by typing without accents (Priority: P1)

A user types the name the quick way, without accents (or has a keyboard without the language's
letters). Typing `zlut` shows both `žluťoučký` and `zlutý.txt`; `cesky` finds `Český.txt`;
`ubersicht` finds `Übersicht.doc`; `reka` finds a name stored decomposed.

**Why this priority**: it is the defect of the item; Czech, Slovak, Polish, German, French and
other users meet it every day.

**Independent Test**: hidden-desktop probe rows D01, D03, D04, D07: type the text into a panel of
the fixture folder, Select all + F5, the copied names are exactly the expected matches.

**Acceptance Scenarios**:

1. **Given** a folder with `žluťoučký` and `zlutý.txt`, **When** the user types `zlut`, **Then**
   the panel shows both and nothing else of the fixture.
2. **Given** `Český.txt`, **When** the user types `cesky` (or `Cesky`), **Then** it is shown.
3. **Given** `Übersicht.doc`, **When** the user types `ubersicht`, **Then** it is shown.
4. **Given** a name stored decomposed (`r` + U+030C + `eka.txt`), **When** the user types `reka`,
   **Then** it is shown.

---

### User Story 2 - Typing with accents finds names without them (Priority: P1)

Diacritics are ignored in both directions (decided with the maintainer, 2026-10-22): typing
`žlut` finds `zlutý.txt` as well as `žluťoučký`.

**Why this priority**: the maintainer's decision; the rule must be symmetric.

**Independent Test**: probe row D02; saltests cases with a mask that has marks and a name without.

**Acceptance Scenarios**:

1. **Given** `žluťoučký` and `zlutý.txt`, **When** the user types `ž` + `lut`, **Then** both are
   shown.

---

### User Story 3 - Letters without a decomposition fold too (Priority: P2)

Letters that are not "a base letter plus a mark" in Unicode are folded through a fixed table:
`ł`/`Ł` -> `l`, `ø`/`Ø` -> `o`, `đ`/`Đ` -> `d`, `ß`/`ẞ` -> `ss`, `æ`/`Æ` -> `ae`, `œ`/`Œ` -> `oe`,
`ı` -> `i`. Typing `lodz` finds `Łódź.txt`; `strasse` finds `Straße.txt`.

**Why this priority**: completes the folding for Polish, Danish/Norwegian, Croatian, German,
French and Turkish names; smaller audience than story 1.

**Independent Test**: probe rows D05, D06; saltests cases for every table letter.

**Acceptance Scenarios**:

1. **Given** `Łódź.txt`, **When** the user types `lodz`, **Then** it is shown.
2. **Given** `Straße.txt`, **When** the user types `strasse`, **Then** it is shown.

---

### User Story 4 - Nothing else changes (Priority: P1)

With the option off, quick search is exactly the 0.1.10 rule. ASCII text against ASCII names
behaves as in feature 244. Typing stays as fast as measured in feature 244. The caret and the
Right-arrow extension still work on whole characters of the real name.

**Why this priority**: backward compatibility (Constitution II) and the 244 timing commitment.

**Independent Test**: probe rows D09/D10 with the option off (identical before and after); the
feature 244 probe (all rows PASS, option off identical to its baseline, `-Perf` timing); saltests
M1 (the 0.1.10 rule) unchanged.

**Acceptance Scenarios**:

1. **Given** the option off, **When** the user types `zlut`, **Then** `zlutý.txt` is focused and
   `žluťoučký` is not (the 0.1.10 rule keeps accents).
2. **Given** 100,000 names, **When** the user types, **Then** each keystroke takes no longer than
   in the feature 244 measurement (Release: <= 32 ms per keystroke after the first).
3. **Given** a match that ends on an accented letter of a decomposed name, **When** the caret is
   drawn or Right extends the text, **Then** the caret sits after the whole letter (its marks
   included) and Right appends the next whole character of the name.

### Edge Cases

- A name stored decomposed: the marks belong to the letter before them; a match never ends between
  a letter and its marks.
- A letter that folds to two letters (`ß` -> `ss`, `æ` -> `ae`): the typed text may end inside it,
  so the letters can be typed one by one (`stras` matches `Straße`, `co` matches `cœur`); the match
  then covers the whole letter. A match never starts inside such a letter. (Review 313: with the
  first rule, "the typed text covers it whole", typing `strasse` stuck at `stra`.)
- Left and Backspace remove the last letter together with the marks the comparison ignores, so
  they never remove only an invisible mark of a decomposed name (review 313: Left got stuck).
- A lone combining mark (a mark at the start of a name, or a mark typed alone): it adds nothing to
  the comparison. A typed text consisting only of such marks behaves as a text of only wildcards
  (every name matches, as `/` does since 0.1.10).
- Marks of scripts where they tell letters or syllables apart are kept: Japanese voiced marks
  (`が` stays different from `か`, probe row D08), Hebrew points, Arabic vowel signs, Indic signs
  (virama, vowel signs), Thai marks.
- A name with bytes that are not UTF-8, or a WTF-8 lone surrogate: compared as before, no crash.
- Hangul and other scripts whose decomposition has no marks: unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: In the new mode, the comparison of a name and the typed text MUST ignore the
  nonspacing combining marks (enclosing marks such as the keycap U+20E3 stay) of their canonical
  decomposition that belong to the blocks of diacritical marks used by the Latin, Greek and
  Cyrillic scripts: U+0300-U+036F (Combining Diacritical Marks),
  U+1AB0-U+1AFF (Extended), U+1DC0-U+1DFF (Supplement), U+20D0-U+20FF (for Symbols),
  U+FE20-U+FE2F (Half Marks) - in the name and in the typed text alike.
- **FR-002**: Combining marks outside those blocks MUST stay part of the comparison (as in 244).
- **FR-003**: The new mode MUST fold these letters, in either case, to the given letters:
  `ł` U+0142 / `Ł` U+0141 -> `l`; `ø` U+00F8 / `Ø` U+00D8 -> `o`; `đ` U+0111 / `Đ` U+0110 -> `d`;
  `ß` U+00DF / `ẞ` U+1E9E -> `ss`; `æ` U+00E6 / `Æ` U+00C6 -> `ae`; `œ` U+0153 / `Œ` U+0152 -> `oe`;
  `ı` U+0131 -> `i`. No other letter is folded. The folding applies to the name and to the typed
  text alike (typing `ß` finds `ss`, typing `ss` finds `ß`).
- **FR-004**: A match MUST start on a character boundary of the name and end on one or inside a
  letter folded by FR-003 (then the reported match covers that letter whole); combining marks that
  follow the last matched letter belong to the match.
- **FR-004a**: Left and Backspace in the new mode MUST remove the last letter together with the
  marks of FR-001 that follow it.
- **FR-005**: The focused item's match (its start, end and the caret) and the Right-arrow
  extension MUST keep working on whole characters of the original name.
- **FR-006**: With the option off, quick search MUST be the 0.1.10 rule, unchanged (saltests M1:
  0 differences; probe rows D09/D10 and the 244 probe's option-off run identical to the baseline).
- **FR-007**: An ASCII typed text against an ASCII name MUST keep the 244 byte-wise rule.
- **FR-008**: A typed text that, after dropping the marks, is empty MUST behave as a text of only
  wildcards (every name matches); a segment between wildcards that becomes empty is ignored.
- **FR-009**: Names with invalid UTF-8 bytes or WTF-8 lone surrogates MUST be handled without a
  crash or a read outside the name, as in 244.
- **FR-010**: The manual's quick search page MUST say that accents are ignored (with an example)
  in the new mode, and its remark on the option switched off MUST say that the earlier search does
  not ignore accents.
- **FR-011**: The decisions MUST be covered by saltests cases: each table letter, NFC and NFD names,
  masks with and without marks, a lone combining mark, a lone surrogate, the kept non-Latin marks,
  and the existing 244 cases adjusted only where the folding changes the answer.

### Key Entities

- **Key of a text**: the comparison form of a name or of a typed segment - per character, its
  canonical decomposition in lower case, without the marks of FR-001, with the letters of FR-003
  folded; each unit remembers the name's character it comes from.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every probe row D01-D08, D11 (Right on a decomposed name) and D12-D15 (folded
  letters typed one by one, Left and Backspace on a decomposed name) gives the expected names with the new build (the rows that
  differed before now match the item's examples).
- **SC-002**: With the option off, rows D09/D10 and the 244 probe's option-off run give the same
  result as before the change.
- **SC-003**: Over 100,000 names in a Release build, typing a character takes no longer than the
  244 measurement (<= 32 ms after the first keystroke); the first keystroke over non-ASCII names
  stays within 10 % of the baseline measured here (291 ms).
- **SC-004**: saltests passes with the new folding cases; the 0.1.10-rule comparison (M1) shows 0
  differences.
- **SC-005**: The feature 244 probe passes all its rows with the new build.

## Clarifications

### Session 2026-10-22

- Q: Restrict the dropping of marks to Latin, Greek and Cyrillic (the item leaves it to the spec)?
  → A: Yes - only the marks of the generic diacritical-mark blocks of FR-001 are dropped; marks of
  other scripts (Japanese voiced marks, Hebrew points, Arabic vowel signs, Indic signs, Thai) stay,
  because there they often tell letters or syllables apart (autonomous run: conservative).
- Q: Which letters does the table fold? → A: Exactly the item's list plus the capital sharp s
  `ẞ` (the same letter as `ß`); no further letters such as `ħ`, `ŧ`, `ð`, `þ` (autonomous run:
  item + conservative).
- Q: What does a typed text of combining marks only do? → A: The same as a text of only wildcards
  (every name matches), consistent with "marks are ignored" (autonomous run: conservative - no new
  rule, the existing wildcard-only behaviour).

## Assumptions

- Assumption (autonomous run): the 0.1.10 option-off rule (`SalNameEqualCI`, which keeps accents)
  is not changed; only the new mode folds.
- Assumption (autonomous run): no UI string is added or changed; the manual page (English HTML,
  not translated by the build) is edited directly.
- Assumption (autonomous run): highlighting the matched letters is out of scope (the maintainer's
  decision, "not now").
- The related item `quick-search-keys-skip-canonical-reordering-of-combining` is removed for the
  marks of FR-001 by this feature; for marks of other scripts it still applies and stays open.
- Q: Does the folding table apply to the typed text as well as to the names? → A: Yes, in both
  directions (autonomous run: item - the maintainer's decision "ignored symmetrically").
- Q: Should the manual say that the option-off search keeps accents? → A: Yes, one clause in the
  existing remark about the option (autonomous run: conservative - documents unchanged behaviour).
