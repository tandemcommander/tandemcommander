# Feature Specification: SFTP - a moved directory leaves the server, and only what was copied whole

**Feature Branch**: `138-sftp-move-directory`
**Created**: 2026-10-13
**Status**: Implemented
**Input**: The maintainer: "fix what you can" - from the points named as substantial: "SFTP
move of a directory leaves it on the server. It behaves safely, it just does not do what it
promises." Measured by feature 133 (row M1): after F6 on a directory of 30 files the 30 files
are on the local disk **and** all 30 and the directory are still on the server, without a word.

## User Scenarios & Testing

### User Story 1 - Move from the server moves a directory (Priority: P1)

The user moves a directory from an SFTP server to the local disk. Afterwards its files are on
the disk and the directory is gone from the server - as with a single file today.

**Why this priority**: the command says Move; a user who trusts it leaves copies on the server
(or deletes them by hand without knowing whether everything arrived).

**Independent Test**: the row M1 of the SFTP probe: after the move the directory is not on the
server and the local folder holds its 30 files.

**Acceptance Scenarios**:

1. **Given** a directory with files and sub-directories, **When** it is moved, **Then** every
   file is on the disk with its content and the whole tree is gone from the server.

### User Story 2 - Nothing is removed from the server that did not arrive whole (Priority: P1)

A file is removed from the server only after its local copy is complete: fully written, and
as long as the server says the file is. A file that was skipped, refused, could not be read or
ended early stays - and so does every directory above it. The user is told what could not be
removed.

**Why this priority**: this is the half that can lose data; a move must fail closed.

**Independent Test**: a directory with one unreadable file among readable ones: after the move
the readable files are local and gone from the server, the unreadable one and its directory
are still there, one message names the reason. A directory whose listing fails (the seam of
133): nothing is removed. A move stopped by the user: what was not yet copied stays.

**Acceptance Scenarios**:

1. **Given** one file of the tree cannot be downloaded, **Then** that file and the directories
   above it stay on the server; everything else is moved.
2. **Given** the local copy of a file is shorter or longer than the server's file, **Then** the
   server's file stays.
3. **Given** an existing local file and the answer "do not overwrite", **Then** the server's
   file stays.
4. **Given** a symbolic link to a directory (not followed by a download), **Then** the link
   stays.

### Edge Cases

- An empty directory: created locally, removed from the server.
- A file that cannot be removed from the server after a complete download (no permission): the
  local copy stays, the user is told, the directory above stays.
- Cancel in the middle.

## Requirements

- **FR-001**: A move from the server MUST remove each source file after - and only after - its
  local copy is complete, and each source directory after - and only after - everything in it
  was moved.
- **FR-002**: "Complete" MUST be decided from facts, not from the absence of an error: the
  local file is closed without error and its size equals the size the server reports for the
  source after the transfer.
- **FR-003**: A source that cannot be removed MUST be reported with the server's reason, and
  the operation MUST end as not fully successful.
- **FR-004**: Copy (without move) MUST be unchanged. No new texts for translation.

## Success Criteria

- **SC-001**: Row M1: the directory is gone from the server and 30 files are local.
- **SC-002**: A tree with an undownloadable file: that file and its parents remain on the
  server, the rest is gone; the local copies match what was removed, file by file.
- **SC-003**: The rows of 133 that must not delete (LISTMOVE, P5M) still leave everything on
  the server.

## Assumptions

- The upload direction (disk to server) already removes local sources after the upload and is
  not changed here.
- The size the server reports is taken as the measure of completeness; content is not
  compared (no checksum in the protocol).
