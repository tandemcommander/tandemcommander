# Feature Specification: User Menu on items in folders of 260 or more bytes - work, or refuse aloud

**Feature Branch**: `280-user-menu-long-paths`  
**Created**: 2026-10-21  
**Status**: Draft  
**Input**: User description: "Backlog item user-menu-long-paths - implement exactly what it describes: every User Menu route either runs the command on the whole name or refuses with "too long name" before anything runs; no route acts on, or shows, a cut path; the choice between work and refuse is recorded per route." From backlog item user-menu-long-paths.

## Measured before (d7405c6a)

Debug build of d7405c6a, probe `um280_probe.ps1` on the hidden desktop. Fixture under
`%TEMP%\tc280`: `s\a.txt`, `s\<L>.txt` (L = 90 CJK letters, the name 274 bytes of UTF-8),
`pl\<L>\a.txt` (a folder of 313 bytes), `pc\<p...>\b\a.txt` (a folder of 260 bytes whose first
259 bytes end with a backslash). User Menu items write their expanded arguments with
`cmd /u /c echo`. Result: 15 PASS / 5 FAIL.

- Already refused aloud ("Cannot finish operation because of too long name."): a.txt focused or
  selected in the 313-byte folder (225), the 274-byte name focused, a.txt + the long name
  selected through a batch file. The control row (a.txt in `s`) runs.
- **FPRCUT** - `$(FullPathRight)`, the right panel in the 260-byte folder: the command RAN with
  the folder's PARENT (`...\pc\ppp...\`) - the panel path cut at 259 bytes ended right after a
  backslash. A command acted on a cut path.
- **FPRLONG** - `$(FullPathRight)`, the right panel in the 313-byte folder: refused, but with
  "FullPathRight ... is not defined in this context (Find window or archive)" - a wrong reason.
- **MIXDIRECT** - a.txt and the long name selected, an item run without a shell: the command
  RAN for a.txt, then "too long name".
- **LISTFULL** - `$(ListOfSelectedFullNames)` over a.txt and the long name: "List of selected
  names with path is too long ... 32771 characters" - the list would hold them (the Find window
  builds the same list whole since 004).
- **CMPLONG** - `$(FileToCompareLeft)`, the long name focused: the compare-names dialog opened
  with empty names, without a word why.
- By reading: the enumeration (panel focus, panel selection, Find results) copies each item's
  folder and name cut at 259 bytes; only a later length check refuses the cut values.

## Clarifications

### Session 2026-10-21

- Q: Work or refuse - for an item (folder + name) that does not fit the User Menu's 259-byte
  expansion, on the panel and Find routes? → A: Refuse with "too long name" (as today), but from
  the whole values: the folder and the name reach the check uncut (autonomous run: item - Notes:
  "refuse may be the only option" for the batch route, cmd's current folder is limited to
  MAX_PATH; conservative - the same refusal on both routes, no new behaviour of launched programs)
- Q: An item run without a shell over several items, one of which is refused - may the items
  before it run? → A: No - the commands of all items are prepared first and run only when every
  item was prepared, as the batch route already does; a refusal comes before anything runs
  (autonomous run: item - Expected "refuses ... before anything runs")
- Q: `$(FullPathLeft)` / `$(FullPathRight)` / `$(FullPathInactive)` when the panel's folder +
  backslash does not fit 259 bytes? → A: Refuse with "too long name" when the command uses the
  variable (never a cut folder, never "not defined") (autonomous run: conservative - refuse,
  the same limit as the item's folder)
- Q: The names to compare (`$(FileToCompare...)`, `$(DirToCompare...)`, `$(FileOrDirToCompare...)`)
  when a name taken from the panels or Find results does not fit? → A: Refuse with "too long
  name" when the command uses the name, instead of the empty compare dialog; a name the command
  does not use (a file where it compares folders) is cleared as today (autonomous run:
  conservative - refuse; the dialog's fields hold 259 bytes)
- Q: `$(ListOfSelectedFullNames)` from the panel? → A: Work - the full names are built whole (the
  list holds up to 32771 bytes), as the Find window's route does since 004 (autonomous run:
  item - "work" where it costs nothing; the list's own limit and message stay)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - No command acts on a cut path (Priority: P1)

A user runs a User Menu item that uses the full path of a panel (`$(FullPathLeft)`,
`$(FullPathRight)`, `$(FullPathInactive)`) while that panel shows a folder of 260 or more bytes.

**Why this priority**: today the command can run on the folder's parent - another folder, a
data risk for a command that deletes, packs or moves.

**Independent Test**: probe rows FPRCUT and FPRLONG.

**Acceptance Scenarios**:

1. **Given** the right panel shows a 260-byte folder whose first 259 bytes end with a backslash,
   **When** the user runs an item with `$(FullPathRight)` from the left panel, **Then** "too long
   name" is shown and the command does not run.
2. **Given** the right panel shows a 313-byte folder, **When** the same item runs, **Then** "too
   long name" is shown (not "not defined") and the command does not run.
3. **Given** the right panel shows a short folder, **When** the same item runs, **Then** the
   command gets that folder with a trailing backslash, as before.

### User Story 2 - A refusal comes before anything runs (Priority: P1)

A user selects several items, one of which has a full name of 260 or more bytes, and runs an
item that is started without a shell, once per item.

**Why this priority**: today the items before the long one run, then the refusal - half of an
operation done.

**Independent Test**: probe rows MIXDIRECT, MIXBAT, LNAME, LDIRFOCUS, LDIRSEL.

**Acceptance Scenarios**:

1. **Given** a.txt and a 274-byte name are selected, **When** an item with `$(FullName)` runs
   without a shell, **Then** "too long name" is shown and the command runs for no item.
2. **Given** the same selection, **When** the item runs through a batch file, **Then** the same
   (as today).
3. **Given** a folder of 313 bytes, **When** an item runs on a focused or selected item there,
   **Then** "too long name", nothing runs (as today).
4. **Given** only short items, **When** an item runs without a shell, **Then** every item's
   command runs, in order, as before.

### User Story 3 - The compare names and the full-name list (Priority: P2)

**Why this priority**: today the user gets an empty dialog without a reason, or a refusal of a
list that fits.

**Independent Test**: probe rows CMPLONG and LISTFULL.

**Acceptance Scenarios**:

1. **Given** a 274-byte name is focused, **When** an item with `$(FileToCompareLeft)` and
   `$(FileToCompareRight)` runs, **Then** "too long name" is shown, no compare dialog, nothing
   runs.
2. **Given** a.txt and a 274-byte name are selected in a short folder, **When** an item with
   `$(ListOfSelectedFullNames)` runs, **Then** the command gets both full names whole.

### Edge Cases

- A name to compare too long but cleared anyway (the command compares folders, the items are
  files): no refusal - the dialog asks for names as today.
- `$(FullPathInactive)` refers to the other panel's path - its own length decides.
- A Find result in a folder of 260 or more bytes: refused with "too long name" before anything
  runs (the Find route itself is driven by a person - a popup menu).
- An item with an up-dir focus or an empty panel in a 260+ byte folder: refused as 225 does.
- A panel path of exactly 259 bytes: `$(FullPathLeft)` needs 260 with its backslash - refused.
- Group commands (a list variable) use only the first item's folder and name; a long name of
  another selected item does not refuse them.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The User Menu's enumeration of items (panel focus, panel selection, Find results)
  MUST hand every item's folder and name on whole - never cut.
- **FR-002**: An item whose folder, or folder + name, does not fit the User Menu's 259-byte
  expansion MUST be refused with "too long name" before its command is prepared (feature 225's
  refusal of a panel with no name stays).
- **FR-003**: An item run without a shell MUST prepare the commands of all items first and run
  them only when every item was prepared; any refusal while preparing MUST leave every command
  unrun (as the batch route does).
- **FR-004**: `$(FullPathLeft)`, `$(FullPathRight)` and `$(FullPathInactive)` MUST never carry a
  cut folder: when the panel's folder + backslash does not fit, a command using the variable
  MUST be refused with "too long name"; "not defined" stays for an archive / file-system panel
  and the Find window.
- **FR-005**: A name to compare that does not fit MUST refuse a command that uses it with "too
  long name" before the compare dialog or the question "files or folders"; a cleared name keeps
  today's dialog.
- **FR-006**: The panel route's `$(ListOfSelectedFullNames)` MUST hold whole full names (the
  list's own size limit and message stay).
- **FR-007**: Every case with short folders and names MUST behave exactly as before (the
  control rows, features 225, 226, 229, 234 probes).

### Key Entities

- **User Menu item value**: a folder, name, panel path, compare name or list inserted into a
  command - whole, or the command is refused.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe `um280_probe.ps1`: 20 / 0 (against 15 / 5 on the build of d7405c6a; the
  rows FPRCUT, FPRLONG, MIXDIRECT, LISTFULL, CMPLONG FAIL before).
- **SC-002**: The probes of features 226, 229 and 234 keep their results after the change.
- **SC-003**: No User Menu route copies an item's folder or name, a panel path or a compare name
  cut (the cuts named in the item are gone, by reading).

## Assumptions

- Assumption (autonomous run): no new UI strings - every refusal reuses "Cannot finish
  operation because of too long name." (`IDS_TOOLONGNAME`).
- Assumption (autonomous run): the internal enumeration contract of the User Menu (not part of
  the plug-in interface) may change.
- The Find window's route is driven by a person (`user-menu-find-route-person`); the probe drives
  the panel routes.
- The fixture's `%TEMP%` has no spaces (the full-name list quotes names with spaces).
