# Feature Specification: Registry Editor Find - whole-word regexp, empty regexp, letters in quoted hex

**Feature Branch**: `257-regedt-find-words-hex`
**Created**: 2026-10-20
**Status**: Draft
**Input**: User description: "Backlog item regedit-find-whole-words-and-quoted-hex-letters - implement exactly what it describes." From backlog item regedit-find-whole-words-and-quoted-hex-letters.

## Background (measured at 2437c4dd)

The Registry Editor plug-in's Find window searches key names, value names and value data. Three
defects remain from the review of feature 190 (items 1-5 were fixed by 191 / 192):

1. **Whole words with a regular expression** - a text value that holds a list (REG_MULTI_SZ, or a
   text with line breaks) is searched line by line, but the characters before and after a match
   were read from the start of the whole value instead of the start of the matched line. On the
   second and later lines a whole word was missed, and a word fragment was reported as a whole
   word. Probe row WW-LINE2: regexp "bar" with Whole words found the list "a bcdef / xxbar" and
   missed the list "abcdefgh / foo bar".
2. **An empty regular expression** - the empty plain-text search finds every item; the empty
   regular expression went on as a pattern and, with Whole words, found nothing (probe row
   EMPTY-RX-WW: nothing instead of all 5 values; without Whole words it already found all).
3. **A quoted letter in a hex pattern** - in HEX mode, text between single quotes `'...'` is put
   into the pattern in the program's code page, one letter at a time into a one-byte space. A
   letter that takes two or more bytes in that code page (every non-ASCII letter with the UTF-8
   code page, the letters of the East Asian code pages) became a single 0x00 byte, so the search
   looked for other bytes than typed. With code page 1250 (this machine) the probe's quoted
   C-caron is one byte and is found - a control.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Whole-word regular expression on every line (Priority: P1)

A user searches the registry data with a regular expression and Whole words. A list value whose
second line is "foo bar" is found for "bar"; a list whose second line is "xxbar" is not.

**Why this priority**: wrong results both ways - a missed match and a false match.

**Independent Test**: probe row WW-LINE2 (hidden desktop).

**Acceptance Scenarios**:

1. **Given** a REG_MULTI_SZ value "abcdefgh", "foo bar", **When** the user searches the data for
   the regexp "bar" with Whole words, **Then** the value is found.
2. **Given** a REG_MULTI_SZ value "a bcdef", "xxbar", **When** the same search runs, **Then** the
   value is not found.
3. **Given** a REG_SZ "bar baz", **When** the same search runs, **Then** it is found (unchanged).

---

### User Story 2 - An empty regular expression finds everything (Priority: P2)

A user leaves the pattern empty with Regular expression checked. As with the empty plain text,
every item in the searched scope is found, with or without Whole words.

**Why this priority**: inconsistent with the plain-text mode; a NIT.

**Independent Test**: probe rows EMPTY-RX, EMPTY-RX-WW against the controls EMPTY-TXT, EMPTY-TXT-WW.

**Acceptance Scenarios**:

1. **Given** five values in the probe key, **When** the user searches with an empty regexp and
   Whole words, **Then** all five are found.
2. **Given** the same, **When** without Whole words, **Then** all five are found (unchanged).

---

### User Story 3 - A quoted letter in a hex pattern is the letter's bytes (Priority: P2)

A user searches in HEX mode with `'...'` text containing a letter that takes several bytes in the
program's code page. The pattern holds all bytes of that letter in the code page - the same bytes
the plain-text search uses for that letter - so binary data holding the text is found.

**Why this priority**: with a UTF-8 code page every non-ASCII quoted letter searched for a 0x00
byte.

**Independent Test**: `saltests` checks of the hex pattern rule with code pages 65001 (UTF-8),
932 (DBCS) and 1250 (single byte); probe rows HEX-CP and HEX-CP-BYTES with the machine's code page.

**Acceptance Scenarios**:

1. **Given** the code page 65001, **When** the pattern is `'<C-caron>AB'`, **Then** the pattern
   bytes are C4 8D 41 42.
2. **Given** the code page 1250, **When** the pattern is `01 '<C-caron>AB' 02`, **Then** the bytes
   are 01 E8 41 42 02 (unchanged).
3. **Given** a quoted text whose code-page bytes make the pattern longer than the search can
   keep, **When** the user starts the search, **Then** it is refused with the existing "too long"
   message, never cut.

### Edge Cases

- A quoted letter that the code page cannot represent: converted as the plain-text pattern
  converts it (the code page's replacement), unchanged from today for single-byte code pages.
- A letter outside the Basic Multilingual Plane (a surrogate pair) inside `'...'`: converted as
  one character, not as two halves.
- An unclosed `'` runs to the end of the pattern (unchanged).
- `"..."` text (UTF-16) and the hex digits are unchanged.
- A whole-word match at the start or end of a later line: the line's start / end count as word
  boundaries, as on the first line.
- A text value with CR LF line breaks: each line is judged by itself.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: With Regular expression and Whole words, the characters before and after a match
  MUST be taken from the line in which the match was found, on every line of the value.
- **FR-002**: An empty pattern with Regular expression MUST find every item the empty plain-text
  pattern finds, with or without Whole words.
- **FR-003**: In HEX mode, the text between single quotes MUST become all the bytes of its letters
  in the program's code page (the code page the plain-text search uses), converted as one text.
- **FR-004**: The length check of a HEX pattern (before the search starts) MUST count the same
  bytes FR-003 produces; a pattern that does not fit is refused with the existing message, never
  cut.
- **FR-005**: Everything else the Find window does (plain-text search, numbers, `"..."` text, hex
  digits, regexp without Whole words on the first line) MUST behave as before.
- **FR-006**: The hex pattern rule and the whole-word boundary rule MUST be checked by `saltests`
  without the GUI, including a multi-byte code page.

### Key Entities

- **Hex pattern**: hex digit pairs, `"..."` UTF-16 text, `'...'` code-page text, separated by spaces.
- **Line of a value**: a part of a text value between NULs or line breaks; regexp matches and their
  word boundaries live in one line.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe `find_words_hex_probe.ps1` goes from 7 PASS / 2 FAIL to 9 PASS / 0 FAIL
  (WW-LINE2 and EMPTY-RX-WW fixed, the controls unchanged), the program exits cleanly, the
  registry is restored identical.
- **SC-002**: `saltests` passes with new checks of the hex pattern bytes under code pages 65001,
  932 and 1250 and of the whole-word rule on a later line.
- **SC-003**: No other search result changes: the controls RX-BAR, EMPTY-TXT, EMPTY-TXT-WW,
  EMPTY-RX, HEX-CP, HEX-CP-BYTES pass before and after.

## Assumptions

- Assumption (autonomous run): `'...'` text uses the program's code page, not UTF-8 - the item's
  *Expected* names the code page first, the help documents only `"..."` (UTF-16) text, and the
  plain-text search's byte pattern uses the same code page (rule: the item).
- Assumption (autonomous run): what counts as a word boundary (a space character) is not changed;
  the help's mention of punctuation is a separate question, not this item.
- Assumption (autonomous run): an empty regexp is treated exactly as the empty plain-text pattern
  (it finds everything without running the regular expression).
- Assumption (autonomous run): the 2-byte case cannot be shown in the GUI on this machine (code
  page 1250, changing it needs a restart); it is proven by `saltests` with the code page as a
  parameter, and a person may confirm the probe's HEX rows on a machine with a UTF-8 code page.
