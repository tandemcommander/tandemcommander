# Feature Specification: Recycle Bin, Find, viewer and compare masks and the view name are never cut to the program's buffer

**Feature Branch**: `291-masks-cut-rest`
**Created**: 2026-10-21
**Status**: Draft
**Input**: Backlog item masks-cut-recycle-bin-find-viewer-compare (backlog/items/masks-cut-recycle-bin-find-viewer-compare/desc.md) - implement exactly what it describes. From backlog item masks-cut-recycle-bin-find-viewer-compare.

## Background

Features 251 and 270 made typed fields refuse text whose UTF-8 form does not fit the program's
buffer ("The path specified is too long.") instead of cutting it at a whole character. The mask
fields of the Recycle Bin (Configuration > System), the Find dialog ("Named"), the viewer (text /
hex mode masks), Compare Directories (ignore files / directories) and the in-place name edit of
Configuration > Views keep the cut: a field limits its text in UTF-16 units (259), the program reads
it into a 260-byte UTF-8 buffer (the view name: 30 bytes), so longer text (CJK letters take three
bytes) is shortened silently and the shorter text is used or stored.

Measured at c01e1801 (hidden-desktop probe `mask291_probe.ps1`, M = 86 CJK letters = 258 bytes,
R = 85 = 255 bytes), 12 rows FAIL:
- Recycle Bin masks `R;*.kp` (260 bytes) were stored as `R;*.k` - with "Move following files to the
  Recycle Bin" and also with "Move all deleted files ..." (the field is stored whatever the choice).
  A mask dropped by the cut no longer matches: the files it named would be **deleted permanently**.
- Find, Named `M*Q`: cut to `M*`, the search found `M.txt` too (the typed mask matches only `MxQ`).
  Options > Add Current and Options > Ignore (and Manage, the same code) read the field cut and
  **wrote the cut text back into the field** without a word, so the next Find used it. Choosing a
  stored Find option without a Named text (the field's text is kept) did the same.
- The viewer's text and hex masks `M*Q` were stored as `M*`.
- Compare Directories' "Ignore files" masks `M*Q` were stored cut; the "Ignore directories" masks
  too while that box was unchecked (both fields are stored whatever the check boxes).
- The Views list's in-place name edit stored 9 of 11 CJK letters (33 bytes) and 29 of 30 ASCII
  letters (the name holds 29 bytes + NUL).
Controls (text that fits) are accepted and kept whole.

## Clarifications

### Session 2026-10-21

- Q: The Recycle Bin masks with "Move all deleted files" or "Remove immediately" chosen: is a text that does not fit refused too? → A: yes - the field is stored whatever the choice, and nothing cut may be stored (autonomous run: item - "no cut mask list is used or stored"; as 270's filter with "Don't use filter")
- Q: The compare ignore masks with their check box off: refused too? → A: yes, for the same reason (both fields are stored whatever the check boxes); the user checks the box to edit the field, or cancels (autonomous run: item; conservative - refuses rather than drops the typed text)
- Q: The Find dialog's Add Current / Manage / Ignore commands, which read the field without the dialog's check: refuse or skip? → A: refuse with the same message before reading the field; the command does nothing, the field keeps the whole text (autonomous run: item - "no cut mask list is used or stored"; conservative)
- Q: Choosing a stored Find option without a Named text keeps the field's text - read cut? → A: no - the field keeps its whole text; the next Find refuses it (autonomous run: item; conservative - the existing "keep the previous value" behaviour, whole)
- Q: The Views name edit (30-byte name): refuse at Enter, or keep the whole name and refuse at OK? → A: refuse at the end of the edit with "The path specified is too long."; nothing is stored, the row keeps its earlier name - the views keep their names in 30-byte slots, so the whole text cannot be kept (autonomous run: item - its *Expected* names this refusal; conservative - no new string, no buffer grown)
- Q: After the view name refusal, should the in-place edit open again with the typed text? → A: no - the message is shown and the edit is over; the user presses F2 again (autonomous run: conservative - changes least, the list's edit handling stays as it is)
- Q: A view name edit that ends because the focus moves (e.g. OK pressed while editing) with a name that does not fit? → A: refused the same way; nothing is stored, the row keeps its earlier name and the dialog continues as before (autonomous run: conservative - never stores a cut name)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Recycle Bin masks are never stored cut (Priority: P1)

A user types Recycle Bin masks ("Move following files to the Recycle Bin, delete others
permanently") whose UTF-8 form is longer than 259 bytes and presses OK (or leaves the page). The
program refuses with "The path specified is too long.", the page stays with the whole text in the
field; the stored masks stay as they were.

**Why this priority**: a mask dropped by the cut no longer matches - the files it named are deleted
permanently instead of going to the Recycle Bin.

**Independent Test**: probe rows `rb-mask`, `rb-unused`, control `rb-ctl`.

**Acceptance Scenarios**:

1. **Given** the System page, the masks choice and masks of more than 259 bytes, **When** OK is
   pressed, **Then** "The path specified is too long." is shown, the Configuration stays open, the
   field holds the whole text.
2. **Given** another Recycle Bin choice and such a text in the masks field, **When** OK is pressed,
   **Then** the same refusal.
3. **Given** masks of exactly 259 bytes, **Then** accepted and stored whole.

---

### User Story 2 - Find never searches with a cut "Named" mask (Priority: P1)

A user types a "Named" mask that does not fit and starts Find (Find, Find Now, Append / Subtract /
Intersect results, Find Duplicates). The program refuses it; nothing is searched, the field keeps
the whole text. Add Current, Manage and Ignore refuse the same way before reading the field. A
stored option without a Named text leaves the whole field text in place.

**Why this priority**: a cut mask finds other files, which the user may delete from the results.

**Independent Test**: probe rows `find-named`, `find-add`, `find-ignore`, `find-option`, control
`find-ctl`.

**Acceptance Scenarios**:

1. **Given** Named of more than 259 bytes, **When** Find is pressed, **Then** the refusal; no
   result, the field whole.
2. **Given** such a text, **When** Options > Add Current, Manage or Ignore is chosen, **Then** the
   refusal; nothing is added or opened, the field whole.
3. **Given** such a text, **When** a stored option without a Named text is chosen, **Then** the
   field still holds the whole text, and Find refuses it.
4. **Given** Named of 259 bytes, **Then** the search runs with it whole, as before.

---

### User Story 3 - Viewer and compare masks are never stored cut (Priority: P2)

A user types viewer text / hex mode masks or compare ignore masks that do not fit. OK refuses them,
the dialog / page stays, nothing is stored.

**Why this priority**: a wrong result with a workaround (a shorter mask list).

**Independent Test**: probe rows `view-text`, `view-hex`, `cmp-files`, `cmp-dirs-unused`, controls
`view-ctl`, `cmp-ctl`.

**Acceptance Scenarios**:

1. **Given** the Viewer page and text (or hex) masks of more than 259 bytes, **When** OK is pressed,
   **Then** the refusal, the field whole.
2. **Given** Compare Directories and ignore masks of more than 259 bytes, with the box checked or
   not, **When** OK is pressed, **Then** the refusal; no compare runs.
3. **Given** masks of 259 bytes, **Then** accepted and stored whole.

---

### User Story 4 - A view name is never stored cut (Priority: P3)

A user renames a view in place (Configuration > Views) with a name longer than 29 UTF-8 bytes and
presses Enter. The program refuses it ("The path specified is too long."); the row keeps its
earlier name.

**Independent Test**: probe rows `vname`, `vname-ascii`, control `vname-ctl`.

**Acceptance Scenarios**:

1. **Given** the in-place edit of a view row and 11 CJK letters (33 bytes) or 30 ASCII letters,
   **When** Enter is pressed, **Then** the refusal; the row keeps its earlier name.
2. **Given** a name of 29 bytes, **Then** stored whole, as before.

### Edge Cases

- A text of exactly 259 bytes fits a 260-byte buffer; a view name of 29 bytes fits its 30.
- A mask with invalid syntax that also does not fit: the length refusal comes first (one message).
- The viewer page checks the tab size first (as before); the masks are measured after it.
- A refused compare field may be disabled (its box unchecked): the message names the problem; the
  user checks the box to edit the field, or cancels.
- A view name edit ended by a focus change (not Enter) is refused the same way; nothing is stored.
- An empty view name edit keeps its existing behaviour; the code-page fallback (no edit control
  reachable) is unchanged - its text is already limited.
- Stored masks are never longer than 259 bytes (registry load and the settings import refuse
  more), so only typed text can be refused.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The System page MUST refuse Recycle Bin masks whose UTF-8 form does not fit 260
  bytes with "The path specified is too long.", whatever the Recycle Bin choice, before the syntax
  check, the field whole and marked; nothing is stored.
- **FR-002**: The Find dialog MUST refuse such a Named text before any search, before its syntax
  check; nothing is searched, the field and its history are not changed.
- **FR-003**: Find's Add Current, Manage and Ignore MUST refuse such a Named text before reading the
  field; the field keeps the whole text.
- **FR-004**: Choosing a stored Find option without a Named text MUST keep the field's whole text.
- **FR-005**: The Viewer page MUST refuse such text or hex masks before their syntax check.
- **FR-006**: Compare Directories MUST refuse such ignore files / directories masks whatever the
  check boxes; no compare runs, nothing is stored.
- **FR-007**: The Views in-place name edit MUST refuse a name whose UTF-8 form does not fit 30 bytes
  and store nothing.
- **FR-008**: Text that fits MUST behave exactly as before in every field.
- **FR-009**: No new UI string; the refusal reuses "The path specified is too long."

### Key Entities

- **Recycle Bin masks**, **Find Named mask** (+ history, stored options), **viewer text / hex
  masks**, **compare ignore masks**: each a 260-byte UTF-8 value; **view name**: 30 bytes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe's 12 rows that fail at c01e1801 (`rb-mask`, `rb-unused`, `find-named`,
  `find-add`, `find-ignore`, `find-option`, `view-text`, `view-hex`, `cmp-files`,
  `cmp-dirs-unused`, `vname`, `vname-ascii`) pass.
- **SC-002**: The 5 control rows (`rb-ctl`, `find-ctl`, `view-ctl`, `cmp-ctl`, `vname-ctl`) still
  pass and every END row passes (no stray window, clean exit).
- **SC-003**: Feature 270's probe (24 / 0) and 251's (42 / 0) still pass.

## Assumptions

- Assumption (autonomous run): every limit is the buffer the program already reads the field into
  (`MAX_PATH`, `NAMED_TEXT_LEN`, `VIEW_NAME_MAX`); no buffer is grown, no registry value changes.
- Assumption (autonomous run): 251's helpers (`DlgItemTextFitsU8`, `SalGetWindowTextU8Alloc`) are
  used; no new pure rule is needed (`SalWTextFitsU8` is covered by saltests).
- Assumption (autonomous run): the actual deletion to / past the Recycle Bin is not driven by the
  probe (it would write the user's Recycle Bin); it follows from the stored masks (the delete
  matches them), checked by reading.
- Assumption (autonomous run): other Find fields (Containing, Look in) are outside the item; Look in
  is already limited so that its UTF-8 always fits (feature 121).
