# Feature Specification: 7-Zip, TAR and SFTP listings declare case sensitivity

**Feature Branch**: `252-archive-case-sensitivity`
**Created**: 2026-10-20
**Status**: Draft
**Input**: Backlog item `archive-plugins-declare-case-sensitivity` - "7-Zip, TAR and SFTP do not
declare case-sensitive listings". From backlog item archive-plugins-declare-case-sensitivity.

## Background (measured at 1cc16d0e, by reading)

A listing tells the program whether "a.txt" and "A.txt" are two names. Only ZIP (archives made on
Unix) and FTP (always) say so. The 7-Zip plug-in (7z, rar), the TAR plug-in (tar, tgz, tbz, gz,
bz2, cpio, rpm, deb, ...) and SFTP never do, so the program treats their names case-insensitively:

1. Copying a.txt from such an archive through the clipboard (Paste) looks the name up again in the
   archive listing case-insensitively and takes the first match - A.txt can be extracted instead.
2. Reselect, Store / Restore Selection, Hide Selected Names and panel tabs take both twins for one.
3. While the archive tree is built, folders "D" and "d" are merged into one folder; the TAR plug-in
   then extracts by exact names, so copying that folder extracts only the "D" part and silently
   leaves the files of "d" behind.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The selected twin is the one copied out of an archive (Priority: P1)

A user opens a 7z or TAR archive that holds a.txt and A.txt (made on Linux or from a case-sensitive
Windows folder), selects one of them and copies it out (Paste, or Copy after Reselect / Restore
Selection / Hide Selected Names).

**Why this priority**: the wrong file's content arrives where the user expects the selected one.

**Independent Test**: a hidden-desktop probe with a TAR and a 7z fixture holding A.txt, a.txt and
z.txt: Hide Selected Names on one twin, Select All, Copy into a case-sensitive folder - only the
other twin and z.txt arrive; Store / Restore Selection of one twin, Copy - only that twin arrives.

**Acceptance Scenarios**:

1. **Given** a 7z / TAR archive holding A.txt and a.txt, **When** one twin is selected and its
   selection is stored and restored, **Then** only that twin is selected and copied.
2. **Given** the same archive, **When** one twin is hidden by Hide Selected Names, **Then** the other
   twin stays in the panel.
3. **Given** the same archive, **When** a.txt is copied by the clipboard and pasted, **Then** a.txt is
   extracted (person check: the clipboard route cannot be driven on the hidden desktop).

### User Story 2 - Folders differing only in case are two folders (Priority: P1)

**Why this priority**: today copying such a folder out of a TAR archive silently leaves files behind.

**Independent Test**: a TAR / 7z fixture with D/x.txt and d/y.txt: the panel shows two folders;
Select All, Copy into a case-sensitive folder: D\x.txt and d\y.txt both arrive.

**Acceptance Scenarios**:

1. **Given** an archive holding D/x.txt and d/y.txt, **When** it is listed, **Then** the panel shows
   folders D and d, each with its own file, and copying both extracts both files.

### User Story 3 - SFTP declares its case sensitivity (Priority: P2)

An SFTP listing is treated like an FTP listing: names that differ only in case are different names.

**Independent Test**: by reading (same declaration as FTP); a person check on the test server.

**Acceptance Scenarios**:

1. **Given** an SFTP folder holding a.txt and A.txt, **When** one is selected and Hide Selected
   Names is used, **Then** the other stays.

### User Story 4 - Ordinary archives behave as before (Priority: P1)

**Independent Test**: a TAR / 7z archive without case twins holding the folder Docs: entering
`<archive>\DOCS` (another case) still enters Docs.

**Acceptance Scenarios**:

1. **Given** an archive whose names never differ only in case, **When** it is used in any way,
   **Then** behaviour is unchanged (names compared case-insensitively, as before).

### Edge Cases

- A file and a folder whose names differ only in case in one folder: they are twins (the listing is
  case-sensitive).
- The same entry stored twice with identical bytes (an appended TAR update): not twins.
- Names that only the legacy byte fold or only the Unicode rule takes for equal: twins either way
  (each rule is used somewhere in the program).
- An empty archive, a single compressed stream (gz without tar): no twins.
- A listing that fails part-way: unchanged error handling.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A 7-Zip (7z, rar) or TAR-family archive listing that holds, in any folder, two names
  that differ only in case MUST be declared case-sensitive: the selected twin, and only it, is
  restored, hidden, copied and pasted; folders that differ only in case stay separate.
- **FR-002**: A 7-Zip or TAR-family listing without such names MUST behave exactly as before
  (case-insensitive).
- **FR-003**: SFTP listings MUST be declared case-sensitive (as FTP's are).
- **FR-004**: Extraction, listing contents and errors MUST otherwise stay unchanged; no plug-in
  interface change.
- **FR-005**: The rule "does this set of names hold case twins" MUST be a pure, unit-tested decision
  that agrees with both comparison rules the program uses for archive names.

### Key Entities

- **Case twins**: two names in one folder that are byte-different but that the program's
  case-insensitive comparison (the legacy byte fold or the file system's ordinal rule) takes for the
  same name.

## Success Criteria *(mandatory)*

- **SC-001**: In the probe, the twin rows (TAR and 7z: hide, store/restore, twin folders) fail before
  and pass after; the ordinary-archive control row passes before and after.
- **SC-002**: The unit checks of the twin rule pass, including names equal only by one of the rules.
- **SC-003**: No other behaviour of ordinary archives changes (control row, existing builds and
  tests green).
- **SC-004**: The archive data are read once per listing, as before (no second pass over a
  compressed TAR).

## Clarifications

### Session 2026-10-20

- Q: Should 7-Zip and TAR listings always be declared case-sensitive (as FTP), or only when they hold
  names that differ only in case? → A: only when the listing holds such twins; an archive without
  twins keeps today's case-insensitive behaviour (typing a path in another case still works there).
  Known change (review 252): an archive whose entries spell one folder in two cases ("Docs\a.txt",
  "DOCS\b.txt") holds twins by this rule - it now shows two folders, as its entries say, and its
  paths must be typed in their exact case. (autonomous run: conservative)
- Q: Should SFTP be declared case-sensitive always? → A: yes, always, as FTP is - the item names the
  exact site (`sftp/fs.cpp`). (autonomous run: item)
- Q: May finding twins read the archive a second time? → A: no - the archive is read once as
  today; the check works on the names already listed, its cost grows with the number of names only
  (sorting the names of each folder). (autonomous run: conservative)

## Assumptions

- Assumption (autonomous run): the ZIP plug-in's own rule (case-sensitive only for archives made on
  Unix) is out of scope; a Windows-made ZIP holding twins is recorded as a separate backlog item.
- Assumption (autonomous run): the clipboard Paste route and SFTP cannot be driven in this run (no
  clipboard on the hidden desktop; the SFTP test container is not running) - both are owed to a
  person; the shared mechanism (the panel's case sensitivity) is proven by the probe rows.
- The other places that take the first case-insensitive twin (backlog item
  `case-sensitive-twins-first-match`) are not part of this feature.
