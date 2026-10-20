# Feature Specification: A ZIP that holds names differing only in case is case-sensitive

**Feature Branch**: `271-zip-case-twins`
**Created**: 2026-10-20
**Status**: Draft
**Input**: Backlog item `a-zip-made-on-windows-that-holds-names-differing-only-in` - "A ZIP made on
Windows that holds names differing only in case is not case-sensitive". From backlog item a-zip-made-on-windows-that-holds-names-differing-only-in.

## Background (measured at 671ae06b)

A listing tells the program whether "a.txt" and "A.txt" are two names. The ZIP plug-in says so only
when an entry of the archive was made on Unix. Feature 252 made 7-Zip and TAR listings
case-sensitive when they hold names that differ only in case ("case twins") and left ZIP's rule as
it was. A ZIP made on Windows from a case-sensitive folder (WSL, `fsutil file setCaseSensitiveInfo`,
.NET `ZipArchive`) holds twins without any Unix entry, so:

1. Hide Selected Names on one twin hides both; Store / Restore Selection (and Reselect, tabs) of one
   twin selects both; Paste looks the name up case-insensitively (probe rows ZIP-HIDE, ZIP-GLOBAL).
2. Folders "D" and "d" are shown as one folder; copying or deleting it acts on both (ZIP-ONE,
   ZIP-DEL).

The plug-in's own operations (copy out, delete, view one file) decide case sensitivity from the
SELECTED items: a folder that has no entry of its own in the archive carries no such information and
is matched case-insensitively. Measured: in a Unix-made ZIP (already listed case-sensitively, two
folders D and d shown), copying only folder "d" also extracted D/x.txt, and **deleting only folder
"d" also deleted D/x.txt** (UNIX-ONE, UNIX-DEL). Showing D and d apart for a Windows-made ZIP without
fixing this would turn the same defect on for it.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The selected twin is the one acted upon (Priority: P1)

A user opens a ZIP made on Windows that holds a.txt and A.txt, selects one of them and copies it out
(after Hide Selected Names, Store / Restore Selection, Reselect, or by the clipboard).

**Why this priority**: the other file's content arrives where the user expects the selected one, or
the selected file is hidden together with its twin.

**Independent Test**: hidden-desktop probe with a .NET-written ZIP (host MS-DOS / Windows) holding
A.txt, a.txt and z.txt: Hide Selected Names on one twin, Select All, Copy into a case-sensitive
folder - only the other twin and z.txt arrive, with their own content; Store / Restore Selection of
one twin, Copy - only that twin arrives.

**Acceptance Scenarios**:

1. **Given** a Windows-made ZIP holding A.txt and a.txt, **When** one twin's selection is stored and
   restored, **Then** only that twin is selected and copied.
2. **Given** the same archive, **When** one twin is hidden by Hide Selected Names, **Then** the other
   twin stays in the panel.
3. **Given** the same archive, **When** a.txt is copied by the clipboard and pasted, **Then** a.txt is
   extracted (person check: no clipboard on the hidden desktop).

### User Story 2 - Folders differing only in case are two folders, each acted upon alone (Priority: P1)

**Why this priority**: deleting one such folder deletes the other one's files - data loss, today in
Unix-made ZIPs and, once the folders are shown apart, in Windows-made ones.

**Independent Test**: ZIP fixtures (Windows host and Unix host) with D/x.txt and d/y.txt and no
folder entries: the panel shows two folders; Select All + Copy extracts D/x.txt and d/y.txt; copying
the first folder alone extracts only its file; deleting the first folder alone keeps the other
folder's entry in the archive.

**Acceptance Scenarios**:

1. **Given** a ZIP holding D/x.txt and d/y.txt, **When** it is listed, **Then** the panel shows
   folders D and d, each with its own file.
2. **Given** the same archive, **When** only one of the folders is copied out, **Then** only its files
   are extracted.
3. **Given** the same archive, **When** only one of the folders is deleted, **Then** the other
   folder's entries stay in the archive.

### User Story 3 - Ordinary ZIPs behave as before (Priority: P1)

**Independent Test**: a Windows-made ZIP without twins holding the folder Docs: opening
`<archive>\DOCS` (another case) still enters Docs.

**Acceptance Scenarios**:

1. **Given** a Windows-made ZIP whose names never differ only in case, **When** it is used in any
   way, **Then** behaviour is unchanged (names compared case-insensitively, as before).
2. **Given** a Unix-made ZIP, **When** it is listed, **Then** it is case-sensitive as before.

### Edge Cases

- A file and a folder whose names differ only in case in one folder: twins (the listing is
  case-sensitive).
- A folder that has its own entry and one that exists only through its files: both follow the
  listing's case sensitivity.
- Names equal only by the legacy byte fold or only by the Unicode rule: twins either way (252's rule).
- An empty ZIP, a damaged ZIP whose listing ends part-way: unchanged error handling; the twin check
  works on what was listed.
- Entries that spell one folder in two cases ("Docs/a.txt", "DOCS/b.txt"): twins by the rule - shown
  as two folders, as the entries say (the same known change as 252's for 7-Zip / TAR).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A ZIP listing that holds, in any folder, two names that differ only in case MUST be
  declared case-sensitive, whatever system made the archive: the selected twin, and only it, is
  restored, hidden, copied and pasted; folders that differ only in case stay separate.
- **FR-002**: A ZIP listing with a Unix-made entry MUST stay case-sensitive (the existing rule).
- **FR-003**: A ZIP listing without twins and without Unix entries MUST behave exactly as before
  (case-insensitive).
- **FR-004**: Copying out, moving out, deleting and viewing items of a ZIP MUST compare the archive's
  names with the same case sensitivity as the listing they were selected in - also for a folder that
  has no entry of its own in the archive - so that an operation on one twin never reaches the other.
- **FR-005**: No plug-in interface change; the twin rule is 252's unit-tested rule, reused.

### Key Entities

- **Case twins**: two byte-different names in one folder that the program's case-insensitive
  comparison (the legacy byte fold or the file system's ordinal rule) takes for the same name.
- **The listing's case sensitivity**: decided once per listing of the archive; the operations started
  from that listing use it.

## Success Criteria *(mandatory)*

- **SC-001**: In the probe, the twin rows (ZIP-HIDE, ZIP-GLOBAL, ZIP-ONE, ZIP-DEL, UNIX-ONE,
  UNIX-DEL) fail before and pass after; ZIP-CONTROL and ZIP-TREE pass before and after.
- **SC-002**: No other behaviour of ordinary ZIPs changes (control row, the build and saltests green).
- **SC-003**: Listing a ZIP reads its central directory no more often than before for archives
  without twins.

## Clarifications

### Session 2026-10-20

- Q: Should Windows-made ZIP listings always be case-sensitive, or only when they hold twins? → A:
  only when they hold twins (Unix-made ZIPs stay always case-sensitive) - the item's *Expected* and
  *Approach*, as 252 did for 7-Zip / TAR. (autonomous run: item)
- Q: Is fixing the copy / delete of a folder without its own entry in a Unix-made ZIP inside this
  item? → A: yes - it is the mechanism the item's listing change depends on (FR-004): showing D and d
  apart without it would make Delete of D silently delete d's files; the fix is one rule for both
  hosts. (autonomous run: rule - CLAUDE.md "Never lose the user's data")

## Assumptions

- Assumption (autonomous run): adding files INTO an existing ZIP that holds twins (Pack / Move into
  the archive, its overwrite questions) decides case sensitivity by its own read of the archive and
  has no listing to follow; it is outside this item and checked separately (recorded in the backlog
  if defective).
- Assumption (autonomous run): the clipboard Paste route cannot be driven on the hidden desktop; it
  shares the mechanism (the panel's case sensitivity) the probe rows prove and is owed to a person
  (the existing person step for 252's archives covers the check; ZIP is added to it).
- The 7-Zip, TAR and SFTP plug-ins are not changed.
