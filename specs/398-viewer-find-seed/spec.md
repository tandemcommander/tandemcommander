# Feature Specification: Viewer Find pre-fills the selection as the text the viewer shows

**Feature Branch**: `398-viewer-find-seed`
**Created**: 2026-11-02
**Status**: Draft
**Input**: User description: "Backlog item viewer-find-pre-fills-a-non-ascii-selection-as-code-page - implement exactly what it describes." From backlog item viewer-find-pre-fills-a-non-ascii-selection-as-code-page.

## Clarifications

### Session 2026-11-02

- Q: Should line breaks and tabs inside the selection be removed or changed in the pre-fill? → A: No - they are passed on as before; only the decoding and the whole-character shortening change (autonomous run: conservative)
- Q: Should an invalid UTF-8 byte in the selection stop the pre-fill or show as a replacement character? → A: It shows as U+FFFD, as the viewer draws it; only an incomplete character at the end of the bytes read is left out (autonomous run: conservative - the field shows what the viewer shows)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A selected non-ASCII word is pre-filled and found (Priority: P1)

A user views a UTF-8 text file in the internal viewer, selects a word with accented letters (for
example `café`) and opens Find. The Find field shows `café` exactly as the viewer shows it, and OK
finds that word in the file.

**Why this priority**: This is the defect: today the field shows `cafĂ©` (code-page mojibake) and
the search answers "Cannot find the string".

**Independent Test**: Hidden-desktop probe: UTF-8 file `café`, Alt+F3, Select All, Find - the field
holds U+0063 U+0061 U+0066 U+00E9; OK asks nothing; Find opened again pre-fills the found text
`café`.

**Acceptance Scenarios**:

1. **Given** a UTF-8 file holding `café` and the whole text selected, **When** Find opens,
   **Then** the field shows `café` (4 characters).
2. **Given** that pre-filled field, **When** the user clicks OK, **Then** the viewer selects the
   found `café` without any message.

---

### User Story 2 - A long selection is shortened at a whole character, not refused (Priority: P1)

A user selects more text than the Find field holds (for example 199 `a` followed by `é…`, or 70
CJK letters) and opens Find. The field shows the longest beginning of the selection that the field
and its search buffer take, ending at a whole character; OK searches it without "The path
specified is too long.".

**Why this priority**: Since feature 311 such a selection is refused at OK although the user typed
nothing.

**Independent Test**: Probe rows with 199 `a` + `é…` (pre-fill 199 `a`), 70 CJK letters (pre-fill
the first 66 letters = 198 bytes), 198 `a` + U+1F600 + `b` (pre-fill 198 `a`): OK asks nothing and
the found text equals the pre-fill.

**Acceptance Scenarios**:

1. **Given** a selection whose text is longer than 200 UTF-16 units or 200 UTF-8 bytes, **When**
   Find opens, **Then** the field holds the longest whole-character beginning that fits both.
2. **Given** that field, **When** OK is clicked, **Then** no "too long" message appears and the
   text is found.

---

### User Story 3 - Code-page files and hex mode keep their behaviour (Priority: P2)

A user viewing a file shown in a code page (no Unicode detected) selects text and opens Find: the
field shows the text as the viewer shows it (as before). With Hex ticked, the field shows the
selection's bytes as hex digits (as before).

**Why this priority**: Regression guard.

**Independent Test**: Probe rows `legacy` (code-page 1250 file `café`: field `café`) and `hex`
(UTF-8 `café` with Hex: field `63 61 66 C3 A9`).

**Acceptance Scenarios**:

1. **Given** a code-page file `café` selected, **When** Find opens, **Then** the field shows `café`.
2. **Given** Hex ticked and the UTF-8 `café` selected, **When** Find opens, **Then** the field is
   `63 61 66 C3 A9`.

### Edge Cases

- A selection longer than what is read, with the read limit inside a multi-byte character: the
  partial character is left out, never shown as a replacement character.
- A selection whose own last character is incomplete (e.g. a file ending in a lone byte E9 that the
  viewer's detection still takes for UTF-8): the character is U+FFFD, as the viewer draws it
  (measured in run 1 of the probe: dropping it pre-filled `caf`, row `u8-tail`).
- A UTF-8 file with a byte that is not valid UTF-8 inside the selection: shown as U+FFFD, as the
  viewer draws it (the search then does not find it - such a byte cannot be typed either).
- A character beyond the BMP (a surrogate pair) at the limit: both units are kept or both left out.
- A NUL byte (or NUL unit) in the selection: the pre-fill ends before it (as before: the field
  cannot hold a NUL).
- A selection starting at the file's BOM: the BOM is decoded as U+FEFF (the viewer draws it as an
  invisible character); the search then matches the file's bytes.
- UTF-16 content: decoded by its byte order, an odd trailing byte left out (the viewer does not
  detect UTF-16 into a wide mode at HEAD; the rule is there for when it does).
- A code page with double-byte characters (the ANSI code page of an East Asian system): a lead byte
  at the end of the read is left out.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The pre-fill MUST decode the selected bytes by the viewer's current content encoding:
  UTF-8 as UTF-8, UTF-16 LE / BE by their byte order, otherwise the ANSI code page (the bytes as
  the viewer shows them, after its conversion table).
- **FR-002**: The pre-fill MUST set the field as wide (UTF-16) text.
- **FR-003**: The pre-filled text MUST hold at most 200 UTF-16 units (the field's limit) and its
  UTF-8 form at most 200 bytes (what OK accepts, feature 311); a longer selection MUST be shortened
  to the longest beginning that fits, ending at a whole character (never half a surrogate pair,
  never part of a multi-byte sequence).
- **FR-004**: An incomplete character at the end of the bytes read MUST be left out when more of the
  selection follows, and MUST be U+FFFD when the selection ends there.
- **FR-005**: Hex mode MUST keep building the field from the selection's first bytes as hex digits
  exactly as before.
- **FR-006**: When there is no selection, or the selection cannot be read, the field MUST keep the
  text it had (as before).
- **FR-008**: Characters other than NUL (line breaks, tabs) MUST be passed on as before.
- **FR-007**: The decision (decode + shorten) MUST be a pure rule with unit checks.

### Key Entities

- **Seed**: the suggested search text built from the selection - a whole-character beginning of the
  decoded selection that fits the field and the search buffer.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe's four failing rows (u8-word, u8-long, u8-cjk, u8-astral) pass: the field
  shows the expected text and OK finds it without a message.
- **SC-002**: The probe's control rows (legacy field, hex) still pass.
- **SC-003**: The unit checks of the rule pass, and a negative control (the old byte-wise pre-fill)
  fails them.

## Assumptions

- Assumption (autonomous run): the field limits are the existing ones - 200 UTF-16 units
  (`CB_LIMITTEXT`) and 200 UTF-8 bytes (`DlgItemTextFitsU8(..., FIND_TEXT_LEN)`); the seed fits
  both, so OK never refuses a text the user did not type.
- Assumption (autonomous run): a code-page file's non-ASCII seed is shown correctly but the search
  still does not find it, because the search compares the field's UTF-8 bytes with the file's
  code-page bytes (measured at 58dcca07, probe row `legacy`). Changing the search engine is outside
  this item; the part of *Expected* "a selected non-ASCII word is found" is reached for UTF-8
  content and recorded as a deviation for code-page (and future UTF-16) content, with an Inbox item
  (stop-rules §2.14).
- Assumption (autonomous run): the internal viewer's Find is the only consumer of
  `CViewerWindow::GetFindText`; the DB Viewer plug-in has its own copy (not part of this item).
- No new UI string, dialog or setting; no translations change.
