# Feature Specification: User Menu compare names and the Change Icon file are never cut

**Feature Branch**: `389-compare-icon-fits`
**Created**: 2026-11-02
**Status**: Draft
**Input**: Backlog item `user-menu-compare-names-and-the-change-icon-file-are-cut-to` - "User Menu compare names and the Change Icon file are cut to 259 bytes". From backlog item user-menu-compare-names-and-the-change-icon-file-are-cut-to.

## Clarifications

### Session 2026-11-02

- Q: In the names-to-compare dialog, does the length check run before the existing "empty name" check? → A: Yes - both fields are measured first, name 1 then name 2, then the empty checks (autonomous run: item - "refuses ... before anything else")
- Q: When the Change Icon dialog refuses to reload icons for a too long name, what does the icon list show? → A: It keeps the icons it showed; no other file is read and OK stays refused until the name fits (autonomous run: conservative)
- Q: Does the refusal use a new message? → A: No - the existing "The path specified is too long." (autonomous run: item)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Names to compare are used whole or refused (Priority: P1)

A user runs a User Menu item whose arguments name two files or folders to compare. The program
shows the "names to compare" dialog; the user types (or keeps) two full names. When a name is
longer than the program can hold (its UTF-8 form over 259 bytes - e.g. 87 or more CJK letters in a
short path), today the dialog closes silently and the compare tool is started with a shorter,
different name. After the fix the dialog says "The path specified is too long.", stays open with the
field and its whole text selected, and nothing is started.

**Why this priority**: the tool is started with names the user never typed - the wrong result is
silent.

**Independent Test**: a User Menu item `cmd.exe /c echo $(FileToCompareLeft)#$(FileToCompareRight)>args.txt`
run from its command; the probe fills both fields and presses OK, then reads what the command wrote.

**Acceptance Scenarios**:

1. **Given** the dialog with name 1 = `C:\` + 86 CJK letters + `a` (262 bytes) and a short name 2,
   **When** the user presses OK, **Then** "The path specified is too long." is shown, the dialog
   stays, name 1 is whole in its field and the command is not started.
2. **Given** a short name 1 and a too long name 2, **When** OK, **Then** the same refusal for name 2.
3. **Given** two names of exactly 259 bytes, **When** OK, **Then** nothing is asked, the dialog closes
   and the command receives both names whole.

---

### User Story 2 - The Change Icon file is used whole or refused (Priority: P2)

In Configuration > User Menu the user selects an item and presses Change Icon, types a file name
whose UTF-8 form is longer than 259 bytes and leaves the field or presses OK. Today the icons are
read for a code-page form of the name (letters outside the code page become `?`), the program says
the file cannot be found, puts SHELL32.DLL into the field and stores SHELL32.DLL as the item's icon
file. After the fix the dialog says "The path specified is too long." both when the icons would be
reloaded and on OK, keeps the typed text whole in the field and stores nothing.

**Why this priority**: a wrong icon only; still a silently replaced user choice.

**Independent Test**: an existing copy of a program with icons named `<fixture>\icons\<86 CJK>.exe`
(312 bytes); the probe sets the field and presses OK twice.

**Acceptance Scenarios**:

1. **Given** the Change Icon dialog with the long file name typed, **When** the user presses OK (the
   field loses focus and the icons would be reloaded), **Then** "too long" is shown, the dialog stays,
   the field is whole.
2. **Given** the same state after the refusal, **When** OK again, **Then** "too long" again, the
   dialog stays, the field is whole, nothing is stored.
3. **Given** a file whose full name with the stored `,<index>` is at most 259 bytes (257 bytes and
   icon 0..9), **When** OK, **Then** nothing is asked, its icons load, the dialog closes and Change
   Icon opened again shows the name whole; the program started with that stored value shows nothing
   and keeps the icon.
4. **Given** a name of 259 bytes (or 257 bytes with icon 10 picked), whose stored `name,index`
   would be longer than the 259 bytes the configuration loader reads, **When** OK, **Then** "too
   long", the dialog stays (review 1: such a value was lost at the next start).

### Edge Cases

- Both compare names too long: the first field is refused first (the user fixes it, the second is
  refused at the next OK).
- An empty compare name keeps its existing "empty string" refusal; the length check runs first.
- A text of exactly 259 bytes (+ NUL = 260) fits and is accepted.
- The Change Icon field loses focus while too long (to the list or Browse): the reload is refused with
  the same message; the list keeps the icons it showed, no other file is read.
- Browse in both dialogs already refuses a picked name that does not fit (feature 172) and the
  folder browse of the compare dialog already measures its start (feature 251) - unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The names-to-compare dialog MUST, on OK, measure each name field whole before anything
  else and refuse a name whose UTF-8 form does not fit 260 bytes (with the NUL) with "The path
  specified is too long.", the dialog open and that field focused with its text selected.
- **FR-002**: The Change Icon dialog MUST, on OK, measure the file name field whole and refuse a name
  whose UTF-8 form plus the stored `,<index>` (the selected icon, else 0) does not fit 260 bytes with
  the NUL - the value the User Menu page stores and the configuration loader reads back - with the
  same message and focus.
- **FR-003**: The Change Icon dialog MUST NOT read icons for a cut or code-page form of the name: a
  reload (on leaving the changed field, on OK of a changed field) of a name that does not fit is
  refused with the same message, the field keeps the typed text and no other file is read.
- **FR-004**: Text that fits MUST behave exactly as before (no new question, stored / used whole):
  compare names up to 259 bytes; an icon file name whose stored `name,index` is up to 259 bytes (a
  258 / 259-byte icon file name was accepted before but its stored value was lost at the next
  start - it is refused now, review 1).
- **FR-005**: No new UI string; the existing `IDS_TOOLONGPATH` text is used.

### Key Entities

- **Compare names**: the two full names a User Menu item's compare arguments expand to (buffers of
  260 bytes).
- **Icon file**: the file the Change Icon dialog lists icons from and stores as `file,index` in the
  User Menu item.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe `fit389_probe.ps1`: the rows that failed before the fix (umc-name1, umc-name2,
  chi-file, and since review 1 chi-store259) pass after it; the control rows (umc-ctl, chi-ctl,
  chi-reload, chi-idx9) pass and the boundary row chi-idx10 is refused.
- **SC-002**: 0 cases in which a name over the limit typed into either dialog is used or stored in
  another (shorter or code-page) form, or stored in a form the next start cannot read.
- **SC-003**: The encoding guard, the build and saltests stay green; earlier probes of the area
  (291's, 251's) still pass.

## Assumptions

- Assumption (autonomous run): the limit stays 260 bytes (MAX_PATH) - the buffers of the callers
  (`CompareName1/2`, the User Menu icon value read with `MAX_PATH`) are not enlarged; refusing is the
  standing rule ("a path or name is never cut").
- The Find dialog's User Menu uses the same compare dialog, so it is covered by the same change.
