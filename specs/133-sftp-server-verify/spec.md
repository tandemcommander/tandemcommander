# Feature Specification: SFTP checked against a server; a listing that ends early is an error

**Feature Branch**: `133-sftp-server-verify`
**Created**: 2026-10-13
**Status**: Implemented
**Input**: The maintainer: "do all four, one after another" - point 2 of the recommendation
after feature 131: "Verify SFTP against a server. The fixes of 131 touch delete and move, and
exactly those were not run in the program, only in tests and review. While there, measure the
silent end of a directory listing: a move with an incomplete listing is the second place where
data may be at stake."

## User Scenarios & Testing

### User Story 1 - What 131 changed in SFTP is seen working against a real server (Priority: P1)

Feature 131 made every SFTP path join refuse instead of cutting, and made every failed
operation show the server's own reason. None of it was run in the program (the test server was
not running). The rows written down by 131 (`specs/131-plugin-defect-batch/items/sftp.md`,
R1-R5 and P1-P5) are driven in the program against the test server, on the build before 131's
SFTP changes (0.1.9) and on the current one.

**Why this priority**: delete and move on a remote server cannot be undone; a fix that was only
read is not a fix yet.

**Independent Test**: the probe of this feature on the hidden desktop against the container
`tandem-sftp` (`localhost:2222`).

**Acceptance Scenarios**:

1. **Given** a directory the user may not write to, **When** a file in it is deleted, a
   directory is created in it or a file is uploaded into it, **Then** the message ends with the
   server's reason ("Permission denied"), not with nothing and not with an earlier reason.
2. **Given** a file the user may not read, **When** it is downloaded, **Then** the same.
3. **Given** a remote tree whose deepest files have paths beyond the plug-in's 4,095 bytes,
   **When** the tree is deleted, **Then** the user is told the path is too long, **nothing is
   asked of the server under a shortened path**, and the files are still on the server.
4. **Given** the same tree, **When** it is downloaded or moved, **Then** nothing is stored
   under a shortened name and a move deletes nothing on the server.
5. **Given** a link to a directory about 2,900 bytes deep, **When** the user enters it, creates
   a directory and renames a file there, **Then** the names are whole.

### User Story 2 - A listing that did not reach its end is not a listing (Priority: P1)

When reading a remote directory stops before its end - the server or the connection reports an
error in the middle, a name does not fit, memory runs out - the plug-in treats what it has as
the whole directory. The panel shows a partial directory as complete, and a recursive download
"succeeds" with part of the files. The user is told the directory could not be read; a download
or move of it ends as failed; the panel does not show a partial directory.

*Corrected while planning (read, to be confirmed by the probe)*: the recommendation said a move
would then delete files that were never downloaded. It does not: a move deletes only the
top-level items it transferred, and for a directory only tries to remove the (still full)
directory itself. So nothing is lost on the server - the harm is a copy the user believes
complete. The probe also records what a move of a directory really leaves on the server.

**Why this priority**: an incomplete copy reported as complete is how files get lost one step
later (the user deletes the source).

**Independent Test**: unit checks of the decision "end of directory / error / stop asked by the
user"; in the program a debug-only seam that makes the Nth read of a listing fail, with a move
of a directory: the source must be complete on the server afterwards.

**Acceptance Scenarios**:

1. **Given** a directory whose listing fails after some entries, **When** the directory is
   copied or moved to the local disk, **Then** an error names the directory and the reason, the
   operation ends as failed, and every file is still on the server.
2. **Given** the same, **When** the user enters the directory in the panel, **Then** an error
   is shown instead of a partial list.
3. **Given** the user presses Close / Cancel while a large listing is read, **Then** the
   operation stops as cancelled (as before) - not as an error and not as success.

### Edge Cases

- An empty directory and a directory whose only entries are `.` and `..` are complete.
- The test server is Linux: no name there can be longer than 255 bytes, so "a name that does
  not fit 2,047 bytes" is reachable only with other servers - covered by the unit checks and the
  seam, recorded as not measured against a real server.
- Rows that need the keyboard of a real desktop are recorded as not driven.

## Requirements

- **FR-001**: The rows R1-R5 and P1-P5 of feature 131 MUST be driven in the program against
  the test server, each with its result on 0.1.9 and on the current build, or recorded as not
  driven with the reason.
- **FR-002**: A defect these rows show MUST be fixed in this feature when it is in the code 131
  touched; anything else goes to `specs/NEXT-WORK.md`.
- **FR-003**: Reading a directory MUST report failure unless the server said "end of
  directory"; the reason is the server's or the connection's own.
- **FR-004**: After a failed listing no remote file or directory of that tree MUST be deleted
  by the same operation, and a transfer of it MUST end as failed.
- **FR-005**: A stop asked by the user stays a cancel.
- **FR-006**: No new texts for translation; no change of the plug-in interface; the product's
  registry key is restored after every run; nothing but the test container is contacted.

## Success Criteria

- **SC-001**: Every row of FR-001 has a verdict with the text or the state of the server that
  proves it; no row ends with a file missing on the server that the user did not ask to delete.
- **SC-002**: With the Nth read of a listing failing, a copy of a directory ends with an error
  that names the directory (before the fix: no message, part of the files) and the server's
  directory is complete after a move (compared file by file, before and after the fix).
- **SC-003**: Unit checks pass; the plug-in's own harness passes; regression probes of 130 and
  131 pass.

## Assumptions

- The test server is the local container described in the session's environment notes
  (`tandem-sftp`, user `tctest`); the probe creates and removes its own directory there.
- The seam is compiled only into debug builds and reads an environment variable, like the
  seams of features 111 and 125.
- The other SFTP notes left by 131 (deep recursion and the stack, no panel refresh after a
  partly failed move, untranslated English texts) are not part of this feature unless a row
  shows them to be reachable defects.
