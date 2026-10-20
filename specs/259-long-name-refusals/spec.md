# Feature Specification: Long names - Paste copy name, Edit New File, simple-selection conversion

**Feature Branch**: `259-long-name-refusals`  
**Created**: 2026-10-20  
**Status**: Draft  
**Input**: User description: "Backlog item core-long-name-wrong-refusals - implement exactly what it describes: Paste of a ~250-byte name in its own folder either creates the "- Copy" name or refuses with "too long name"; Edit New File accepts long paths or the limit is stated; `IsSimpleSelection` never converts through `CP_ACP` and says "too long" correctly." From backlog item core-long-name-wrong-refusals.

## Measured before (7a13bdee)

- **Edit New File** (Shift+F4): probe `probe/editnew259_probe.ps1`, label before - 7 PASS / 3 FAIL.
  A relative name typed in a panel whose folder path is 288 bytes, a typed full path of 294
  bytes and a name of 100 CJK letters (304 bytes of UTF-8, a valid name) in a short folder are
  all refused with "The path specified is too long." The control (a short folder, "n.txt") is
  created; a name of 256 letters (more than a file system takes) is refused.
- **Paste "- Copy"** (Ctrl+C, Ctrl+V of a file or folder into the folder it is in): the copy name
  is assembled in a 260-byte window and dropped when it reaches 260 bytes; the copy then targets
  the source itself and the user reads "Cannot copy a file to itself." - for "250 letters.txt"
  (whose copy name no file system takes: the right answer is "too long name") and also for
  "84 CJK letters.txt" (256 bytes; its copy name has 95 UTF-16 units and could be created).
  By reading - the clipboard is not driven on the hidden desktop.
- **Simple selection** (Paste or drop of disk files into an archive or a plug-in file-system
  panel): when converting the common folder or a name to UTF-8 fails, the code falls back to the
  ANSI code page cut at 259 bytes (another name); a common folder too long for the program's
  path buffer is reported as "Source path cannot be translated from Unicode to multibyte"
  instead of "too long". With real Windows paths these routes are reached only on low memory or
  through a crafted drop list (by reading).

## Clarifications

### Session 2026-10-20

- Q: Which message does Edit New File show for a name no file system takes (over 255 UTF-16 units) once long paths are accepted? → A: The existing "Cannot finish operation because of too long name." (IDS_TOOLONGNAME) from a check of the new name against 255 UTF-16 units; the dialog comes back (autonomous run: conservative). Measured while implementing: without the check Windows answers error 123 "invalid name", not "too long" - the first answer (the file system's own error) was revised
- Q: Does a too-long copy name end the whole Paste or only skip that item? → A: The existing "name is too long" question decides per item - Skip / Skip all go on with the other items, Focus / Cancel end the operation before anything is copied (autonomous run: rule - feature 141's handling of a mask result that no file system takes)
- Q: What happens when the legacy ANSI drop list cannot be converted to UTF-8? → A: The selection is refused (no operation), as on low memory - the raw code-page bytes are never used as a UTF-8 name (autonomous run: conservative - refuse rather than guess)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Edit New File in long paths (Priority: P1)

A user works in a folder whose path is longer than 259 bytes (deep trees, or names in scripts
that take three bytes per letter) and creates a new file with Edit New File.

**Why this priority**: it is the measured, reproducible refusal of valid work; the program
otherwise supports such paths (copy, move, create directory, edit an existing file).

**Independent Test**: probe rows SHORT, REL, ABS, CJK, OVER.

**Acceptance Scenarios**:

1. **Given** a panel in a folder whose path is 288 bytes, **When** the user types "n.txt" and
   confirms, **Then** the file is created there and the editor is started with it.
2. **Given** a panel in a short folder, **When** the user types the full path (over 259 bytes) of
   a new file in an existing deep folder, **Then** that file is created.
3. **Given** a panel in a short folder, **When** the user types a name of 100 CJK letters +
   ".txt", **Then** the file is created under exactly that name.
4. **Given** a name longer than any file system takes (256 letters), **When** the user confirms
   it, **Then** nothing is created and a message says the name is too long ("Cannot finish
   operation because of too long name."); the dialog comes back with the text.
5. **Given** a short folder and a short name, **When** the user confirms, **Then** the file is
   created as before (control).

---

### User Story 2 - Paste a copy of a long name into its own folder (Priority: P2)

A user copies a file or folder to the clipboard and pastes it into the same folder; the program
names the copy "name - Copy.ext", "name - Copy (2).ext", ... (Windows Explorer's style).

**Why this priority**: the wrong message ("to itself") misleads, and a valid copy is refused;
nothing is lost (the operation does nothing).

**Independent Test**: unit checks of the copy-name rule (whole names, the 255-unit limit); the
paste itself by a person (clipboard).

**Acceptance Scenarios**:

1. **Given** a file "84 CJK letters.txt" (256 bytes), **When** the user pastes it into its own
   folder, **Then** a copy "84 CJK letters - Copy.txt" is created.
2. **Given** a file "250 letters.txt", **When** the user pastes it into its own folder, **Then**
   the "too long name" question appears (Skip / Skip all / Focus / Cancel) and no file is created
   or changed; "Cannot copy a file to itself." is never shown.
3. **Given** a short name whose copy names exist up to "(5)", **When** the user pastes it,
   **Then** "name - Copy (6).ext" is created as before.
4. **Given** several selected items, one of them too long for a copy name, **When** the user
   pastes them and answers Skip, **Then** the other items are copied and the long one is not.

---

### User Story 3 - Simple selection never takes a code-page name (Priority: P3)

A user pastes or drops disk files into an archive or a plug-in file-system panel.

**Why this priority**: reached only on low memory or with a crafted drop list; the fix removes
a route to a wrong (cut, code-page) name and a misleading message.

**Independent Test**: by reading and by the existing routes still working (paste / drop of
ordinary names is unchanged).

**Acceptance Scenarios**:

1. **Given** a drop list whose common folder is too long for the program, **When** it is pasted
   into an archive, **Then** the message is "The path specified is too long." and nothing is
   packed.
2. **Given** a conversion of a name or folder to UTF-8 that fails, **When** the list is
   processed, **Then** the operation does not start (as for any other low-memory failure); no
   code-page or cut name is used.
3. **Given** ordinary file names (any script), **When** they are pasted into a ZIP panel,
   **Then** they are packed as before.

### Edge Cases

- A copy name exactly at the limit (255 UTF-16 units) is created; one unit more is "too long".
- A copy name that is valid but whose full path exceeds the program's path limit goes the same
  "too long" way.
- A localized word "Copy" (any language) is part of the name and counted in UTF-16 units.
- Names with a 4-byte UTF-8 letter (emoji) count two units.
- Edit New File with a relative name in a long folder and with "..\" parts; a typed path whose
  folder does not exist is refused by the existing path check, as before.
- A malformed drop list with an empty name component (only a crafted list) keeps the old
  behaviour: the name "" (it matches no file).
- The legacy ANSI drop list keeps converting from the ANSI code page (that is what it holds);
  only its "keep the raw bytes" and cutting fallbacks are removed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Edit New File MUST accept a typed name or path whose full path is up to the
  program's long-path limit, relative or absolute, and create the file under exactly that path.
- **FR-002**: Edit New File MUST refuse a name no file system takes ("Cannot finish operation
  because of too long name.") or a path over the program's limit ("The path specified is too
  long."), and MUST never create a cut name.
- **FR-003**: Paste into the item's own folder MUST build the copy name whole (no byte limit
  smaller than what a file system takes) and create it when it has at most 255 UTF-16 units.
- **FR-004**: When the copy name would exceed 255 UTF-16 units (or its full path the program's
  limit), Paste MUST show the existing "name is too long" question (Skip / Skip all / Focus /
  Cancel) and MUST NOT report "to itself" or create any file for that item.
- **FR-005**: The copy-name rule (Explorer style: " - Copy", " - Copy (n)", the "(n)" of a name,
  folders without extension) MUST stay as it is for every name that fits.
- **FR-006**: The simple-selection conversion MUST NOT convert a wide name or folder through the
  ANSI code page, MUST NOT cut a name or folder, and MUST NOT keep code-page bytes as a UTF-8 name;
  a list that cannot be converted is refused (no operation starts).
- **FR-007**: A common folder too long for the program MUST be reported as "The path specified is
  too long." by the paste / drop into an archive or file-system panel.
- **FR-008**: No new UI string; existing messages only.

### Key Entities

- **Copy name**: the name a pasted copy gets in its own folder; derived from the source name, the
  localized word "Copy" and a number; valid when it has at most 255 UTF-16 units.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The Edit New File probe passes all five rows (before: 3 of 5 failed).
- **SC-002**: The unit checks of the copy-name rule pass, including a name at 255 units created
  and one at 256 refused; a negative control (the old 260-byte limit) fails them.
- **SC-003**: No code path of the simple-selection conversion calls a code-page conversion of a
  wide string (verified by reading and by the encoding guard staying at 0 findings).
- **SC-004**: Encoding guard 0 findings, build succeeds, unit checks 0 failed.

## Assumptions

- Assumption (autonomous run): the "too long" answer for Paste uses the existing question of
  F5 / F6 with a mask (feature 141) - Skip / Skip all / Focus / Cancel - rather than a new
  message; the item says "refuses with too long name" and FR-008 forbids new strings.
- Assumption (autonomous run): Edit New File takes the item's first option ("accepts long
  paths"), as Create Directory already does (feature 027).
- Assumption (autonomous run): the pre-Vista copy-name patterns ("Copy of ...") are never used on
  the supported Windows 11; they get the same "too long" handling instead of "to itself" but no
  other change.
- The paste rows need the clipboard and are owed to a person (CLAUDE.md working method).
