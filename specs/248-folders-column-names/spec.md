# Feature Specification: Desktop view column headers show the shell's names correctly

**Feature Branch**: `248-folders-column-names`
**Created**: 2026-10-19
**Status**: Draft
**Input**: Backlog item `drobna-chyba-textu-v-hlavicce-pro-zobrazeni-plochy-v-cestine` (GitHub issue #13): "Desktop view (Folders plug-in) column headers show mojibake for accented names". From backlog item drobna-chyba-textu-v-hlavicce-pro-zobrazeni-plochy-v-cestine.

## Clarifications

### Session 2026-10-19

- Q: How is a character of a shell column name that the Windows code page cannot represent shown - as a lookalike letter (best-fit) or as the replacement mark? → A: the replacement mark, no best-fit (autonomous run: item - "a character outside the code page is not shown" - and conservative)
- Q: What happens to a shell column name that does not fit the column-name field? → A: it is shortened at a whole character (never half a surrogate pair, never half a double-byte character), never left empty - revised after the first review: `CColumn::Name` "must not contain an empty string" (`spl_com.h`) and CLAUDE.md says a text that must be shortened is cut at a whole character (autonomous run: rule; the first answer, "empty as today", was conservative and is replaced)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Readable column headers in the Desktop view (Priority: P1)

A user of a non-English Windows (here Czech) opens the Desktop view (`fld:`, the Folders
plug-in) in the Detailed view. The column headers that come from the shell read exactly as
Windows names them ("Typ položky", "Datum změny"), like the program's own headers ("Název",
"Velikost") next to them - not "Typ poloĹľky" / "Datum zmÄ›ny".

**Why this priority**: it is the whole defect reported in issue #13; every user of a Windows
whose shell column names hold non-ASCII letters sees it.

**Independent Test**: on a Czech Windows, open `fld:` in the Detailed view and read the header
line: every column name equals the shell's name for that column.

**Acceptance Scenarios**:

1. **Given** a Czech Windows (code page 1250) and the Detailed view, **When** the panel shows
   `fld:` (the Desktop), **Then** the headers read "Typ položky" and "Datum změny".
2. **Given** the same panel, **When** the user looks at the cells ("Složka souborů") and the
   program's own headers ("Název", "Velikost"), **Then** they are unchanged (still right).
3. **Given** an English Windows, **When** the panel shows `fld:`, **Then** the headers read as
   before ("Item type", "Date modified").

### Edge Cases

- A shell column name holds a character the Windows code page cannot represent: that character
  is not shown faithfully in the header (it becomes the code page's replacement mark), as for
  any other column name; the rest of the name is right.
- A shell column name too long for the column-name field: shortened at a whole character, never
  empty (before this feature such a name - e.g. 10+ CJK characters as UTF-8 - left the header
  empty); a surrogate pair torn by the 29-unit read is dropped whole.
- Sorting by a plug-in column, the header's context menu and column widths are not affected:
  they do not use the column's name text, only its measurement for the width (which then
  measures the right text).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Folders plug-in MUST hand the shell's column names to the program in the
  Windows code page (the encoding the program's header line draws in), so that the Desktop view's
  header shows them correctly in every Windows language.
- **FR-002**: The cell texts of the Desktop view MUST stay as they are (UTF-8, plug-in interface
  104).
- **FR-003**: The plug-in interface (its headers, `LAST_VERSION_OF_SALAMANDER`) and the program
  core MUST NOT change.
- **FR-004**: A character outside the code page MUST NOT be replaced by a different-looking
  letter of the code page (no best-fit lookalike); it shows as the code page's replacement mark.
- **FR-005**: A name too long for the column-name field MUST be shortened at a whole character
  (never half a surrogate pair or a double-byte character) and MUST NOT become empty.

### Key Entities

- **Shell column name**: the text Windows gives for a column of a shell folder (language of
  Windows), shown as a header of the Desktop view.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On this cs-CZ machine, all shell column headers of `fld:` with accented letters
  (2 of the 4 default columns) read correctly in the header line (probe: before FAIL, after PASS).
- **SC-002**: The headers and cells that were right before stay right (probe rows NAME and
  CELLS pass before and after), and the program ends cleanly (exit code 0, no report).
- **SC-003**: No behaviour change outside the Folders plug-in (the diff touches
  `src/plugins/folders/`, the plug-in-usable rule `src/common/salcpfit.h` and its checks in
  `saltests`, plus records).

## Assumptions

- Assumption (autonomous run): every core reader of a column's name treats it as code page - the
  header line's painting and width measurement (`filesbx2.cpp`); the header context menu, sorting
  and the view configuration use the column's ID, not its name (enumerated at 7f37ec00; item
  *Approach*).
- Assumption (autonomous run): "a character outside the code page is not shown" (item *Approach*)
  is implemented without best-fit mapping - a lookalike letter would show a different word
  (conservative; the project's stance on best-fit, CLAUDE.md, 104).
- Assumption (autonomous run): a too-long name is cut at a whole character (rule: CLAUDE.md 097 /
  098 / 101 and the interface's "must not be empty"; see Clarifications).
- The GUI check needs the program not to run elsewhere on the machine (shared settings); when the
  maintainer's instance runs, the probe is owed to a person.
