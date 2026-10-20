# Feature Specification: SFTP upload into drop folders, the limits of a replacement, left temporary files

**Feature Branch**: `258-sftp-drop-folder-upload`  
**Created**: 2026-10-20  
**Status**: Draft  
**Input**: User description: "Backlog item sftp-replace-keeps-links-acls-drop-dirs - implement exactly what it describes: an upload into a write-only directory succeeds (or says why); the limits on hard links and ACLs are either handled or stated to the user; orphaned `.tcpart-*` files are found and offered for cleanup." From backlog item sftp-replace-keeps-links-acls-drop-dirs.

## Measured before (2807bbc4)

- A Unix write-only folder on OpenSSH (mode 0733 / 1733) already works: the server answers
  "no such file" for the target, lets the account create, examine and rename its own file.
- A server that refuses to tell anything about files in an upload-only folder (SFTPGo's
  "upload" without "list", hosted drop boxes; modelled by the probe's test server) makes every
  upload into that folder fail at once: `Cannot upload "/drop/up.txt": Permission denied.` -
  the plug-in cannot learn whether the target exists, and it refuses rather than risk a silent
  replacement. Nothing arrives; a Move keeps the local file.
- A replacement (temporary file + rename, feature 139) gives the file a new identity on the
  server: another hard link to the old file keeps the old content (measured on OpenSSH), and
  the old file's ACL and extended attributes are not carried (SFTP version 3 can neither read
  nor write them). The overwrite question does not say so.
- A connection lost at the end of an upload leaves the temporary file `.tcpart-XXXXXXXX` on the
  server; the box names it once and nothing ever offers to remove it.

## Clarifications

### Session 2026-10-20

- Q: When is the removal of left temporary files offered - only at the start of the next upload on the connection, or also when the panel reconnects or refreshes? → A: Only at the start of the next upload on that panel connection (no question inside a refresh or path change; the upload is the operation that left them) (autonomous run: conservative)
- Q: When an upload into a drop folder fails after the file was created under its name, does the plug-in try to remove the partial file? → A: Yes, once - the plug-in created it exclusively, it is no one else's; if the server refuses, the box says a partial file may stay under that name (autonomous run: conservative - no torso left silently)
- Q: Does the confirmation by the server's acknowledgments (size not reportable) apply only to the drop route or to every upload route? → A: To every route, only when the size request is refused with a permission status on a live session and every byte and the close were acknowledged; the route then goes on as before (a temporary file is still renamed) (autonomous run: item - "succeeds (or says why)")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Upload into a drop folder (Priority: P1)

A user copies or moves files (or a folder) into a server folder in which the server lets them
create files but refuses to show anything about the files there.

**Why this priority**: it is the function that fails (the item's severity 4); the others are
limits that must be stated.

**Independent Test**: probe rows DROPNEW, DROPEXIST, DROPMOVE, DROPDIR against the test server.

**Acceptance Scenarios**:

1. **Given** a drop folder without a file of that name, **When** the user copies a file into it,
   **Then** the file arrives with its whole content, no error is shown, and the session log
   says that the server did not let the plug-in examine the file and that it was created only
   because no file of that name existed.
2. **Given** a drop folder that already holds a file of that name, **When** the user copies a
   file of that name into it, **Then** the existing file is not touched and an error box says
   why (the server does not show whether a file of that name exists; it refused to create a new
   one).
3. **Given** a drop folder, **When** the user moves a file into it, **Then** the file arrives
   and the local source is removed - only after the server confirmed every byte.
4. **Given** a drop folder, **When** the user copies a local folder with files into it, **Then**
   the folder and its files arrive.

### User Story 2 - The limits of a replacement are stated (Priority: P2)

A user uploads a file over an existing server file and is asked whether to overwrite it.

**Why this priority**: the user decides at that question; without the statement a hard link
silently stops sharing the content and permissions beyond the mode bits are lost.

**Independent Test**: probe row REPL - the question's text.

**Acceptance Scenarios**:

1. **Given** an existing regular server file, **When** the overwrite question appears, **Then**
   it says that the file is replaced by a new copy, that other hard links to it keep the old
   content, and that its ACL and extended attributes are not carried over.
2. **Given** the user answers Yes, **Then** the replacement works as before (complete new
   content under the name, nothing else changed).

### User Story 3 - Left temporary files are offered for removal (Priority: P3)

A user's upload lost its connection after the temporary file was created; the user uploads
again over the same connection (after it was re-established).

**Why this priority**: the files take space and confuse a listing, but hold nothing the user
needs (the old file and the local source are intact).

**Independent Test**: probe row CUT.

**Acceptance Scenarios**:

1. **Given** an upload whose connection was lost and whose temporary file could therefore not
   be removed, **When** the user starts the next upload to that server in the same panel
   connection, **Then** a question lists the left temporary files and offers to delete them;
   Yes deletes them, No keeps them and does not ask about them again.
2. **Given** a temporary file that is the only complete copy of new content (the old file was
   already removed, feature 139), **Then** it is never offered for deletion.

### Edge Cases

- The server refuses to show the target for another reason than permission (timeout, transport,
  any other status): the upload fails as before.
- The server does not support an exclusive create: the drop route does not fall back to an
  open that could replace an existing file - the item fails with the reason.
- The upload into the drop folder is stopped or fails after the file was created: the plug-in
  tries once to remove its partial file; if the server refuses, the box says a partial file may
  stay under the target's name.
- The server lets the account write but reports a different size after the upload: as before,
  the upload is not confirmed.
- The server refuses to report the size of the uploaded file (permission): the upload is
  confirmed when the server acknowledged every byte of the local file and the close; the log
  says the size could not be checked.
- A temporary file offered for deletion has meanwhile disappeared or is no longer a regular
  file: it is not deleted, nothing is shown for a vanished one.
- The connection is lost again while deleting offered files: the rest stay recorded.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When the server refuses with a permission status to say whether the upload target
  exists (session alive), the upload MUST create the target only if no file of that name
  exists (exclusive create) and MUST NOT open, truncate or rename over an existing file.
- **FR-002**: If the exclusive create is refused, the item MUST fail with a reason that says the
  server does not show whether a file of that name exists; nothing on the server is changed.
- **FR-003**: When the server refuses with a permission status to report the size of an
  uploaded file, the upload MUST be taken as confirmed only when every byte of the local file
  was acknowledged by the server and the close was confirmed; the session log MUST say so.
  This holds for every upload route; the route then continues as before.
- **FR-003a**: A drop-route upload that fails or is stopped after its exclusive create MUST try
  once to remove the partial file and, if it stays, MUST say in the box that a partial file may
  remain under the target's name.
- **FR-004**: A Move into a drop folder MUST remove the local source only after FR-003's
  confirmation (unchanged rule of 139).
- **FR-005**: The overwrite question MUST state that a replacement is a new copy: other hard
  links keep the old content; the ACL and extended attributes are not carried over.
- **FR-006**: A temporary file of an upload whose removal failed because the connection was lost
  MUST be remembered for that connection; at the start of the next upload on it (after the
  reconnection; not at a refresh or a change of path) the user MUST be offered to delete all remembered files; the answer (Yes or No)
  clears the record.
- **FR-007**: A temporary file kept as the only complete copy of new content, and one whose
  removal the server refused while the connection was alive, MUST NOT be offered.
- **FR-008**: Before deleting an offered file the plug-in MUST check it is still a regular file;
  a deletion that fails is logged and named once in a box.
- **FR-009**: Every other upload path (OpenSSH, ordinary folders, the 139 routes) MUST behave as
  before - the 133 / 139 probe rows stay green.

### Key Entities

- **Left temporary file**: the full server path of a `.tcpart-XXXXXXXX` file the plug-in created
  and could not remove because the connection was lost; held in memory for the panel's
  connection only.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Copy, Move and folder Copy into the test server's drop folder: 4 of 4 probe rows
  arrive complete (before: 0 of 3 arrived, all "Permission denied").
- **SC-002**: An existing file in the drop folder is never changed by an upload (row DROPEXIST).
- **SC-003**: The overwrite question names hard links and the ACL (row REPL).
- **SC-004**: After a lost connection, the next upload on that connection leaves no
  `.tcpart-*` file in the folder (row CUT; before: one left).
- **SC-005**: The SFTP probe of 133 (66 rows on the OpenSSH container) passes as before.

## Assumptions

- Assumption (autonomous run): hard links and ACLs are **stated**, not handled - SFTP version 3
  reports no link count and no ACL (the only source of a link count, the listing's "long name",
  is a text the protocol says clients should not parse). Writing in place to keep the links
  would give up 139's rule (the old content is never gone before the new one is whole). The
  statement goes into the overwrite question, where the user decides.
- Assumption (autonomous run): "found and offered" covers the temporary files this program
  left on a connection it lost - remembered in memory per panel connection (nothing is stored:
  no registry change), offered at the next upload on that connection. Files left by an earlier
  run of the program or by another computer are not searched for (a listing-based search would
  offer files another upload may be writing at that moment). Conservative option.
- Assumption (autonomous run): the new questions and reasons are English literals, as 139's
  question and reasons are (no new UI strings, no `.slt` refresh).
- Assumption (autonomous run): the "drop" route is chosen only on a permission status from a
  live session (SSH_FX_PERMISSION_DENIED, WRITE_PROTECT); "no such file" keeps the 139 route.
- The test server for the drop and connection-cut cases is a local Python (paramiko) server
  started by the probe; the OpenSSH container is used for the 133 regression.
