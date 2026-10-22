# Feature Specification: Find's Containing text and the viewer's Find text are never cut to the program's buffer

**Feature Branch**: `311-find-containing-cut`
**Created**: 2026-10-22
**Status**: Draft
**Input**: Backlog item find-cuts-a-long-containing-text-and-writes-the-cut-text (backlog/items/find-cuts-a-long-containing-text-and-writes-the-cut-text/desc.md) - implement exactly what it describes. From backlog item find-cuts-a-long-containing-text-and-writes-the-cut-text.

## Background

The Find dialog's "Containing" field limits its text to 200 UTF-16 units, but the program reads it
into a 201-byte UTF-8 buffer: a longer UTF-8 form (CJK letters take three bytes, accented letters
two) is shortened at a whole character without a word, the shorter text is searched for, written
back into the field and stored in the history. Feature 291 fixed the same defect for the "Named"
field of the same dialog; "Containing" kept it (`review:291`).

Measured at 95145b44 (hidden-desktop probe, driver of 291's probe; fixture `cut.txt` = 66 CJK
letters + "ZZ", `full.txt` = 67 CJK letters, `other.txt`), 7 rows FAIL:
- Find, "Search file content" on, Containing = 67 CJK letters (201 bytes): no question, **found 2**
  (`cut.txt` does not contain the typed text), the field afterwards holds 66 letters.
- Regular expression (66 letters + `ZZQ`, 201 bytes): searched as 66 letters + `ZZ`, found 1, field
  cut. Hex mode (`"<66 letters>" 5A 5A`, 206 bytes): searched as the quoted text alone, found 2.
- Options > Add Current and Options > Ignore: the field written back cut (Manage runs the same
  code). A stored option without a Containing text chosen: the field cut to 66 letters, the next
  Find found 2.
- The internal viewer's Find (Alt+F3 on `cut.txt`, Find) with 67 letters: the dialog closed with no
  "cannot find", although the file does not hold the typed text - it searched the cut text.
Controls (66 letters + `Z`, 199 bytes) are found and kept whole.

## Clarifications

### Session 2026-10-22

- Q: When both Named and Containing do not fit, which one is refused first? → A: Named - feature 291's check keeps its place; after it is fixed the next Find refuses Containing (autonomous run: conservative - existing behaviour unchanged for Named)
- Q: Should Options > Manage refuse before its window opens, like Add Current and Ignore? → A: yes - same message, no window (autonomous run: item - "before Add Current / Manage / Ignore read it")
- Q: When a found file is viewed and the Containing text does not fit the viewer's buffer, should viewing be refused or the copy into the viewer's Find skipped? → A: the copy is skipped silently, the file is viewed, the viewer keeps its earlier find text (autonomous run: conservative - viewing unchanged, nothing cut stored, no new string)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Find never searches for a cut Containing text (Priority: P1)

A user types a Containing text whose UTF-8 form is longer than 200 bytes and starts a search (Find,
Find Duplicates, or the refine commands of the result list). The program refuses with "The path
specified is too long." before searching; the field keeps the whole text; nothing is found and
nothing goes into the history. This holds in plain-text, regular-expression and hex mode.

**Why this priority**: a cut text matches files that do not contain the typed text; the user may
act on the results (delete them).

**Independent Test**: probe rows `grep`, `grep-regex`, `grep-hex`; control `grep-ctl`.

**Acceptance Scenarios**:

1. **Given** Containing = 67 CJK letters, **When** Find, **Then** "too long", nothing found, the
   field holds the 67 letters.
2. **Given** regular expressions on and a 201-byte pattern, **When** Find, **Then** refused as 1.
3. **Given** hex mode and a quoted text making 206 bytes, **When** Find, **Then** refused as 1.
4. **Given** Containing = 66 CJK letters + `Z` (199 bytes), **When** Find, **Then** no question,
   1 found, the field whole.

---

### User Story 2 - Options commands never write a cut text back (Priority: P1)

Options > Add Current, Options > Manage and Options > Ignore read the dialog's fields without the
search's check. With a Containing text that does not fit they refuse first with the same message
and do nothing; the field keeps the whole text.

**Why this priority**: otherwise the cut text is written back silently and the next Find uses it.

**Independent Test**: probe rows `grep-add`, `grep-manage`, `grep-ignore`.

**Acceptance Scenarios**:

1. **Given** Containing = 67 CJK letters, **When** Options > Add Current / Manage / Ignore, **Then**
   "too long", no option added and no window opened, the field whole.

---

### User Story 3 - A stored option without Containing keeps the whole field (Priority: P2)

Choosing a stored Find option that has no Containing text keeps the field's current text (existing
behaviour) - whole, never read cut; the next Find refuses it as in Story 1.

**Independent Test**: probe row `grep-option`.

**Acceptance Scenarios**:

1. **Given** a stored option without Containing and Containing = 67 CJK letters, **When** the
   option is chosen, **Then** the field holds the 67 letters; **When** Find, **Then** refused.

---

### User Story 4 - The viewer's Find never searches for a cut text (Priority: P2)

In the internal viewer's Find dialog a text whose UTF-8 form is longer than 200 bytes is refused
with "The path specified is too long." at OK; the dialog stays with the whole text; nothing is
searched or stored in the viewer's history.

**Independent Test**: probe rows `view-find`, control `view-ctl`.

**Acceptance Scenarios**:

1. **Given** the viewer's Find with 67 CJK letters, **When** OK, **Then** the dialog stays, "too
   long", the field whole.
2. **Given** 66 letters + `Z`, **When** OK, **Then** the dialog closes and the viewer searches.
3. **Given** a finished Find with a result, then Containing changed to 67 CJK letters, **When** the
   result is viewed with the internal viewer (Alt+F3) and its Find opened, **Then** the viewer's
   find text is not the cut 66 letters (probe row `view-copy`).

### Edge Cases

- A text of exactly 200 bytes fits and is accepted unchanged.
- The "Named" check of feature 291 keeps its place: with both fields too long, Named is refused
  first; after it is fixed, Containing is refused.
- "Search file content" off: the Containing field is emptied by the dialog (existing behaviour),
  nothing to refuse.
- Viewing a found file (F3 / Alt+F3 / View With in the result list) copies the Containing text into
  the viewer's Find text and history (Configuration "copy find text", on by default) through a read
  that cuts at a whole character (core `CTransferInfo::EditLine`). The field may have been edited
  after the search, so a text that does not fit can reach it: the copy is skipped then (the viewer
  keeps its earlier find text); viewing is not refused.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Starting a search from the Find dialog MUST refuse a Containing text whose UTF-8 form
  does not fit the program's 201-byte buffer with "The path specified is too long." before the
  search and before the field is read into the buffer; the field keeps its whole text and gets the
  focus.
- **FR-002**: FR-001 holds whatever the mode: plain text, regular expression, hex.
- **FR-003**: Options > Add Current, Options > Manage and Options > Ignore MUST refuse such a
  Containing text the same way before reading the dialog's fields; the command then does nothing.
- **FR-004**: Choosing a stored Find option without a Containing text MUST keep the field's text
  whole (a text that does not fit is put back whole after the option is shown).
- **FR-005**: The internal viewer's Find dialog MUST refuse at OK a find text whose UTF-8 form does
  not fit its 201-byte buffer with the same message; the dialog stays with the whole text.
- **FR-006**: No new UI string; text that fits behaves as before (searched, stored, kept).
- **FR-007**: Nothing cut is searched for, written back into a field, or stored in a history or a
  Find option.
- **FR-008**: Copying the Containing text into the viewer's Find text when a found file is viewed
  MUST be skipped when the text does not fit the viewer's 201-byte buffer; the viewer keeps its
  earlier find text and history; the file is viewed as before.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe's 7 refusal rows that FAIL at 95145b44 PASS after the change, as do the new rows
  `grep-manage` and `view-copy`; its control rows PASS before and after.
- **SC-002**: The probes of features 291 (Named) and 251 still pass in full.
- **SC-003**: Encoding guard `TOTAL: 0`, build succeeds, `saltests` 0 failed.

## Assumptions

- Assumption (autonomous run): the viewer's Find is in scope - the item's *Notes* ask to check it
  "while there", the measurement confirmed the same cut, and the fix is the same refusal.
- Assumption (autonomous run): Manage is driven by the probe as well (the item names it), although
  feature 291 measured it by reading only.
- Assumption (autonomous run): the refusal reuses `DlgItemTextFitsU8` and `IDS_TOOLONGPATH` as 291
  did (item: "no new string").
- Assumption (autonomous run): the copy into the viewer (FR-008) is skipped silently rather than
  refusing to view the file - conservative: viewing is unchanged, nothing cut is stored, no new
  string.
- Stored Find options and histories already cut by earlier versions are not repaired.
