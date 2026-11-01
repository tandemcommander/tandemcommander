# Feature Specification: FTP - a listing column built from several parts is decoded part by part

**Feature Branch**: `384-ftp-joined-column`
**Created**: 2026-11-01
**Status**: Draft
**Input**: User description: "Backlog item ftp-listing-rule-joins-utf8-with-raw-bytes (backlog/items/ftp-listing-rule-joins-utf8-with-raw-bytes/desc.md) - implement exactly what it describes." From backlog item ftp-listing-rule-joins-utf8-with-raw-bytes.

## Background

Some FTP server types list a file in parts that the client joins into one value with the listing
rule "add string to column": IBM z/VM CMS lists `NAME TYPE`, and the client's z/VM rules build the
file name `NAME.TYPE` from the name word, a literal `.` and the next word of the line. Other rules
use the same step on text columns (VMS: the rest of a rights line; MVS: the unit followed by a space
and the name column).

The first part (the column's value) is already decoded to UTF-8 when the next part is appended.
The appended part, when it is taken from the listing line itself, is still the server's raw bytes.
Today both are copied into one buffer and the whole text is decoded again. On a server that lists
names in the Windows code page (a "legacy" server), a name with letters outside ASCII in both parts
is then no longer valid UTF-8, so the already-decoded first part is read in the code page a second
time: `nameč.extč` is shown as `nameÄŤ.extč`. Every command for that file (delete, download, rename,
view) names a file the server does not have.

Measured at 7ba0dcb8 (Debug build, ACP 1250, hidden desktop, a z/VM-style listing from a test
server): F8 sends `DELE nameÄŤ.extč` and the file stays; F5 sends `RETR nameÄŤ.extč` and nothing is
downloaded. A name whose first part is ASCII (`name.extč`) and the same name from a UTF-8 server
work.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Work with a z/VM file whose name has letters outside ASCII on a code-page server (Priority: P1)

A user connects to a z/VM (CMS) FTP server that lists names in the code page. A file is named
`nameč.extč` (letters outside ASCII in both the file name and the file type). The panel shows the
name as the server has it, and delete, download and the other commands reach that file.

**Why this priority**: This is the defect of the item - the file cannot be worked with at all.

**Independent Test**: A test server listing in the z/VM form and in cp1250 holds `nameč.extč` and
`a-keep.txt`; F8 on `nameč.extč` deletes it (only `a-keep.txt` stays); F5 of it to a local folder
creates a local `nameč.extč` with the server file's content.

**Acceptance Scenarios**:

1. **Given** a code-page z/VM listing with `nameč.extč`, **When** the folder is listed, **Then** the
   panel and the delete confirmation show `nameč.extč`.
2. **Given** the same listing, **When** the user deletes the file, **Then** the server receives the
   delete for `nameč.extč` and the file is gone; no other file is touched.
3. **Given** the same listing, **When** the user copies the file to a local folder, **Then** the
   local folder holds `nameč.extč` with the server file's content.

---

### User Story 2 - Names that already worked keep working (Priority: P2)

A name whose only non-ASCII letters are in the appended part (`name.extč`) on a code-page server,
any name on a UTF-8 server, and ASCII names are shown and addressed exactly as before.

**Why this priority**: The fix must not change the cases that were right.

**Independent Test**: The same test server rows with `name.extč` (code page) and `nameč.extč`
(UTF-8 server): F8 deletes the file, before and after the change.

**Acceptance Scenarios**:

1. **Given** a code-page z/VM listing with `name.extč`, **When** the user deletes it, **Then** it is
   deleted (as before).
2. **Given** a UTF-8 z/VM listing with `nameč.extč`, **When** the user deletes it, **Then** it is
   deleted (as before).

---

### Edge Cases

- The appended part is the rule's literal text (`.`, a space): it is appended as text; a literal
  that is not valid UTF-8 is read in the code page as before (it is not the server's bytes and is
  not recorded as one of the server's names).
- The appended part is another column's value (already decoded): it is appended as it is - never
  decoded a second time.
- The appended part is raw listing bytes (next word, next character, rest of line): it is decoded
  by the same rule as any listing field (ASCII / UTF-8 / WTF-8 kept, otherwise the code page).
- A "mixed" server (it listed both UTF-8 and code-page names): a joined name with a part that came
  from the code page is remembered as a code-page name of that server, so commands for it go in
  the code page (as a single-field code-page name does since feature 288).
- The appended text is empty: nothing is appended (as before).
- The joined name is longer than the name limit (`FTP_MAX_NAME_U8`): the line does not match the
  rule, as before (a name is never cut).
- Low memory: the rule fails with the low-memory flag, as before.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When a listing rule appends a part to a text or name column, the column's existing
  (already decoded) value MUST NOT be decoded again.
- **FR-002**: An appended part taken from the listing line (raw server bytes) MUST be decoded by the
  same rule as a listing field before it is appended.
- **FR-003**: An appended part that is another column's value MUST be appended as it is.
- **FR-004**: An appended literal from the rule MUST be appended as valid text: kept when it is
  ASCII / UTF-8, otherwise read in the code page (the earlier result for such a literal).
- **FR-005**: A joined value with a part that came from the code page MUST be remembered as a
  code-page name of the server, as every code-page listing field is (features 224 / 288), so that
  a command for it goes in the code page also to a "mixed" server.
- **FR-006**: The joined value MUST NOT count as evidence of the server's encoding (feature 288's
  rule for re-assigned columns stays).
- **FR-007**: Names and text that were shown correctly before (ASCII, UTF-8 servers, a code-page
  name whose first part is ASCII) MUST be shown and addressed exactly as before.
- **FR-008**: The name limit and the low-memory behaviour of the rule MUST stay as they are.
- **FR-009**: The pure part of the decision (whether a joined value is a code-page name) MUST be a
  testable rule with unit checks.

### Key Entities

- **Listing column value**: the decoded (UTF-8) text of a name or text column of one listed item.
- **Appended part**: the text a rule adds - raw listing bytes, another column's value or a literal.
- **Server's code-page names**: the per-server set of names the server gave in the code page
  (feature 288), which decides the encoding of commands for a "mixed" server.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a code-page z/VM listing, a file named with non-ASCII letters in both parts is
  deleted and downloaded by its name: the probe's two failing rows (ZVM-CP-DEL, ZVM-CP-DL) pass.
- **SC-002**: The control rows (ZVM-CP-ASCII, ZVM-UTF-DEL) pass before and after.
- **SC-003**: The earlier FTP encoding probes (288, 269, 224) give the same results as before.
- **SC-004**: The unit rules pass with 0 failures, including the new checks.

## Assumptions

- Assumption (autonomous run): the joined value keeps feature 288's rule "a re-assigned column is
  no evidence of the server's encoding" - also for its raw part (conservative: the server state
  is decided exactly as before; the item does not ask to change it).
- Assumption (autonomous run): the rule's literal text is not the server's bytes; it is decoded on
  its own (valid UTF-8 kept, else the code page, the earlier result) and not recorded as a server
  name.
- Assumption (autonomous run): the reproduction uses a copy of 215's `ftpmini.py` with a z/VM
  listing form and a z/VM SYST reply (so the client's UNIX rules are not tried) - a real z/VM
  server is not available; a real-server check is owed to a person only if a reviewer finds the
  test server's form unlike a real one.
- The VMS (rights + rest of line) and MVS (unit + name column) rules use the same step; they get
  the same part-by-part decoding without separate probes (their parts are ASCII in practice).
