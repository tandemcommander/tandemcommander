# Feature Specification: SFTP - a folder uploaded again into an upload-only folder

**Feature Branch**: `279-sftp-drop-folder-again`  
**Created**: 2026-10-21  
**Status**: Draft  
**Input**: User description: "Backlog item sftp-a-folder-uploaded-again-into-an-upload-only-folder - implement exactly what it describes: a folder uploaded again into a drop folder sends its files (each by exclusive create), or says clearly that the server does not show whether the folder exists; a Move removes a local folder only when something of it was shown to arrive." From backlog item sftp-a-folder-uploaded-again-into-an-upload-only-folder.

## Measured before (3541e7ad)

- Debug build of 3541e7ad, feature 258's probe on the hidden desktop (`-Only DROPDIR,DROPHOLE,DROPDIR2`,
  test server `dropsftp.py`): the first upload of a folder into `/drop` arrives (DROPDIR).
- A Move of the folder `pack2` (with `c.txt`) into `/drop` where `/drop/pack2` exists already:
  the server answers the folder's creation with FAILURE (it exists) and refuses to show it
  (`stat` DENIED); the box "Cannot create directory "/drop/pack2": SFTP error 4: Failure" and
  nothing of the folder is sent. The local files stay (DROPDIR2).
- A Move of an EMPTY folder `hole` onto `/drop/hole`, a file: the same box; the local folder
  stays (DROPHOLE - the case review 2 of 258 found deleted by a first attempt).

## Clarifications

### Session 2026-10-21

- Q: Is the box naming the folder shown also when every file of it already failed with a box of its own? → A: Yes - zero confirmed items always fail the folder with one box naming it (autonomous run: item - "zero confirmed (an empty folder, or every file failed) = the level fails with one box naming the folder")
- Q: Which refusals of a file's creation end the folder at once (no box for the file, the rest not tried)? → A: Only "no such file" and "no such path" - the folder is not there. A refusal for want of a right or because a file of that name exists stays the file's own failure, as for a file uploaded alone (autonomous run: item - Approach names "no such file / path"; a refusal for a right is what an upload-only service without the "overwrite" right answers for a file that is already there)
- Q: Does a subfolder count as "confirmed" for its parent? → A: Yes, when the server created it, showed it as a folder, or confirmed at least one item inside it - each proves that the parent is there (autonomous run: conservative - only what the server confirmed)
- Q: Does a "no such file / path" refusal still end an unconfirmed folder after one of its items was already confirmed? → A: No - only while nothing of the folder is confirmed; once an item is confirmed the folder is known to be there and a later refusal is that item's own failure with its own box, as in any folder (autonomous run: conservative - keeps today's per-file behaviour where the folder is known)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A folder uploaded again arrives (Priority: P1)

A user copies or moves a local folder into an upload-only ("drop") server folder into which
the same folder was uploaded before. The server refuses to create the folder (it is there)
and refuses to show it.

**Why this priority**: it is the function that fails (the item's severity 4).

**Independent Test**: probe row DROPDIR2 (Move) and DROPAGAIN (Copy with a file that is
already there and a new one) against the test server.

**Acceptance Scenarios**:

1. **Given** `/drop/pack2` exists on the server and the server will not show it, **When** the
   user moves the local folder `pack2` (with `c.txt`) into `/drop`, **Then** `c.txt` arrives in
   `/drop/pack2` by an exclusive create, the local `c.txt` and the local folder `pack2` are
   removed, and no error box is shown.
2. **Given** `/drop/pack3` exists with `old.txt` in it, **When** the user copies the local folder
   `pack3` (`old.txt`, `new.txt`) into `/drop`, **Then** `new.txt` arrives, the server's
   `old.txt` keeps its content, and one box says that `old.txt` was not replaced (as for a
   file uploaded alone into a drop folder).
3. The session log says that the folder could not be created, that the server does not show
   whether it exists, and that its files are tried.

### User Story 2 - Nothing confirmed: the local folder is kept (Priority: P1)

**Why this priority**: the first attempt (258, review 2 MUST-1) deleted a local folder although
nothing of it had reached the server. Data safety.

**Independent Test**: probe rows DROPHOLE, DROPEMPTY, DROPHOLE2, and the OpenSSH row OSSHLINK.

**Acceptance Scenarios**:

1. **Given** `/drop/hole` is a FILE, **When** the user moves an EMPTY local folder `hole` into
   `/drop`, **Then** one box names the folder `/drop/hole` and says that the server does not
   show whether the folder is there and nothing of it was confirmed; the local folder stays;
   the server's file is unchanged.
2. **Given** `/drop/empty` exists (the server will not show it), **When** the user moves an
   EMPTY local folder `empty` into `/drop`, **Then** the same: one box, the local folder stays
   (nothing of it was shown to arrive).
3. **Given** `/drop/hole2` is a FILE, **When** the user moves the local folder `hole2` with two
   files into `/drop`, **Then** the server is asked to create the first file only, the
   creation fails with "no such file", ONE box names the folder and says it is not there (no
   box per file), both local files and the folder stay.
4. **Given** plain OpenSSH and `/home/tctest/x`, a symbolic link into a folder the account
   cannot enter, **When** the user moves an EMPTY local folder `x` into `/home/tctest`, **Then**
   one box names the folder, the local folder stays.

### Edge Cases

- The folder's creation refused for want of a right, for no space, without any status, or on a
  lost connection: as before - the folder fails with its reason, nothing below is tried.
- The server shows the existing name: a folder - the content goes on (as before); not a folder -
  the folder fails with its reason (as before).
- Every item of an unconfirmed folder skipped (a local link folder): zero confirmed - the folder
  fails with its box and stays.
- A file confirmed, another file failed: the folder is not removed in a Move (as before: only a
  folder whose every item was moved is removed); no folder box (something was confirmed).
- A nested folder: an unconfirmed subfolder with a confirmed file confirms its parent; a
  subfolder whose creation is refused with "no such file / path" inside an unconfirmed folder
  ends that folder as a file would.
- The user stops the operation, or the connection is lost, inside an unconfirmed folder: no
  folder box (the stop / the one connection box of the operation), the local folder stays.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When the server refuses to create a folder of an upload with a status that can
  mean "a name is there" (FAILURE, FILE_ALREADY_EXISTS) and refuses to show that name for want of
  a right (a live session), the folder MUST be taken as "unconfirmed": its items are uploaded
  (a file by the route of 258 - the exclusive create where the server will not show the file).
- **FR-002**: Every other refusal of the folder's creation, and every answer of the server about
  the name, MUST keep today's behaviour.
- **FR-003**: An unconfirmed folder MUST count its confirmed items: a file whose upload the server
  confirmed complete (also when a Move could not remove the local file afterwards), a subfolder
  the server created or showed as a folder, a subfolder that is itself unconfirmed with at least
  one confirmed item.
- **FR-004**: An unconfirmed folder with zero confirmed items MUST fail with one box naming the
  folder: the server's reason for the refused creation, that the server does not show whether the
  folder is there, and that nothing of it was confirmed to arrive. A Move MUST keep the local
  folder and all it holds.
- **FR-005**: In an unconfirmed folder with no confirmed item yet, the first item whose creation
  the server refuses with "no such file" or "no such path" MUST end the folder: no box for that item, the remaining
  items not tried, one box naming the folder and saying that it is not there (a file could not
  be created in it).
- **FR-006**: A Move MUST remove the local folder of an unconfirmed folder only when at least one
  item was confirmed and every item was moved (today's rule for every folder, plus the count).
- **FR-007**: A stop by the user or a lost connection inside an unconfirmed folder MUST NOT add a
  folder box; the local folder stays.
- **FR-008**: The session log MUST record that a folder was taken as unconfirmed and why.

### Key Entities

- **Unconfirmed folder**: a folder of an upload whose creation the server refused in a way that
  allows "it is there" and whose existence it will not show; carries the count of confirmed items.
- **Confirmed item**: a file or subfolder whose arrival the server confirmed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe rows DROPDIR2 and DROPAGAIN pass (the files arrive), against a FAIL on the
  build of 3541e7ad for DROPDIR2.
- **SC-002**: Probe rows DROPHOLE, DROPEMPTY, DROPHOLE2 pass: in each, the local folder is kept
  and exactly one box names the folder (DROPHOLE2: the server log shows one file creation only).
- **SC-003**: Row OSSHLINK (real OpenSSH) passes: the local folder is kept, one box.
- **SC-004**: All other rows of 258's probe and 133's SFTP regression probe keep passing
  (258: 20 / 0; 133: 76 / 0).
- **SC-005**: The SFTP plug-in's rule harness passes with new checks for the decisions (which
  refusals make a folder unconfirmed, which end it, the verdict for zero confirmed items), each
  with negatives.

## Assumptions

- Assumption (autonomous run): no new UI strings - the folder box reuses the existing "Cannot
  create directory" text with an English reason, as 258 did for its reasons.
- Assumption (autonomous run): a create refused for want of a right inside an unconfirmed folder
  stays the file's own box (one per file) - on plain OpenSSH, a folder with files moved onto a
  symbolic link into an unreadable folder shows a box per file and then the folder box; the
  local folder and files stay. A recorded limit.
- The test server `dropsftp.py` is extended (a copy in this feature's probe folder) to answer a
  creation under a file with "no such file", as OpenSSH does (`ENOTDIR` -> NO_SUCH_FILE).
- Real OpenSSH rows run on the Docker container `tandem-sftp` (localhost:2222).
