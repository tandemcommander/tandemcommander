# Feature Specification: a name is not cut at a byte position

**Feature Branch**: `137-names-cut-at-byte`
**Created**: 2026-10-13
**Status**: Implemented
**Input**: The maintainer: "fix what you can" - the points named as substantial after the two
critical ones: "FTP automatic rename and Quick Rename in the core work with a shortened name.
The file gets another name than it should; nothing is deleted. In every release so far."
Both are recorded in `specs/NEXT-WORK.md` (left by 131), seen by reading, not measured.

## User Scenarios & Testing

### User Story 1 - Quick Rename on a server never renames to a name the user did not type (Priority: P1)

On an FTP / SFTP panel the user renames a file and types a long name (about 90 Chinese or 130
accented letters and more). The program handed the plug-in the first 259 bytes of it - a name
that ends in the middle of the text, possibly in the middle of a letter - and the file on the
server got that name. Now the user is told the name is too long and nothing is renamed.

**Why this priority**: an operation on another machine carried out with a name that was never
typed; with a letter torn in half the server stores a name that is not valid text.

**Independent Test**: against the SFTP test container: Quick Rename to a name of 100 Chinese
letters; the server's directory is read afterwards.

**Acceptance Scenarios**:

1. **Given** a typed name longer than the plug-in interface can carry, **When** OK is pressed,
   **Then** a message says the name is too long, the dialog stays with the typed text, and the
   file on the server keeps its name.
2. **Given** a typed name of 250 letters that fits, **Then** the file is renamed to all of it.

### User Story 2 - FTP's automatic rename shortens a name at a whole letter (Priority: P2)

Downloading into a deep local folder with "if the file cannot be created: rename
automatically": when folder and name together are too long the FTP client shortens the name so
that it fits. It cut at a byte position; a name with accented or Asian letters was cut inside a
letter, the result was not a valid name and the file could not be created at all. Now the cut
falls between letters and the file is created under the shortened name.

**Independent Test**: unit checks of the cut; in the program a download of a file with an
accented name into a folder whose path leaves room for only part of the name.

### Edge Cases

- A name that fits exactly; one byte more.
- The cut position falls on the first byte, the middle or the last byte of a multi-byte letter.
- A name of ASCII letters only: unchanged behaviour.

## Requirements

- **FR-001**: Both defects MUST be reproduced on the build before (or shown unreachable, and
  recorded so).
- **FR-002**: Quick Rename on a plug-in file system MUST refuse a typed name that does not fit
  what the plug-in receives (existing "name too long" text), without calling the plug-in.
- **FR-003**: Where the FTP client shortens a name by design, the shortened name MUST be valid
  text (cut at a whole character).
- **FR-004**: No new texts for translation; no change of the plug-in interface.

## Success Criteria

- **SC-001**: After Quick Rename with a name that does not fit, the server holds exactly the
  names it held before (measured on the server); before the fix it holds a cut name.
- **SC-002**: Unit checks of the whole-character cut pass for 1- to 4-byte characters at every
  cut position.
- **SC-003**: The regression probes of SFTP (133) and FTP (134 / 136) pass.

## Assumptions

- The limit itself (259 bytes of a name through the plug-in interface; 259 bytes of a local
  path in the FTP client) is not changed here - it is the interface's and the plug-in's own.
