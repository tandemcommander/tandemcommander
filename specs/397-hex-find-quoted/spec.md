# Feature Specification: Hex mode in Find keeps quoted letters outside the code page

**Feature Branch**: `397-hex-find-quoted`
**Created**: 2026-11-02
**Status**: Draft
**Input**: User description: "Backlog item hex-mode-in-find-turns-quoted-letters-outside-the-code-page - implement exactly what it describes." From backlog item hex-mode-in-find-turns-quoted-letters-outside-the-code-page.

## Background

With *Hex* ticked, the Find dialog's *Containing* field and the internal viewer's *Find* field take
hexadecimal bytes and quoted text (`"abc" 0D 0A`). While the user types, the program tidies the
field after every change: it drops leading spaces, folds double spaces, puts a space between every
two hex digits and around a quoted part, and keeps the caret where the user is typing. That tidying
reads and writes the field through the system code page, so a quoted letter the code page does not
have (Chinese, Japanese, Greek on a Czech system, …) becomes `?` at the first key the user presses;
the search then looks for the byte `?`. Measured at `223d5a8e` (probe `hex397_probe.ps1`, hidden
desktop, ACP 1250):

| Row | Typed | Field after typing (before) | Search (before) |
|---|---|---|---|
| `grep-type` | Find, `"` + 5 CJK + `"`, then `41` | `"?????" 41` | found the 2 decoy files holding `?????A`, not `hit.txt` |
| `grep-mid` | `a` typed inside the quotes | `"???a??" 41` | - |
| `view-type` | viewer's Find, the same | `"?????" 41` | "Cannot find the string" |
| `grep-group` | `41424` (ASCII only) | `41 42 4`, caret 7 (right) | - |

The text the program searches for is already taken from the field as UTF-8, and quoted parts are
already searched as their bytes; only the tidying loses the letters.

## Clarifications

### Session 2026-11-02

- Q: How long may the tidied text grow when the tidying inserts spaces? → A: as today, up to the field's own limit (200 UTF-16 units); the tidying never shortens or cuts the text; a text whose UTF-8 form does not fit the program's buffer is refused at OK by feature 311's rule, not cut (autonomous run: item - its *Notes* "refuses rather than cuts"; rule - CLAUDE.md "a path or name is never cut")
- Q: Should a surrogate pair (a letter outside the Basic Multilingual Plane) typed outside quotes be split by the hex-digit grouping? → A: no - a space is never inserted between the two halves of a pair; such a text stays invalid hex and is refused at OK as today (autonomous run: rule - "cut at a whole character")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Find searches for quoted letters as typed (Priority: P1)

A user searches files for a byte sequence that includes text in a script their system code page
does not have: in Find they tick *Search file content* and *Hex*, type `"` + Chinese letters + `"`
followed by hex bytes, and press Find.

**Why this priority**: it is the defect: today the letters turn into `?` and Find returns files that
do not contain the text while missing the ones that do.

**Independent Test**: the probe row `grep-type`: the field keeps the letters while typing, Find finds
exactly `hit.txt`.

**Acceptance Scenarios**:

1. **Given** Find in hex mode with `"` + 5 CJK letters + `"` in Containing, **When** the user types
   `4` `1` at the end, **Then** the field shows `"` + the 5 letters + `" 41` and the caret is at the
   end.
2. **Given** that field, **When** the user presses Find, **Then** the files containing the UTF-8
   bytes of the letters followed by `A` are found, and files containing `?????A` are not.
3. **Given** the caret inside the quoted letters, **When** the user types a letter, **Then** it is
   inserted there, the other letters stay, and the caret is right after the typed letter.

### User Story 2 - The viewer's Find does the same (Priority: P1)

In the internal viewer, Find with *Hex* ticked takes the same quoted text and finds it in the file.

**Independent Test**: probe row `view-type`: the field keeps the letters, the viewer finds and
selects the bytes.

**Acceptance Scenarios**:

1. **Given** the viewer's Find in hex mode, **When** the user types the quoted letters and `41` and
   presses OK, **Then** the viewer finds the text (no "Cannot find" message) and selects it.

### User Story 3 - The tidying of hex input stays as it is (Priority: P2)

Users typing plain hex digits keep the existing help: spaces between every two digits, leading and
double spaces removed, a space around quoted parts, the caret kept where they type.

**Independent Test**: probe row `grep-group` and the unit checks of the tidying rule.

**Acceptance Scenarios**:

1. **Given** an empty Containing field in hex mode, **When** the user types `41424`, **Then** the
   field is `41 42 4` and the caret is at 7.

### Edge Cases

- Leading spaces, double spaces outside quotes, a quote glued to a hex digit (`41"a"`, `"a"41`):
  tidied as before, the caret moved by the same amounts as before.
- A field at its length limit: no space is inserted (as before); nothing is cut.
- A letter outside the Basic Multilingual Plane (two UTF-16 units) inside quotes: kept whole; outside
  quotes: never split by an inserted space.
- A text whose UTF-8 form is longer than the program's buffer: refused at OK with the existing
  message (feature 311), not cut by the tidying.
- Regular-expression mode or hex off: the tidying does not run (unchanged).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The tidying of a hex-mode field MUST read and write the whole field text without
  passing it through the system code page, in both the Find dialog's Containing field and the
  viewer's Find field.
- **FR-002**: The tidying MUST produce for every text the same result and the same caret movement as
  before for characters the code page has (spaces, quotes and hex grouping work on characters, not
  bytes).
- **FR-003**: The caret and selection MUST be kept in the units the field uses, so that it stays where
  the user typed also after letters that take more than one byte.
- **FR-004**: The tidying MUST never shorten the text: it only inserts spaces while the text stays
  within the field's limit, and removes only the spaces it folds today.
- **FR-005**: An inserted space MUST NOT split a surrogate pair.
- **FR-006**: Quoted letters MUST be searched as their UTF-8 bytes (the existing conversion, unchanged).
- **FR-007**: The tidying rule MUST be a pure function covered by unit checks (`saltests`), including
  the before-behaviour for ASCII input and the caret arithmetic.

### Key Entities

- **Hex field text**: the field's characters; outside quotes hex digits and spaces, inside quotes any
  text; the caret/selection as a start and end position in the field's units.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe `hex397_probe.ps1`: the rows `grep-type`, `grep-mid`, `view-type` go from FAIL to
  PASS; `grep-group` stays PASS.
- **SC-002**: Unit checks of the tidying rule pass, and with the old code-page behaviour simulated
  (a negative control) the rows for letters outside the code page fail.
- **SC-003**: Feature 311's probe (`grep311_probe.ps1`) keeps its result (26 PASS / 0 FAIL).

## Assumptions

- Assumption (autonomous run): the internal viewer's pre-fill of its Find field from a selection
  (an ANSI `WM_SETTEXT`, Inbox item `viewer-find-pre-fills-a-non-ascii-selection-as-code-page`) is
  out of scope; in hex mode it writes only ASCII hex digits.
- Assumption (autonomous run): the error selection of `HistoryComboBox` for a non-hex character
  (a byte offset of the UTF-8 text used as a field position) is not part of this item; it is checked
  and, if it is a defect, recorded as an Inbox item.
- Typing is driven in the probe by `WM_CHAR` to the field's edit, which runs the same change
  notification as a key press; a real keyboard (IME composition) is owed to a person only if the
  review asks for it.
