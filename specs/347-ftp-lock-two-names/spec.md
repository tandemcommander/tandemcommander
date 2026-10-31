# Feature Specification: FTP opened-file lock across two names of one server

**Feature Branch**: `347-ftp-lock-two-names`
**Created**: 2026-10-31
**Status**: Draft
**Input**: User description: "Backlog item ftp-opened-file-lock-two-names-of-one-server - FTP: two operations under two names of one server can open one file at the same time." From backlog item ftp-opened-file-lock-two-names-of-one-server.

## Background

The FTP plug-in keeps a list of the server files its running operations have open (the opened-file
lock), so that two uploads of one file, or an upload and a download / delete / rename of it, never
run at the same time inside one program instance. The lock tells servers apart by the host name as
typed. One server reached as `localhost` and as `127.0.0.1` (a name and its address, two names or
two addresses of one server) is two servers to the lock, so two operations can store the same
server file at once.

**Measured at 794b3207** (probe `probe/ftp347_probe.ps1`, result `probe/result_main.txt`): the
panel at `ftp://u@127.0.0.1:2147`; upload 1 of the local `hold.txt` ("UP1") typed to
`ftp://u:p@localhost:2147/ALIAS-LOCK`, its store held by the test server; the local file changed
to "UP2"; upload 2 by F5 into the panel (127.0.0.1). The server received a second `STOR hold.txt`
while the first was still in flight; both operations ended "(100 %)" and the server file holds
"UP2" - upload 1's file was replaced without any question (row ALIAS-LOCK FAIL). The control with
one name (SAME-LOCK) sends one store and asks the overwrite question.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Two uploads of one file under two names of one server (Priority: P1)

A user uploads a file to a server they opened as `localhost` and, while that upload is still
storing, uploads a file of the same name to the same folder through a panel connected to the
server's address `127.0.0.1` (same user, same port). The second upload must not store the file
while the first one is storing it: its item is refused as "in use" (the same answer the program
gives today when both uploads use one name), and the user can retry it once the first upload ends.

**Why this priority**: it is the item's defect - a silent overwrite of a file being uploaded
(data loss, no question).

**Independent Test**: probe row ALIAS-LOCK: one held store under `localhost`, a second upload of
the same file under `127.0.0.1`; PASS = no second store of the file while the first is in flight.

**Acceptance Scenarios**:

1. **Given** an upload of `/F/hold.txt` running under host name A (user u, port p), **When** an
   upload of `/F/hold.txt` starts under host name B (user u, port p), **Then** the second upload
   does not store the file while the first is storing it; its item fails as "the target file is in
   use" and can be retried.
2. **Given** the same two uploads under one host name, **When** the second starts, **Then** the
   behaviour is unchanged (control SAME-LOCK).

---

### User Story 2 - Other kinds of access under two names (Priority: P2)

The lock also keeps a download, a delete, a rename and a view of a file apart from an upload of it.
Under two names of one server with the same user and port, these conflicts are recognised exactly
as under one name: a conflicting access is refused, two downloads of one file still run together.

**Why this priority**: the same lock decision serves every kind of access; it must stay consistent
for all of them.

**Independent Test**: by reading - every access goes through the one lock decision changed for
User Story 1; the conflict table itself (which access types conflict) is not changed.

**Acceptance Scenarios**:

1. **Given** an upload of a file under host name A, **When** a download / delete / rename of the
   same file is started under host name B with the same user and port, **Then** it is refused as
   under one name.
2. **Given** a download of a file under host name A, **When** a download of the same file starts
   under host name B, **Then** both run (two reads never conflicted).

### Edge Cases

- Two different servers that share user, port, folder and file name (e.g. two hosts each with
  `u@host:21/pub/a.txt`): while one writes the file, a conflicting access to the other is refused
  as "in use" and can be retried after the first ends. Accepted cost: the client cannot tell two
  names of one server from two servers (feature 341's finding), and a refused item loses nothing.
- Another user or another port of one server: unchanged by this feature (the item's scope is the
  same user and port); measured on `main` as also able to store one file twice at once (row
  OTHER-USER) - recorded as a separate backlog item.
- Host names differing only by letter case: already one server to the lock; unchanged.
- Low memory while recording a lock: unchanged (the lock refuses).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The opened-file lock MUST treat two accesses with the same user, the same port, the
  same server path and the same file name as accesses to maybe the same file regardless of the host
  name each was opened under.
- **FR-002**: Which access types conflict (write with anything, delete / rename with other
  types, read with read allowed) MUST stay as it is.
- **FR-003**: The comparison of user, port, path and name MUST stay as it is (user exact, port
  equal, path by the server type's rule, name by the server type's case rule).
- **FR-004**: The answer to a refused access MUST stay the existing one for each caller (an
  operation's item fails "in use" and can be retried; a panel action reports the file is in use).
- **FR-005**: No new UI text, no stored data, no network communication.

### Key Entities

- **Opened-file lock entry**: user, host, port, server path, path type, file name, access type,
  identifier. The host is still stored (for diagnostics) but no longer decides identity.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the probe row ALIAS-LOCK the server receives 0 stores of the file while another
  store of it is in flight (main: 1), and upload 1's content is not replaced without a question.
- **SC-002**: Control rows keep their results: SAME-LOCK PASS; feature 341's and 345's probes keep
  their recorded results (12 / 0 and 16 / 0).
- **SC-003**: The encoding guard reports 0 findings and the build succeeds.

## Assumptions

- Assumption (autonomous run): "maybe the same file" follows feature 341's rule for host names:
  any other host name with the same user and port may be the same server (neither equal nor
  different addresses prove it). The item's *Expected* names exactly this scope.
- Assumption (autonomous run): the second access is refused (not made to wait) - the lock's
  existing answer for one name; the item accepts "waits or is refused".
- Assumption (autonomous run): user and port differences keep two lock owners apart (item scope);
  the measured OTHER-USER case becomes an Inbox item.
- The lock is per program instance; two program instances never saw each other's locks (unchanged).
