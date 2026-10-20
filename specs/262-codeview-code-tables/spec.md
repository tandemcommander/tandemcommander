# Feature Specification: Code Viewer decodes single-byte files with the product's conversion tables

**Feature Branch**: `262-codeview-code-tables`
**Created**: 2026-10-20
**Status**: Draft
**Input**: Backlog item codeview-code-tables-for-single-byte-files: "Code Viewer reads single-byte files only in the system code page (no CP852 etc.)". From backlog item codeview-code-tables-for-single-byte-files.

The Code Viewer (the codeview plug-in, the default F3 viewer for source and text files) decodes a
file that has no BOM and is not UTF-8 or UTF-16 with the system code page only. The product's
conversion tables (`convert\<dir>\convert.cfg`: ISO-8859-2, CP852, MAC CE, KOI-8, ... - the list
the built-in viewer's *Convert* menu offers) are not available in it, and its Encoding menu (F8) is a
fixed list of five entries. A DOS CP852 or an ISO-8859-2 text on a CP1250 machine therefore shows
wrong letters and the user cannot fix that inside the Code Viewer (spec 070 FR-024, review F16).

Measured at `bf05ffc9` (machine code page 1250): the corpus file
`src/plugins/codeview/test/corpus/encodings/cp852.bat` shows
"Pý˘lię §luśouźkě k…ĺ Łpŕl Ô belsk‚ ˘dy" instead of "Příliš žluťoučký kůň úpěl ďábelské ódy";
`iso8859-2.ini` shows "Přílią ľlu»oučký" instead of "Příliš žluťoučký".

## Clarifications

### Session 2026-10-20

- Q: How is the table list presented? → A: In the existing Encoding menu: its five entries stay first, then a separator, then every conversion table in the built-in viewer's order and grouping (its separators included, names with their menu hot-keys); F8 / Shift+F8 cycle through the five entries and all tables (autonomous run: item)
- Q: How is a table applied? → A: Exactly as the built-in viewer shows it: every byte goes through the 256-byte table and the result is read in the system code page; the status bar names the table (autonomous run: item)
- Q: How is the choice remembered? → A: The chosen table's name is kept in the Code Viewer's own settings - the counterpart of the built-in viewer's remembered default conversion - and is applied to every later file the Code Viewer reads as single-byte; choosing *System code page* forgets it; without a remembered table (the default) the Code Viewer behaves exactly as today (autonomous run: item + conservative)
- Q: Should the Code Viewer recognize the code page automatically (the built-in viewer's *Auto-Select*) or offer a separate *Set as default* command? → A: No - both need new UI strings (a translation refresh a run cannot do) and automatic recognition would change files that decode correctly today; recorded as a leftover backlog item (autonomous run: conservative)
- Q: When a table is chosen in one Code Viewer window, do other open Code Viewer windows re-decode their files? → A: No - they keep what they show; the remembered table applies to files opened (or re-opened by next / previous file) afterwards (autonomous run: conservative)
- Q: Which Encoding menu entry is checked when a remembered table decoded the file without the user choosing it now? → A: The table's entry, and the status bar names it - the menu always shows how the open file was decoded (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Read a single-byte file in another code page (Priority: P1)

A user on a CP1250 machine opens a DOS batch file written in CP852 with F3. The Code Viewer shows
wrong letters. The user opens *View > Encoding*, picks *CP852 - CP1250*, and the file is shown
with the right letters; the status bar names the table.

**Why this priority**: this is the whole gap - without it the only way to read such a file is the
built-in viewer.

**Independent Test**: open `cp852.bat` and `iso8859-2.ini` from the codeview corpus, choose the
matching table, read the first line.

**Acceptance Scenarios**:

1. **Given** `cp852.bat` open in the Code Viewer, **When** the user chooses *CP852 - CP1250*,
   **Then** the first line reads "Příliš žluťoučký kůň úpěl ďábelské ódy" and the status bar shows
   "CP852 - CP1250".
2. **Given** `iso8859-2.ini` open, **When** the user chooses *ISO-8859-2 - CP1250*, **Then** the
   first line reads "Příliš žluťoučký kůň úpěl ďábelské ódy".
3. **Given** a table is chosen, **When** the user presses F8 or Shift+F8, **Then** the next or
   previous entry of the whole list (five entries, then the tables) is applied.

---

### User Story 2 - The choice is remembered (Priority: P2)

The user who chose *CP852 - CP1250* for one file opens another single-byte file (also after
restarting the program). It is shown through CP852 - CP1250 again, as the built-in viewer applies
its remembered default conversion. Choosing *System code page* returns to today's behaviour.

**Why this priority**: the item asks for the choice to be remembered; a user with many DOS files
should not pick the table for every file.

**Independent Test**: choose a table, close the viewer, open another single-byte file; then choose
*System code page* and open it again.

**Acceptance Scenarios**:

1. **Given** the user chose *CP852 - CP1250*, **When** another file without BOM that is not UTF-8
   or UTF-16 is opened, **Then** it is decoded with CP852 - CP1250 and the status bar says so.
2. **Given** a remembered table, **When** a UTF-8, UTF-8 with BOM or UTF-16 file is opened,
   **Then** it is decoded exactly as today (the table plays no role).
3. **Given** a remembered table, **When** the user chooses *System code page*, **Then** the open
   file is decoded with the system code page and later single-byte files are too.

---

### User Story 3 - Nothing changes for files that work today (Priority: P1)

A user who never chooses a table sees every file exactly as before: UTF-8, UTF-8 with BOM,
UTF-16 LE/BE and system-code-page files decode the same, the five menu entries do what they did.

**Why this priority**: the item requires it; the Encoding menu that works today must not break.

**Independent Test**: the codeview corpus files and the unit checks of the decode rule with no
table chosen.

**Acceptance Scenarios**:

1. **Given** default settings (no remembered table), **When** any corpus file is opened, **Then**
   it decodes to the same text as at `bf05ffc9`.
2. **Given** any file, **When** the user chooses one of the five entries, **Then** the result is
   the same as at `bf05ffc9`.

### Edge Cases

- The remembered table name no longer exists (another conversion directory, an edited
  `convert.cfg`): the file is decoded with the system code page, as the built-in viewer does with a
  default it cannot find; the status bar shows the system code page.
- The conversion tables cannot be loaded at all: the menu shows the five entries only; F8 cycles
  through those five as today.
- A table whose target is not the Windows code page (e.g. *CP1250 - CP852*, *... - ASCII*):
  offered and applied like in the built-in viewer (bytes through the table, then the system code
  page), even though the result is meant for another code page.
- A table name with `&` (menu hot-key): shown with the hot-key in the menu and without the `&` in
  the status bar.
- A file of the viewer's maximum size: the table pass must not need more than one extra copy of the
  file's bytes.
- A choice of table on a file that is UTF-8 or UTF-16: the table is applied to the raw bytes (the
  user forced it), exactly as a forced *System code page* reads them today.
- Re-reading fails after a choice (file vanished): the open view keeps its text and its previous
  encoding, and the remembered table is not changed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Encoding menu MUST list, after its five existing entries and a separator, every
  conversion table the built-in viewer's *Convert* menu lists, in the same order, with the same
  separators and names.
- **FR-002**: Choosing a table MUST re-decode the open file: each byte replaced by the table's byte,
  the result read in the system code page; the menu MUST check the entry that decoded the open file
  (also when a remembered table was applied automatically) and the status bar MUST name the table
  (without `&`).
- **FR-003**: F8 / Shift+F8 MUST cycle through the five entries and all tables (separators
  skipped), wrapping around.
- **FR-004**: The chosen table's name MUST be kept in the Code Viewer's settings and survive a
  restart; choosing *System code page* MUST clear it; choosing UTF-8 / UTF-8 with BOM /
  UTF-16 LE / UTF-16 BE MUST leave it unchanged.
- **FR-005**: A file the Code Viewer detects as single-byte (no BOM, not UTF-16, not valid UTF-8)
  MUST be decoded with the remembered table when one is kept and found; otherwise with the system
  code page, as today.
- **FR-006**: With no remembered table, every file MUST decode exactly as at `bf05ffc9`; the five
  entries MUST keep their behaviour.
- **FR-007**: Table names MUST be handled as the code-page bytes the product hands to plug-ins
  (the `CCodeTablesData::Name` invariant, feature 069 B-5): stored and looked up byte for byte, and
  converted to wide text only for display, with the system code page.
- **FR-008**: The feature MUST NOT change the plug-in interface, add UI strings, or change what
  the core stores.
- **FR-009**: A failed re-read after a choice MUST keep the open view, its encoding and the
  remembered table as they were.
- **FR-010**: Choosing a table in one window MUST NOT re-decode files open in other Code Viewer
  windows; they pick up the remembered table only when they open (or move to) another file.

### Key Entities

- **Conversion table**: a named 256-byte mapping from `convert.cfg`; name in code-page bytes, may
  contain `&`; a NULL name is a menu separator.
- **Remembered table**: one table name in the Code Viewer's settings, or empty (= system code page).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `cp852.bat` and `iso8859-2.ini` read "Příliš žluťoučký kůň úpěl ďábelské ódy" after
  choosing the matching table (0 wrong letters in the first line).
- **SC-002**: With no table chosen, every file of the codeview encoding corpus decodes to the same
  text as before the change (unit checks).
- **SC-003**: The Encoding menu offers as many tables as the built-in viewer's *Convert* menu (all
  of them for the active conversion directory).
- **SC-004**: A chosen table is applied to the next single-byte file without the user choosing it
  again, also after a restart.

## Assumptions

- Assumption (autonomous run): the built-in viewer draws a converted file with the ANSI font in
  the system code page; the Code Viewer reads the converted bytes with the system code page to
  give the same letters.
- Assumption (autonomous run): the existing plug-in services `EnumConversionTables` and
  `GetConversionTable` are used unchanged; the decision item `plugin-ansi-services-interface-decision`
  is not answered here.
- Assumption (autonomous run): the Code Viewer setting is one more value under the plug-in's own
  settings key, like dbviewer's "Default Coding"; `PRIVACY.md` already says the settings of each
  plug-in are stored there, so no public claim changes.
- Out of scope: automatic code-page recognition and an explicit *Set as default* command (leftover
  item); changing the built-in viewer.
