# Feature Specification: typed text is never cut to the caller's buffer (Make File List, user menu, viewers, editors, hot paths, drives, Edit New)

**Feature Branch**: `251-dialog-text-fits`
**Created**: 2026-10-20
**Status**: Draft
**Input**: Backlog item dialog-typed-text-cut-to-caller-buffer (backlog/items/dialog-typed-text-cut-to-caller-buffer/desc.md) - implement exactly what it describes. From backlog item dialog-typed-text-cut-to-caller-buffer.

## Background

Feature 214 made the Copy / Move family of dialogs refuse a typed target whose UTF-8 form does not
fit the buffer the operation uses ("The path specified is too long.") instead of cutting it at a
whole character. The same cut remains in other dialogs: a field limits its text in UTF-16 units,
while the program stores it in a buffer counted in UTF-8 bytes (up to three per unit), so text that
fits the field can be shortened silently - and the shortened text is acted upon.

Measured at c7f07bc6 (hidden-desktop probe `dlg251_probe.ps1`, CJK text that fits the field but not
the buffer): Make File List wrote its list into **another file** (a 274-byte name cut to 67 letters
without `.txt`); its line format lost the tail `END$(CRLF)`; the user menu Command (277 bytes) and
the viewers' and editors' Command were stored as 258 bytes (another program would run); the user
menu Arguments (33,000 bytes) were stored as 32,769; the hot path path (1,203 bytes) and name (300
bytes) were stored as `?` characters (a code-page fallback); the drives page's "go to" path was
stored as 258 bytes; its browse button started from a cut path; Edit New's "Save as default" stored
a cut default name.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Make File List never writes to a shortened name (Priority: P1)

A user makes a file list into a file whose full name is long in UTF-8 (e.g. Chinese letters). The
program refuses the name with "The path specified is too long." and the dialog stays open; no file
is created or appended to. The same holds for a line format that does not fit.

**Why this priority**: a cut name creates, overwrites or appends to another file - user data.

**Independent Test**: probe rows `mfl-name`, `mfl-line` (refused, `out\` empty) and `mfl-ctl` (a
short name still works).

**Acceptance Scenarios**:

1. **Given** the destination File and a file name of more than 260 UTF-8 bytes, **When** OK is
   pressed, **Then** "The path specified is too long." is shown, the dialog stays open and no file
   is written.
2. **Given** a line format of more than 260 UTF-8 bytes, **When** OK is pressed, **Then** the same
   refusal; no file is written and the format is not stored in the history.
3. **Given** a short name and the default format, **When** OK is pressed, **Then** the list is
   written as before.

---

### User Story 2 - A configured command is never stored shortened (Priority: P1)

A user edits a user menu item, a viewer or an editor (Command, Arguments, Initial directory) with
text that does not fit the program's buffer. On OK (or when leaving the page) the program refuses
with "The path specified is too long.", selects the item and marks the field; the configuration is
not changed. A command that is never stored shortened is never run shortened.

**Why this priority**: a cut command runs another program.

**Independent Test**: probe rows `um-cmd`, `um-args`, `vw-cmd`, `ed-cmd`.

**Acceptance Scenarios**:

1. **Given** a user menu item whose Command has more than 260 UTF-8 bytes, **When** OK is pressed,
   **Then** the refusal is shown, the Configuration dialog stays open with the item and field shown.
2. **Given** Arguments of more than 32,772 bytes, **Then** the same.
3. **Given** a viewer's or an editor's Command of more than 260 bytes, **Then** the same.

---

### User Story 3 - Hot paths, the drives' "go to" path and Edit New's default are never stored changed (Priority: P2)

A hot path path (more than 1,040 bytes) or name (more than 260 bytes), the "If path is inaccessible
go to" path (more than 260 bytes) and Edit New's "Save as default" name (more than 260 bytes) are
refused with the same message instead of being stored cut or as `?` characters.

**Why this priority**: a changed path leads somewhere else; lower risk than a written file or a
run program.

**Independent Test**: probe rows `hp-path`, `hp-name`, `drv-goto`, `en-default`.

**Acceptance Scenarios**:

1. **Given** a hot path path of 400 CJK letters, **When** OK is pressed, **Then** the refusal; the
   configuration keeps the previous path.
2. **Given** Edit New's field with a name of more than 260 bytes, **When** "Save as default" is
   chosen, **Then** the refusal; the default stays as it was.

---

### User Story 4 - A browse button never starts from a shortened path (Priority: P3)

The browse buttons that start from the field's text (the drives page, the directory menu of the
Copy / Move family, the user-menu compare dialog, Make File List's file browse) refuse text that
does not fit instead of starting the browse from a cut path.

**Independent Test**: probe row `drv-browse` (refused, no "Select Path" window).

**Acceptance Scenarios**:

1. **Given** the drives page's field with more than 260 bytes, **When** its browse button is
   pressed, **Then** the refusal is shown and no browse window opens; the field is unchanged.

### Edge Cases

- Text that fits exactly (the UTF-8 form with its terminator equals the buffer) is accepted.
- A lone surrogate counts as three bytes (WTF-8), a surrogate pair as four.
- No memory to measure the text: refused (fail closed), as 214.
- A field the user does not use (Make File List's file name while the destination is the clipboard
  or the viewer) is not refused; a value that does not fit is not stored - the previous one stays.
- A user menu item turned into a separator or submenu keeps whatever its fields hold; the length
  check covers every item, so nothing longer than the buffer can reach the configuration.
- Text that fits behaves exactly as before (no new question, no new string).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Make File List MUST refuse a file name (destination File) or a line format whose
  UTF-8 form does not fit the buffer, with "The path specified is too long.", keep the dialog open
  and write nothing.
- **FR-002**: The user menu, viewers and editors pages MUST keep the whole typed text while editing
  and MUST refuse, when the page is validated (OK or leaving the page), every item whose Command,
  Arguments or Initial directory does not fit the buffer the program loads and runs it with
  (Command / Initial directory 260 bytes, user menu Arguments 32,772 bytes, viewers / editors
  Arguments 260 bytes): the message, the item selected, the field marked.
- **FR-003**: The hot paths page MUST never store a code-page form of the path or name; a path of
  more than 1,040 bytes or a name of more than 260 bytes MUST be refused at validation as in FR-002.
- **FR-004**: The drives page MUST refuse an edited "go to" path that does not fit 260 bytes.
- **FR-005**: Edit New's "Save as default" MUST refuse a name that does not fit 260 bytes and leave
  the stored default unchanged.
- **FR-006**: The listed browse-from-field buttons MUST refuse a field text that does not fit
  instead of starting from a cut path.
- **FR-007**: The rule "does the whole text fit N bytes of UTF-8 (WTF-8) with its terminator" MUST
  be one shared, unit-tested decision (also used by feature 214's check).
- **FR-008**: No new UI string: the existing "The path specified is too long." (`IDS_TOOLONGPATH`).
- **FR-009**: Text that fits MUST behave as before.

### Key Entities

- **Caller's buffer**: the size in UTF-8 bytes the program keeps or loads a value with (260 for
  names, commands and directories, 1,040 for a hot path path, 32,772 for user menu arguments).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe `dlg251_probe.ps1`: every refusal row (11) FAIL before, PASS after; the control
  row PASS before and after; registry restored identical.
- **SC-002**: No file is created in the probe's output folder by a refused Make File List.
- **SC-003**: `saltests` carries checks of the shared rule (ASCII, CJK, surrogate pair, lone
  surrogate, exact fit, one byte over, empty text, zero buffer); 0 failed.
- **SC-004**: Feature 214's probe (`cm_text_probe.ps1`) still 4 / 0.

## Assumptions

- Assumption (autonomous run): the configuration pages that store on every keystroke are refused at
  page validation (OK / leaving the page), as their existing checks are; refusing keystrokes is not
  possible and cutting is what the item forbids.
- Assumption (autonomous run): the hot path name is fixed with its path (the same code-page fallback
  side by side, the item names the hot path editor); the in-place label edit of the hot path list
  (a display label cut at a whole character) stays out of scope.
- Assumption (autonomous run): Make File List's own file browse button is treated as the other
  browse-from-field buttons (FR-006).
- Assumption (autonomous run): a browse button refuses rather than starting without a folder - the
  item's *Expected* says each field refuses.
