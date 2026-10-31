# Feature Specification: FTP opened-file lock across two users or ports of one server

**Feature Branch**: `348-ftp-lock-user-port`
**Created**: 2026-10-31
**Status**: Draft
**Input**: User description: "Backlog item ftp-two-uploads-as-another-user-or-port-of-one-server-can - FTP: two uploads as another user or port of one server can store one file at once." From backlog item ftp-two-uploads-as-another-user-or-port-of-one-server-can.

## Background

The FTP plug-in keeps a list of the server files its running operations have open (the opened-file
lock), so that two uploads of one file, or an upload and a download / delete / rename of it, never
run at the same time inside one program instance. Feature 347 stopped the lock from telling
servers apart by the host name (two names of one server are maybe one server). It still tells
them apart by the user and by the port: an upload running as user `v` and an upload as `u` into a
panel at the same server (two accounts that share folders), or two uploads through two ports of
one server (a forwarded port), both store the same file at the same time, and the second store
replaces the first without any question.

**Measured at 4e2c8835** (probe `probe/ftp348_probe.ps1`, result `probe/result_main.txt`; one
test server serving one folder on two ports, 2148 and 2149): the panel at
`ftp://u@127.0.0.1:2148`; upload 1 of the local `hold.txt` ("UP1") typed to another connection of
the server, its store held by the test server; the local file changed to "UP2"; upload 2 by F5
into the panel. Rows OTHER-USER (`v@127.0.0.1:2148`), OTHER-PORT (`u@127.0.0.1:2149`) and
ALL-OTHER (`v@localhost:2149`): FAIL - two stores of the file, one while the other was in flight,
the server file holds "UP2", upload 2 was not refused. Feature 347's row ALIAS-LOCK (another host
name only) and the one-connection control SAME-LOCK: PASS. PASS 7 / FAIL 3.

## Clarifications

### Session 2026-10-31

- Q: Which other connections count as maybe the same server for the lock? → A: every other connection - any host name, user and port; only the server path (by the server type's rule) and the file name (by the server type's case rule) decide (autonomous run: item - *Expected*: "two users or two ports of a server", feature 345's rule for the upload listing cache)
- Q: Should the second conflicting access wait for the first or be refused? → A: refused with the existing "in use" answer of each caller, retryable (autonomous run: conservative - the lock's existing answer; the item accepts "refused (or waits)")
- Q: Is the cost (unrelated servers or accounts whose paths look alike refuse each other's conflicting access while one runs) acceptable? → A: yes - the item's *Expected* chooses refusing; the cost is the one feature 347 accepted for host names, extended to user and port, and a refused item loses nothing (it can be retried) (autonomous run: item)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Two uploads of one file as two users of one server (Priority: P1)

A user uploads a file to a server as user `v` and, while that upload is still storing, uploads a
file of the same name to the same folder through a panel connected to the same server as user `u`
(two accounts that share the folder). The second upload must not store the file while the first
one is storing it: its item is refused as "in use" (the answer the program gives today when both
uploads use one connection), and the user can retry it once the first upload ends.

**Why this priority**: it is the item's defect - a silent overwrite of a file being uploaded
(data loss, no question).

**Independent Test**: probe row OTHER-USER: PASS = no second store of the file while the first is
in flight, upload 2 listed the folder and was refused by the lock, the server keeps "UP1".

**Acceptance Scenarios**:

1. **Given** an upload of `/F/hold.txt` running as user v (host h, port p), **When** an upload of
   `/F/hold.txt` starts as user u (host h, port p), **Then** the second upload does not store the
   file while the first is storing it; its item fails as "the target file is in use" and can be
   retried.
2. **Given** the same two uploads through one connection, **When** the second starts, **Then** the
   behaviour is unchanged (control SAME-LOCK).

---

### User Story 2 - Two uploads through two ports of one server (Priority: P1)

The same as User Story 1 when the two uploads reach the server through two ports (one server
reached through a forwarded port), and when host name, user and port all differ.

**Why this priority**: the item's port variant (*Expected*).

**Independent Test**: probe rows OTHER-PORT and ALL-OTHER, the same verdict as OTHER-USER.

**Acceptance Scenarios**:

1. **Given** an upload of `/F/hold.txt` through port p2, **When** an upload of `/F/hold.txt` starts
   through port p (same server folder), **Then** the second is refused "in use" while the first
   stores.
2. **Given** feature 347's case (another host name, same user and port), **Then** it stays refused
   (row ALIAS-LOCK PASS).

---

### User Story 3 - Other kinds of access as two users or ports (Priority: P2)

The lock also keeps a download, a delete, a rename and a view of a file apart from an upload of it.
Across two users or ports these conflicts are recognised exactly as under one connection: a
conflicting access is refused, two downloads of one file still run together.

**Why this priority**: the same lock decision serves every kind of access; it must stay consistent.

**Independent Test**: by reading - every access goes through the one lock decision changed for
User Story 1; the conflict table (which access types conflict) is not changed.

**Acceptance Scenarios**:

1. **Given** an upload of a file as user v, **When** a download / delete / rename of the same file
   is started as user u, **Then** it is refused as under one connection.
2. **Given** a download of a file as user v, **When** a download of the same file starts as user u,
   **Then** both run (two reads never conflicted).

### Edge Cases

- Two unrelated servers or accounts whose files have the same server path and name (e.g.
  `/index.html` on two servers, or two chrooted accounts): while one writes the file, a conflicting
  access to the other is refused as "in use" and can be retried after the first ends. Accepted
  cost (item *Notes*): the client cannot tell two accounts or ports of one server from two servers,
  and a refused item loses nothing.
- Accounts whose home folders differ and whose paths are reported absolute (`/home/u/a.txt` vs
  `/home/v/a.txt`): different paths, never conflict (unchanged).
- Anonymous login (user `anonymous` or no user): no longer matters - the user is not compared.
- One shared folder seen at two different absolute paths by two accounts (per-account chroot:
  `u` sees `/home/shared/f`, `v` sees `/shared/f`) or through a symbolic link on the server: still
  two files to the lock - the client cannot know they are one (limit, named in the closing record;
  review 1 SHOULD 1).
- Low memory while recording a lock: unchanged (the lock refuses).
- Two program instances: never saw each other's locks (unchanged).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The opened-file lock MUST treat two accesses with the same server path and the same
  file name as accesses to maybe the same file regardless of the host name, user and port each was
  opened under.
- **FR-002**: Which access types conflict (write with anything, delete / rename with other types,
  read with read allowed) MUST stay as it is.
- **FR-003**: The comparison of path and name MUST stay as it is (path by the server type's rule,
  name by the server type's case rule).
- **FR-004**: The answer to a refused access MUST stay the existing one for each caller (an
  operation's item fails "in use" and can be retried; a panel action reports the file is in use).
- **FR-005**: No new UI text, no stored data, no network communication, no plug-in interface change.

### Key Entities

- **Opened-file lock entry**: user, host, port, server path, path type, file name, access type,
  identifier. User, host and port are still stored (for diagnostics) but no longer decide identity.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the probe rows OTHER-USER, OTHER-PORT and ALL-OTHER the server receives 0 stores of
  the file while another store of it is in flight (main: 1 each), the second upload is refused, and
  upload 1's content is kept.
- **SC-002**: Rows ALIAS-LOCK and SAME-LOCK stay PASS; feature 341's, 345's and 347's probes keep
  their recorded results (12 / 0, 16 / 0, 6 / 0 - 347's OTHER-USER row is facts only and now shows
  0 overlapping stores).
- **SC-003**: The encoding guard reports 0 findings and the build succeeds.

## Assumptions

- Assumption (autonomous run): "maybe the same file" follows feature 345's rule for the upload
  listing cache: every other connection (host, user or port differs) may be the same server.
- Assumption (autonomous run): the second access is refused (not made to wait) - the lock's
  existing answer; the item accepts "refused (or waits)".
- Assumption (autonomous run): the cost named in the item's *Notes* is accepted as feature 347
  accepted it for host names; it is named in the closing record and the changelog text.
- The lock is per program instance (unchanged).
