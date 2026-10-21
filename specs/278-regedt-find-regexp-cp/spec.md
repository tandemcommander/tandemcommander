# Feature Specification: Registry Editor Find - a regexp searches the whole code-page text

**Feature Branch**: `278-regedt-find-regexp-cp`
**Created**: 2026-10-21
**Status**: Draft
**Input**: User description: "Backlog item regedit-find-regexp-multibyte-code-page-buffer - implement exactly what it describes." From backlog item regedit-find-regexp-multibyte-code-page-buffer.

## Background (measured at cffe5eca)

The Registry Editor plug-in's Find window can search key names, value names and text data with a
**Regular expression**. The regular expression works on the program's code page (the Windows
ANSI code page), so each text is converted to that code page before it is searched. The
conversion space and the length searched were both the text's count of UTF-16 units. On a
machine whose ANSI code page is multi-byte (UTF-8 65001, or the East Asian 932 / 936 / 949 / 950),
a text's code-page form can be longer than that count:

- when the conversion space is too small, the conversion fails and whatever bytes were left in the
  space (an earlier text, or a partial conversion) are searched instead of the text;
- when the space happens to be large enough (it is reused and only grows), the conversion
  succeeds, but only the first "unit count" bytes are searched - the end of the text never is.

Measured with the real conversion call (python ctypes, `WideCharToMultiByte`): code page 65001,
`čččč bar` is 8 units but 12 bytes; converted into 8 bytes the call fails (returns 0) and leaves
`č` x4 in the space; into a larger space it gives 12 bytes, of which 8 were searched. Either way
the regexp `bar` finds nothing. Code pages 932 and 1250 give 8 bytes: `bar` is found. The
measuring machine's code page is 1250, so the GUI symptom cannot be shown here.

## Clarifications

### Session 2026-10-21

- Q: Is the text converted with the program's ANSI code page or as UTF-8? → A: the ANSI code page (`CP_ACP`), as the regexp pattern is converted; only the size and the length change (autonomous run: item)
- Q: What does the search do with a text whose conversion fails outright? → A: it is no match, without a message; the search goes on with the next item (autonomous run: conservative)
- Q: Is anything besides the regexp branch's conversion changed (plain-text or hex search, the shared `WStrToStr`, the pattern conversion)? → A: no - only the regexp branch of the test; `WStrToStr` and its other callers stay (autonomous run: conservative)
- Q: How is the GUI case on a multi-byte code page confirmed? → A: by a person on a machine with a UTF-8 ANSI code page, recorded as a `person-step` item; the run proves the rule in `saltests` (autonomous run: item)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A regexp finds text at the end of a non-ASCII value (Priority: P1)

A user on a machine with a multi-byte ANSI code page (for example the "Beta: Use Unicode UTF-8"
option of Windows) searches the registry with a regular expression. A value, value name or key
name `čččč bar` is found for the regexp `bar`, with or without Whole words, exactly as on a
single-byte code page.

**Why this priority**: the search silently misses matches (or, on stale bytes, could report a
match the text does not hold) - the only defect the item names.

**Independent Test**: `saltests` checks with the code page as a parameter: the conversion rule
converts `čččč bar` under 65001 into 12 bytes that hold `bar` at its end; a too small space is
refused, never searched.

**Acceptance Scenarios**:

1. **Given** code page 65001 and the text `čččč bar`, **When** the text is prepared for the
   regexp, **Then** the prepared text is 12 bytes long and ends with `bar`.
2. **Given** code page 932 and a text of Japanese letters followed by ` bar`, **When** prepared,
   **Then** its length is the code page's byte count and it ends with `bar`.
3. **Given** code page 1250 and `čččč bar`, **When** prepared, **Then** it is 8 bytes (unchanged
   behaviour of single-byte code pages).
4. **Given** a text whose conversion fails, **When** the search tests it, **Then** the text is
   not searched as leftover bytes - it is not a match.

### Edge Cases

- An empty text (or a text value of only NULs): nothing to convert; unchanged behaviour (the
  line loop sees zero length).
- A lone surrogate in a value: the conversion substitutes the code page's replacement and goes
  on; the text is searched in that form (unchanged; not a failure).
- A text the code page cannot represent (č under 932): the replacement character `?`, as before.
- The conversion space is reused between texts and only grows: a later, shorter text is searched
  only up to its own byte count.
- Non-text data (REG_DWORD, REG_BINARY, ...) searched with a regexp: searched as raw bytes,
  unchanged.
- Out of memory for the conversion space: the text is not a match (unchanged: a trace, FALSE).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Before a text (a key name, a value name, or REG_SZ / REG_EXPAND_SZ / REG_MULTI_SZ
  data) is searched with a regular expression, its byte count in the program's code page MUST be
  computed first, and the conversion space MUST hold at least that many bytes.
- **FR-002**: The searched length MUST be the converted byte count, not the UTF-16 unit count.
- **FR-003**: A conversion that fails, or whose result is not the counted length, MUST NOT be
  searched; such a text is no match.
- **FR-004**: The conversion rule MUST be a pure, testable rule taking the code page as a
  parameter, with `saltests` checks under 65001, 932 and 1250, including a negative control that
  shows the old sizing loses `bar`.
- **FR-005**: Every other part of the search (plain text, hex, whole-word rule, the trailing-NUL
  trimming of feature 189, non-text data) MUST keep its current behaviour.

### Key Entities

- **Prepared text**: the code-page bytes of one name or text value and their count - what the
  regular expression is run against, line by line.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Under code page 65001, the prepared form of `čččč bar` is 12 bytes and contains
  `bar` (it was: 8 bytes searched, `bar` absent).
- **SC-002**: 0 cases where leftover bytes of the conversion space are searched in place of a
  text (a failed conversion is no match).
- **SC-003**: Single-byte code pages give the same searched bytes as before (1250: 8 bytes for
  `čččč bar`).
- **SC-004**: All existing `saltests` checks still pass; the encoding guard and build stay green.

## Assumptions

- Assumption (autonomous run): the regexp keeps working on the program's ANSI code page (the
  pattern is converted with the same code page, features 191 / 257) - switching the regexp to
  UTF-8 is not part of this item.
- Assumption (autonomous run): the GUI case on a machine with a multi-byte ANSI code page cannot
  be driven here (the measuring machine runs code page 1250); it is owed to a person as a
  `person-step` item (the item's `who: both`).
- Assumption (autonomous run): a text whose conversion fails outright is treated as no match
  without a message (conservative: the search goes on; the plain-text search has no message for
  a single item either).
