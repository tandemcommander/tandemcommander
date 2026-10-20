# Feature Specification: Renamer regular expressions work on whole letters of UTF-8 names

**Feature Branch**: `254-renamer-regex-letters`
**Created**: 2026-10-20
**Status**: Draft
**Input**: Backlog item `renamer-regex-single-byte-classes` - "Renamer: regular expressions judge \b,
\w, classes and '.' by single bytes". From backlog item renamer-regex-single-byte-classes.

## Background (measured at 3ea24ab5)

The Batch Renamer (Ctrl+Shift+R) can search and replace inside names with a regular expression.
Names are UTF-8, so one letter outside ASCII takes two to four bytes. Feature 210 made the
case-insensitive search fold whole letters. The expression engine still steps, classifies and
counts **bytes**. The probe `ren_regex_probe.ps1` (feature 210's driver, hidden desktop, ACP 1250)
on the current build: 18 rows, 16 FAIL, the 2 ASCII controls PASS.

1. **Refused "(123) the name is incorrect", nothing renamed** — the expression matched part of a
   letter, so the new name was not valid UTF-8: `^.` on "žluť.txt"; `^\w+` on "Жаба.txt"; `[ž]`;
   `^[^l]`; `^[à-ž]`; `^[[:alpha:]]+` on "Жаба"; `^\w+` on "Café" (with a combining accent) and on
   two CJK letters outside the BMP; case-insensitive `^[ž]` on "Žluť"; a global `l*` (an empty
   match after "ž" stepped one byte into the next letter).
2. **A wrong name written** — `а\b` (Cyrillic а) → "A" on "Жаба.txt" replaced the *first* а,
   because the engine took a byte of б for a letter and a byte of а for a non-letter. The user got
   "ЖAба.txt" instead of "ЖабA.txt".
3. **A match missed** — `^ž+` on "žžluť" replaced one ž of the run (the `+` repeated the last byte
   only); `(?<=^.)l` found nothing (the look-behind stepped back one byte); case-insensitive
   `\xC5\xBD` (the bytes of Ž) found nothing (the name is folded, the escape is not); case-insensitive
   "Σ" did not match the final sigma "ς", with or without regular expressions.

Also in the item: the Search / Replace / New name **history** treats two entries as one through the
code page's byte fold (`StrICmp`). With cp1250 the patterns "Ċ" and "Ě" are one entry, so the older
one is dropped. This is shown by reading the code; nothing is renamed by it. The **preview's sort**,
also named in the item, already compares non-ASCII names by whole letters (the core's
`RegSetStrICmp` goes through its UTF-8 name comparison, feature 004). It is not changed here.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An expression never splits a letter (Priority: P1)

A user types an expression with `.`, a bracket class (`[ž]`, `[^l]`, `[à-ž]`), `\w` / `\d` / `\s`
(or their negations), a POSIX class (`[[:alpha:]]`), or a quantifier after a non-ASCII letter
(`ž+`, `ж*`). They rename files whose names hold non-ASCII letters. Each of these consumes whole
letters. The preview shows a valid new name and the rename succeeds.

**Why this priority**: today such renames are refused for the whole run. That is the most common
symptom.

**Independent Test**: probe rows dot, w-cyr, class, negclass, range, quant, posix, mark, nonbmp,
ci-class, empty — each renames to the expected name.

**Acceptance Scenarios**:

1. **Given** "žluť.txt", **When** `^.` → "X", **Then** the file becomes "Xluť.txt".
2. **Given** "Жаба.txt", **When** `^\w+` → "W", **Then** "W.txt".
3. **Given** "žluť.txt", **When** `[ž]` → "z", **Then** "zluť.txt"; `^[^l]` → "N" gives "Nluť.txt";
   `^[à-ž]` → "R" gives "Rluť.txt".
4. **Given** "žžluť.txt", **When** `^ž+` → "Z", **Then** "Zluť.txt" (the whole run).
5. **Given** "Café x.txt" written with a combining accent, **When** `^\w+` → "W", **Then** "W x.txt".
6. **Given** a name starting with two CJK letters outside the BMP and " x.txt", **When** `^\w+` →
   "W", **Then** "W x.txt".
7. **Given** "žl.txt", Global and Exclude extension, **When** `l*` → "-", **Then** "-ž-.txt".

---

### User Story 2 - Word boundaries and look-behind judge letters (Priority: P1)

`\b`, `\B` and a look-behind decide by the letter before and after the position. They never decide
by a byte inside a letter.

**Why this priority**: a wrong `\b` decision writes a wrong name without any warning.

**Independent Test**: probe rows wordb, lookb.

**Acceptance Scenarios**:

1. **Given** "Жаба.txt", **When** `а\b` → "A", **Then** "ЖабA.txt" (the last а, before the dot).
2. **Given** "žluť.txt", **When** `(?<=^.)l` → "L", **Then** "žLuť.txt".

---

### User Story 3 - Case-insensitive matching of escapes and the final sigma (Priority: P2)

A case-insensitive expression finds a letter written as `\x` escapes of its UTF-8 bytes in either
case. "Σ", "σ" and "ς" are one letter for a case-insensitive search, with or without regular
expressions.

**Why this priority**: today the match is only missed; nothing wrong is written.

**Independent Test**: probe rows esc, sigma, bm-sigma.

**Acceptance Scenarios**:

1. **Given** "žluť.txt", case-insensitive, **When** `\xC5\xBD` → "Z", **Then** "Zluť.txt".
2. **Given** "λόγος.txt", case-insensitive, **When** "Σ" → "s" (expression or plain search),
   **Then** "λόγοs.txt".

---

### User Story 4 - The histories keep entries that differ in a letter (Priority: P3)

The Search, Replace and New name histories treat two entries as the same only when they differ just
in the case of whole letters. They never merge entries because of a byte fold.

**Independent Test**: by reading. The comparison is the shared name rule, already covered by
saltests.

**Acceptance Scenarios**:

1. **Given** the history holds "Ċ", **When** the user runs with "Ě", **Then** both stay in the
   history. Running again with "ċ" moves the "Ċ" entry to the top instead of adding a second one.

### Edge Cases

- ASCII-only expressions on ASCII names behave exactly as before (probe controls asc-wb, asc-dot).
- Bytes in a name that are not valid UTF-8 (legacy names) are one "letter" each. They are never
  merged with their neighbours. A WTF-8 lone surrogate (three bytes) is one letter.
- A `\x` escape sequence that does not form a whole character matches only the same invalid bytes
  in a name. It never matches part of a valid letter.
- A bracket range with non-ASCII bounds is a range of code points. A range with a reversed order
  (end before start) matches nothing, as before for ASCII.
- A case-insensitive class or range compares the lower-case forms (feature 210's same-length fold
  of the name and the pattern). A letter whose two cases differ in UTF-8 length stays
  case-sensitive, as in 210.
- An empty match steps over a whole letter before the next attempt.
- The `(?<=...)` width must still be fixed. It is counted in letters, so `(?<=.)` and `(?<=ž)` are
  both one letter.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `.` (with or without the single-line option) MUST match exactly one whole letter.
- **FR-002**: Bracket classes, their negations, `\w \W \d \D \s \S` and the POSIX classes MUST
  match exactly one whole letter. A non-ASCII letter is judged by its Unicode properties: letters,
  digits, spaces, punctuation, upper / lower case. `\w` also includes combining marks and `_`.
- **FR-003**: A non-ASCII literal letter followed by `*`, `+` or `?` MUST be repeated as a whole
  letter.
- **FR-004**: `*`, `+`, `?` and their ungreedy forms after `.` or a class MUST give back whole
  letters when they backtrack.
- **FR-005**: `\b` and `\B` MUST judge the whole letter before and after the position.
- **FR-006**: A look-behind MUST step back by whole letters. Its fixed width is counted in letters.
- **FR-007**: Consecutive `\xHH` escapes that form one valid UTF-8 character MUST be one letter. A
  case-insensitive expression MUST fold it like a typed letter. Escapes that form no whole
  character MUST match only the same bytes standing alone in the name, never part of a letter.
- **FR-008**: A bracket range with a non-ASCII bound MUST be a range of code points.
- **FR-009**: The search MUST start only at letter boundaries. A replacement after an empty match
  MUST move on by a whole letter.
- **FR-010**: A case-insensitive search (expression and plain) MUST treat the final sigma "ς" as
  "σ".
- **FR-011**: The Search / Replace / New name histories MUST decide "already in the history" by
  whole letters (the shared case-insensitive name rule), not by the code page's byte fold.
- **FR-012**: An expression made only of ASCII, on an ASCII name, MUST give the same result as
  before. This covers the error codes for invalid expressions and the meaning of every option.
- **FR-013**: The rules that decide letter boundaries, stepping and classification MUST live in a
  shared header with saltests checks.

### Key Entities

- **Letter (unit)**: a valid UTF-8 character (1–4 bytes), a WTF-8 encoded lone surrogate (3
  bytes), or a single byte that is not part of either.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 18 probe rows pass (before: 16 fail), including the 2 ASCII controls.
- **SC-002**: None of the probe's expressions is refused "(123)" for a non-ASCII name.
- **SC-003**: The regression probes of the Renamer (210's 16 rows, 199, 196, 206, 207, 208, 209)
  still pass.
- **SC-004**: saltests cover the letter rules (boundaries, stepping forward and back, invalid bytes,
  surrogates, classification, final sigma) with 0 failures.

## Assumptions

- Assumption (autonomous run): non-BMP letters are classified by the system's Unicode library
  (`icu.dll`, part of Windows 10 1903+ and therefore of every supported Windows 11). It is loaded
  from System32 at first use. If it cannot be loaded, a non-BMP character belongs to no class. It
  still is one whole letter for `.` and negated classes. This changes nothing that is stored or
  sent.
- Assumption (autonomous run): BMP characters are classified by the Windows character types
  (`GetStringTypeW`) — the same C1 types the engine's POSIX classes are defined by. Combining marks
  are the "nonspacing" type.
- Assumption (autonomous run): the preview sort is not changed. It already compares by whole
  letters (measured by reading at 3ea24ab5).
- Assumption (autonomous run): the final-sigma fold goes into feature 210's shared fold, so the
  plain search and the expression search agree. "ς" and "σ" have the same UTF-8 length, so 210's
  rules (same length, offsets kept) still hold.
- The engine's syntax, error messages and options stay the same. No UI string is added or removed.
- Out of scope: the 259-byte limit of a new name (`renamer-long-new-name-limits`), Unicode case
  folding of letters whose two cases differ in UTF-8 length, and canonical equivalence (a
  precomposed "é" does not match "e" + combining accent).
