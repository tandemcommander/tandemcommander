# Feature Specification: defects found while fixing the plug-in messages

**Feature Branch**: `131-plugin-defect-batch`
**Created**: 2026-10-13
**Status**: Implemented
**Input**: The maintainer, after feature 130: "plan and carry out these points right after this
work: about twenty more defects were found on the way, for example cut paths in PictView and
SFTP, a buffer overrun in the File Comparator and a wrong Spanish translation in 7-Zip."
The list is in `specs/NEXT-WORK.md` (section D, under feature 130) and in the sections "Other
defects seen" of `specs/130-plugin-mixed-templates/triage/*.md`. They were seen by reading, not
measured.

## User Scenarios & Testing

### User Story 1 - A plug-in never works on a shortened path (Priority: P1)

A path or name that does not fit a plug-in's buffer was cut and the operation went on with the
cut text: an SFTP download written to another file, a remote delete or rename of another path,
an FTP rename to a cut name, a thumbnail written through a path without its end. The user is
told the path is too long and nothing is done on a wrong path.

**Independent Test**: unit checks of the path joins (exact fit, one byte over: refused, the
buffer empty); by hand against a server: an operation on a tree deeper than the buffer.

### User Story 2 - No crash or overrun from a typed or stored text (Priority: P1)

- A `%` in an FTP host name (`ftp://a%sb/`) was read as a printf directive of the error text:
  **the program crashed**.
- A ZIP self-extractor favourite whose name is longer than about 25 accented letters failed to
  load and was **deleted with its settings** at the next save of the configuration.
- A font name of 25 or more characters overran a 32-byte field in the File Comparator's
  configuration.
- DiskMap wrote past its text buffer when a text filled it exactly.

**Independent Test**: Change Directory to `ftp://tc131-%s-%d-%s.invalid/` - one message with the
host as typed (0.1.9: a crash report).

### User Story 3 - A message says the real reason (Priority: P2)

- SFTP: a failed delete, create, permission change ... showed no reason, or the reason of an
  earlier failure. It shows the server's own status now ("Permission denied").
- Renamer: "Duplicate name." was followed by the text of some earlier Windows error.
- Registry Editor: a broken regular expression in Find was followed by an unrelated Windows
  error text.
- 7-Zip: "Could not write N byte(s)" chose its plural form from an unwritten stack value.

### User Story 4 - Names and texts in the right encoding (Priority: P2)

- PictView *Update Thumbnail* could not open any file with an accented letter in its path.
- PE Viewer lost the rest of a line of the dump at a version-resource name with a letter above
  U+00FF.
- Undelete's virtual folders (`{Všechny vymazané soubory}`) were code-page text used as names.
- ZIP favourite names were code page in the session they were typed in and UTF-8 after a
  restart (a reloaded accented name was garbled in the list).
- Spanish 7-Zip said "El archivo '...' es Aceptar."; the "SFTP error N: text" sentence was
  mistranslated in seven languages (and is shown now).

### Edge Cases

- An item that turns out unreachable or no defect is recorded and left (FTP: the three most
  "serious" notes were of that kind - `char` is unsigned in every plug-in, the core limits a
  typed path).
- Favourite names stored by older versions still load.
- A `.set` file of the self-extractor written by hand in the code page still imports.

## Requirements

- **FR-001**: Each listed item MUST be measured first (real? reachable?) and its verdict
  recorded with evidence, per plug-in.
- **FR-002**: A path or name that does not fit MUST be refused (existing "too long" text) or
  held in a buffer that fits; an operation MUST NOT run on a shortened path. A refusal fails
  closed (a move deletes nothing).
- **FR-003**: No user-typed or server-sent text may act as a printf format.
- **FR-004**: An error message shows a Windows or server reason only when it belongs to that
  failure.
- **FR-005**: No new texts for translation; no change of the plug-in interface.

## Success Criteria

- **SC-001**: Every item has a record with its verdict (`items/*.md`).
- **SC-002**: The rows that can be driven without a server pass on the new build and fail on
  0.1.9; the regression probes of features 113, 117, 127, 129, 130 stay clean.
- **SC-003**: An independent review per group finds no blocker; its findings are fixed or
  recorded.
