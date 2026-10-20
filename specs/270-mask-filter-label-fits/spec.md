# Feature Specification: typed masks, filter, volume label and hot path name are never cut to the program's buffer

**Feature Branch**: `270-mask-filter-label-fits`
**Created**: 2026-10-20
**Status**: Draft
**Input**: Backlog item more-typed-fields-cut-to-their-buffer-masks-filter-volume (backlog/items/more-typed-fields-cut-to-their-buffer-masks-filter-volume/desc.md) - implement exactly what it describes. From backlog item more-typed-fields-cut-to-their-buffer-masks-filter-volume.

## Background

Feature 251 made the fields of Make File List, the user menu, viewers / editors, hot paths, the
drives page and Edit New refuse text whose UTF-8 form does not fit the program's buffer ("The path
specified is too long.") instead of cutting it at a whole character. Five more fields keep the cut:
a field limits its text in UTF-16 units (259), the program reads it into a 260-byte UTF-8 buffer,
so text of 87-259 CJK letters is shortened silently and the shorter text is acted upon or stored.

Measured at 11e20a84 (hidden-desktop probe `mask270_probe.ps1`, M = 86 CJK letters = 258 bytes):
- Select and Unselect with the mask `M*Q` (260 bytes) closed without a word; the next Select showed
  `M*` - the cut mask, which also matches the file `M.txt` the typed mask does not;
- Convert with `M*Q` and CRLF line ends **converted the focused `M.txt`** (LF -> CRLF) although the
  typed mask does not match it; the history held `M*`;
- Change Filter stored `M*` - with "Use filter" and with "Don't use filter" (masks string, history);
- Drive Information called the volume-label write with a label of 129 of the 140 typed letters
  (it failed only because the probe is not elevated; no Windows file system takes a label of 86 or
  more characters, so a cut label is never applied - but the write is attempted with another text);
- the hot path list's in-place label edit (F2) stored 86 of 100 typed letters as the slot's name;
  OK closed the page without a word.
Controls (text that fits, 259 bytes + NUL) are accepted and kept whole.

## Clarifications

### Session 2026-10-20

- Q: The volume label: refuse with the program's "too long" message, or apply the file system's own label limit? → A: refuse with "The path specified is too long." when the typed label does not fit the 260-byte buffer, before any write; a label that fits keeps the existing behaviour (the file system's own refusal is shown as before) (autonomous run: item - its *Expected* names this refusal; conservative - no new string, no new limit)
- Q: The filter dialog with "Don't use filter": is a text that does not fit refused too? → A: yes - the text is stored (the masks string and the filter history) even when the filter is not used, and nothing cut may be stored (autonomous run: item - "no cut ... filter ... is used or stored")
- Q: The hot path label edit: refuse at Enter, or keep the whole name and refuse at the page's OK? → A: keep the whole name in the slot; the page's existing check refuses it at OK / leaving the page, the slot selected and the name field marked (autonomous run: item - its *Expected* chooses this)
- Q: Grow the filter buffer (its masks string holds 1,001 bytes) instead of refusing? → A: no - refuse at the existing 260-byte read, as every other mask field; the stored sizes and the registry stay as they are (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A mask never selects or converts other files (Priority: P1)

A user types a Select, Unselect or Convert mask whose UTF-8 form is longer than 259 bytes. The
program refuses it with "The path specified is too long.", the dialog stays open with the whole
text in the field; nothing is selected, unselected or converted, nothing cut enters the history.

**Why this priority**: a cut Select mask selects other files, which a following Delete or Move acts
on; a cut Convert mask rewrites other files - user data.

**Independent Test**: probe rows `sel-mask`, `unsel-mask`, `conv-mask` (refused, `M.txt` unchanged)
and the controls `sel-ctl`, `conv-ctl`.

**Acceptance Scenarios**:

1. **Given** the Select (or Unselect) dialog and a mask of more than 259 UTF-8 bytes, **When** OK is
   pressed, **Then** "The path specified is too long." is shown, the dialog stays open and the field
   holds the whole typed mask.
2. **Given** Convert with a mask of more than 259 bytes and a line-end conversion, **When** OK is
   pressed, **Then** the same refusal; no file is converted.
3. **Given** a mask of exactly 259 bytes, **When** OK is pressed, **Then** it is accepted and used
   whole, as before.

---

### User Story 2 - A filter is never cut (Priority: P2)

A user types a panel filter that does not fit. The program refuses it, with "Use filter" and with
"Don't use filter"; the panel's filter and the history stay as they were.

**Why this priority**: a cut filter shows other files; a workaround exists (a shorter filter).

**Independent Test**: probe rows `flt`, `flt-unused`, control `flt-ctl`.

**Acceptance Scenarios**:

1. **Given** Change Filter, "Use filter" and a filter of more than 259 bytes, **When** OK is pressed,
   **Then** the refusal; the dialog stays open, the field whole.
2. **Given** "Don't use filter" and such a text in the field, **When** OK is pressed, **Then** the
   same refusal.
3. **Given** a filter of 259 bytes, **Then** accepted and stored whole.

---

### User Story 3 - A volume label is never written cut (Priority: P3)

A user types a volume label that does not fit in Drive Information. The program refuses it as too
long before any write.

**Independent Test**: probe row `vol` (driven only when not elevated, so the label cannot change).

**Acceptance Scenarios**:

1. **Given** a label of more than 259 UTF-8 bytes, **When** OK is pressed, **Then** "The path
   specified is too long." is shown, the dialog stays open, no label is written.
2. **Given** a label that fits, **Then** the existing behaviour (write, or the file system's error).

---

### User Story 4 - A hot path name typed with F2 is never stored cut (Priority: P2)

A user renames a hot path in place (F2 on the row) with a name of more than 259 bytes and presses
Enter. The slot keeps the whole name; OK refuses it ("The path specified is too long."), the slot
selected and its name field shown whole.

**Independent Test**: probe rows `hp-label`, control `hp-label-ctl`.

**Acceptance Scenarios**:

1. **Given** F2 on a hot path row, 100 CJK letters, Enter, **When** OK is pressed, **Then** the
   refusal; the page stays, the name field holds the 100 letters.
2. **Given** 86 CJK letters (258 bytes), **Then** accepted and stored whole.

### Edge Cases

- A text of exactly 259 bytes fits (the buffer holds 260 with the terminating NUL).
- A mask with invalid syntax that also does not fit: the length refusal comes first (one message).
- The volume-label dialog is a code-page dialog: on a CJK code page the label can hold CJK letters;
  the measure counts the UTF-8 form of what the field holds.
- The hot path label edit when the edit control is not reachable keeps the existing code-page
  fallback (the A notification text, already limited by the code page).
- An empty or space-only label edit still clears the custom name (feature 047).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Select and Unselect MUST refuse a mask whose UTF-8 form does not fit 260 bytes with
  "The path specified is too long.", leaving the dialog open, the field whole and marked, and MUST
  NOT select, unselect or store the mask in the history.
- **FR-002**: Convert MUST refuse such a mask the same way and convert nothing.
- **FR-003**: Change Filter MUST refuse such a filter whether "Use filter" or "Don't use filter" is
  chosen, and MUST NOT change the panel's filter or the history.
- **FR-004**: Drive Information MUST refuse such a label before writing any label.
- **FR-005**: The hot path in-place label edit MUST store the whole typed name in the slot; the
  page's existing check MUST refuse it at OK / leaving the page (slot selected, name field marked).
- **FR-006**: Text that fits (up to 259 bytes) MUST behave exactly as before in every field.
- **FR-007**: No new UI string; the refusal reuses "The path specified is too long."

### Key Entities

- **Selection mask**, **Convert mask**, **panel filter** (masks string + history), **volume label**,
  **hot path slot name**: each a 260-byte UTF-8 value.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe's 6 refusal rows that fail at 11e20a84 (`sel-mask`, `unsel-mask`,
  `conv-mask`, `flt`, `flt-unused`, `hp-label`) pass, and `vol` passes (refused before any write).
- **SC-002**: The 4 control rows (`sel-ctl`, `conv-ctl`, `flt-ctl`, `hp-label-ctl`: text that
  fits) still pass; the volume label that fits is checked by reading (driving it would write the
  label).
- **SC-003**: No file outside the typed mask is converted (`M.txt` unchanged in `conv-mask`).
- **SC-004**: Feature 251's probe still passes (42 / 0) - the hot path page's checks are unchanged.

## Assumptions

- Assumption (autonomous run): the limit of every field is the 260-byte buffer the program already
  reads it into (`MAX_PATH`); no buffer is grown and no registry value changes.
- Assumption (autonomous run): the shared helpers of feature 251 (`DlgItemTextFitsU8`,
  `SalGetWindowTextU8Alloc`) are used; no new pure rule is needed (the rule `SalWTextFitsU8` is
  already covered by saltests).
- Assumption (autonomous run): Convert's own syntax check keeps its existing read; the length
  check runs before it.
