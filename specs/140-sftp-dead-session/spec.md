# Feature Specification: SFTP - a lost connection stops the operation; special files are not downloaded; failed attribute changes are said

**Feature Branch**: `140-sftp-dead-session`
**Created**: 2026-10-14
**Status**: Draft
**Input**: The maintainer: "queue the medium and critical problems you meet and fix them through
the Spec Kit flow." Left by the final independent review of the SFTP operations (2026-10-13)
after feature 139; all three older than this cycle (present in 0.1.9):

- **medium**: after a timeout or a transport error the operation goes on with the next item.
  The library then answers the next request of the same kind with the reply that belonged to
  the earlier one - the content of file A can arrive under the name of file B, a "not found"
  for one path can be read as the answer for another.
- **medium**: an item that is not a regular file (a device such as `/dev/zero`, a FIFO, a
  socket) is downloaded like a file: without an end, or the open never returns.
- **medium**: Change Attributes (and Change Owner) report nothing when the server refuses: the
  failures go to the log only and the command looks successful.

## User Scenarios & Testing

### User Story 1 - A lost connection ends the operation, once (Priority: P1)

When the connection times out or breaks in the middle of a copy, move, delete or attribute
change, the operation stops there: nothing more is asked of the server on that connection, no
further item is touched, and the user sees one message that the connection was lost - not one
box per remaining file.

**Why this priority**: going on is the dangerous part - answers are mismatched with requests
afterwards, and a move or delete acts on what such an answer says.

**Independent Test**: a directory of 30 files; the test seam makes the request for the tenth
file end as a timeout. Copy: nine local files, one message, the program ends cleanly. Delete:
at least 21 files still on the server, one message.

**Acceptance Scenarios**:

1. **Given** a timeout at the tenth of 30 files in a download, **Then** no later file is
   requested, at most the files before it are local, and one message names the lost connection.
2. **Given** the same in a delete, **Then** the later files are still on the server.
3. **Given** the same in a move, **Then** nothing is removed from the source side after the
   timeout.
4. **Given** a dead connection, **When** the user starts another operation, **Then** the
   existing "reconnect?" route is offered as before.

### User Story 2 - Only regular files are downloaded as files (Priority: P1)

An item the server reports as a device, FIFO or socket - also behind a symbolic link - is not
opened: the user is told it is not a regular file and the operation goes on with the rest. A
move leaves it on the server.

**Independent Test**: a directory with a link to `/dev/zero` and a FIFO: copying each ends at
once with a message, no local file grows, the program stays responsive.

### User Story 3 - A refused attribute change is said (Priority: P2)

Change Attributes and Change Owner tell the user when the server refused: one message for the
operation with the first refused item and its reason, and how many were refused; the details
stay in the log.

### Edge Cases

- A server that reports no file type: the download proceeds as before (nothing to decide by).
- A timeout while closing a handle; while listing a directory in the middle of a tree.
- Cancel by the user is not a lost connection: no message.

## Requirements

- **FR-001**: After a request ended with a timeout or transport error, no further request MUST
  be sent on that connection by the running operation, and no item MUST be modified or removed
  on either side on the strength of anything read afterwards.
- **FR-002**: The lost connection MUST be reported once per operation.
- **FR-003**: A remote item known not to be a regular file or directory MUST NOT be opened for
  a download; it MUST be reported and left in place.
- **FR-004**: A refused attribute or owner change MUST be reported to the user (once per
  operation, with the reason of the first and the count).
- **FR-005**: No new texts for translation; no interface change; the behaviour of a healthy
  connection is unchanged.

## Success Criteria

- **SC-001**: The probe rows end with the server's and the disk's state as stated; the earlier
  rows of the SFTP probe still pass.
- **SC-002**: A download of a link to `/dev/zero` ends within seconds with a message.

## Assumptions

- Which mode a recursive Change Attributes should give to directories as opposed to files is a
  design decision for the maintainer (it needs interface and texts) and is not part of this.
- The texts added are English, in the plug-in's existing style.
