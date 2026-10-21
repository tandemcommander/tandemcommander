# Feature Specification: FTP - a PWD reply or a created folder path that does not fit is never cut and used

**Feature Branch**: `277-ftp-pwd-path-cut`
**Created**: 2026-10-21
**Status**: Draft
**Input**: From backlog item ftp-pwd-and-created-path-cut. User description: "Backlog item ftp-pwd-and-created-path-cut (backlog/items/ftp-pwd-and-created-path-cut/desc.md) - implement exactly what it describes." (full input: title, problem, evidence, expected, approach, notes, measurement at 65c337dc - see *Background* below)

## Background

The FTP plug-in keeps a server path in a 301-byte buffer (300 bytes of UTF-8). In a few places
it still cuts a longer server path, or a name, to fit and then works on the result:

- the server's answer to "which folder am I in" (PWD / 257 reply) in the German AIX form
  (`257 '/path' ist das aktuelle Verzeichnis.`) is cut at 300 bytes and taken as success; a
  legacy (code-page) server's path whose UTF-8 form is longer than 300 bytes is cut when it is
  converted, possibly inside a letter. The RFC 959 form (`257 "/path"`) is refused when it does
  not fit, but already at exactly 300 bytes, one byte before the buffer is full;
- the folder a user creates (Create Directory, a relative name up to 2 * MAX_PATH) is cut to 300
  bytes before it is reported to the upload listing cache - a cut last component is recorded as a
  created folder; completing an absolute OS/2 or VMS path cuts its end;
- the AS/400 member name used as a download's target name is cut to MAX_PATH;
- the lock that keeps two operations off one server file compares names on a case-insensitive
  server with the code-page case rule on UTF-8 bytes, not the file system's rule (feature 092);
- the upload's estimate of a linked file's size reads the size from a cut local source path.

**Measured at 65c337dc** (hidden-desktop probe; 215's local test server extended so that a
folder is reached "through a link": its PWD reply names another, long path; the server drops the
session once after the folder's listing): copying the server folder `lnk` (file x.txt "DEEP")
whose PWD reply in the AIX form is `A/deep` (305 bytes; `A`, 300 bytes, is the server's folder
`anc` holding x.txt "ANCESTOR") - the client took the cut path `A`, and after the reconnect it
went to `A` and downloaded **"ANCESTOR" as lnk\x.txt** (another folder's file under the deep
folder's name). The cp1250 form (`A` = 152 code-page bytes, 300 bytes of UTF-8): cut on
conversion, the client changed to the cut path. The RFC form of 305 bytes: refused (control). The
RFC form of exactly 300 bytes: refused. A short AIX-form path: downloaded "DEEP" (control). The
other sites by reading.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A server folder whose working path does not fit is refused, never replaced by an ancestor (Priority: P1)

A user copies, moves or browses an FTP folder that the server reports (PWD) under a path longer
than 300 bytes - for example a link to a deeply nested folder on an AIX server or on a legacy
server with accented folder names. The plug-in must not continue in a cut path: it reports that
it cannot get the working path, as it already does for the RFC form, and nothing is read from,
written to or deleted in another folder.

**Why this priority**: the cut path is an ancestor (or a sibling-prefix) folder; downloading,
uploading or deleting there acts on other files under the deep folder's name - loss or mix-up of
the user's data.

**Independent Test**: the probe's AIX and cp1250 rows: F5 of the server folder `lnk`; the local
`lnk\x.txt` is never "ANCESTOR"; the copy reports the working-path error.

**Acceptance Scenarios**:

1. **Given** a server whose AIX-form PWD reply in `lnk` is 305 bytes, **When** the user copies
   `lnk` to the local panel, **Then** the copy of `lnk` fails with "Error Getting Working Path On
   Server" and no file of another server folder is written locally.
2. **Given** a cp1250 server whose RFC-form PWD path fits in 300 code-page bytes but not in 300
   bytes of UTF-8, **When** the user copies `lnk`, **Then** the same refusal; no command is sent
   to a cut path.
3. **Given** an RFC-form PWD path of 305 bytes, **When** the user copies `lnk`, **Then** it is
   refused as before (unchanged).
4. **Given** the connection's first PWD (after login), a Create Directory reply or an upload's
   target PWD with a path that does not fit, **When** the reply is read, **Then** the path is
   refused exactly as an RFC-form path that does not fit is refused at that place today.

---

### User Story 2 - A working path of exactly 300 bytes is accepted (Priority: P2)

A server path of exactly 300 bytes of UTF-8 fits the plug-in's buffer and is accepted in every
reply form.

**Why this priority**: today the RFC form is refused at 300 bytes, one byte early - a folder the
plug-in can hold cannot be copied.

**Independent Test**: the probe's R300 row: the RFC-form PWD reply of exactly 300 bytes; the
local `lnk\x.txt` is "DEEP300".

**Acceptance Scenarios**:

1. **Given** an RFC-form PWD reply of exactly 300 bytes, **When** the user copies `lnk`,
   **Then** the copy succeeds and the right file is downloaded.
2. **Given** a reply of 301 bytes, **Then** it is refused.

---

### User Story 3 - No other place acts on a cut server name or path (Priority: P3)

The created-folder report, the AS/400 member name, the opened-file lock and the upload's link
size estimate never act on a cut text.

**Why this priority**: lower impact (a stale cache entry, a target name, a missing lock, a wrong
size estimate), but each is the same defect class.

**Independent Test**: by reading and unit checks (saltests) of the pure rules; the existing FTP
probes (215, 224, 233) as regressions.

**Acceptance Scenarios**:

1. **Given** a Create Directory name that does not fit the 300-byte path buffer, **When** the
   server confirms the creation, **Then** the upload listing cache invalidates the affected
   listings instead of recording a cut folder name.
2. **Given** an OS/2 or VMS absolute path that would not fit once completed, **Then** the
   completion fails without changing the path and its caller does not use a cut path.
3. **Given** an AS/400 member name that does not fit the caller's buffer, **Then** no cut name is
   used as a target name - the caller refuses ("too long" as for any other long target name).
4. **Given** two files on a case-insensitive server whose names differ only by the case of a
   non-ASCII letter (`Č.txt` / `č.txt`), **Then** the lock treats them as one file; two different
   non-ASCII names that only the code-page case table folds together are two files.
5. **Given** an upload from a local folder whose path does not fit the link-name buffer, **Then**
   the size of a linked file is left unknown (as for a link whose name does not fit) - never read
   from another path.

### Edge Cases

- A PWD path of exactly 300 bytes in the AIX form: accepted (it was accepted before too).
- A legacy server path whose UTF-8 form is exactly 300 bytes: accepted; 301 bytes: refused.
- A reply whose quoted path is never closed (no closing quote within the reply): refused as a
  syntax error, as before.
- An AIX-form reply, VxWorks form (`257 Current directory is "mars:"`) and `""` escapes keep
  their current parsing.
- A reply that is not terminated after its size: the parser reads only within the reply's size.
- Low memory while converting a code-page path: refused (never a cut or unconverted path taken
  as UTF-8 - [Assumption] see below).
- A Create Directory name made of components that each fit but whose whole does not: the
  components that fit are walked whole; listings are invalidated, nothing cut is recorded.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The PWD / 257 reply parser MUST return failure when the path (in the server's
  encoding, and again after conversion to UTF-8) does not fit the caller's buffer, in every reply
  form (RFC 959, VxWorks, German AIX); it MUST never return a cut path as success.
- **FR-002**: A path that fits exactly (buffer size - 1 bytes, 300 bytes for the 301-byte buffer)
  MUST be accepted in every form.
- **FR-003**: Every caller of the parser (the connection's working path, Create Directory's
  reply, the explore of a folder in an operation, the upload's target path) MUST keep its existing
  handling of a refused reply; no caller changes what it does on failure.
- **FR-004**: The created-folder report to the upload listing cache MUST never record a cut folder
  name; when the reported name does not fit the path buffer, it MUST invalidate the affected
  cached listings instead.
- **FR-005**: The completion of an absolute OS/2 / VMS path MUST fail without changing the path
  when the result does not fit; its caller MUST not continue with a cut path.
- **FR-006**: The AS/400 member-name helper MUST fail instead of cutting; both callers (the panel
  download, the explore of a folder in a copy / move) MUST refuse a name that does not fit, as
  they refuse other too-long target names.
- **FR-007**: The opened-file lock MUST compare names on a case-insensitive server by the file
  system's name rule of feature 092 (the header-only plug-in variant).
- **FR-008**: The upload's link size estimate MUST be skipped (size unknown) when the local
  source path does not fit the link-name buffer.
- **FR-009**: The pure parse rule of FR-001 / FR-002 MUST be covered by `saltests` checks
  (fit / one byte over / exactly full, each form).
- **FR-010**: No new UI strings; existing messages only.

### Key Entities

- **PWD reply**: the server's 257 answer; carries one path in one of three forms, in the server's
  encoding.
- **Server path buffer**: 301 bytes (300 bytes of UTF-8 + terminator) - unchanged.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the probe, 0 rows in which a local file holds another server folder's content
  (AIX, cp1250 rows: "ANCESTOR" before, never after).
- **SC-002**: The 300-byte RFC-form row downloads the right file (refused before).
- **SC-003**: The controls (RFC 305 bytes refused; a short AIX-form path downloads) give the same
  result before and after.
- **SC-004**: `saltests` passes with the new checks; the encoding guard reports 0 findings; the
  existing FTP probes of 215 and 233 give their recorded results.

## Assumptions

- Assumption (autonomous run): the limit stays 300 bytes (`FTP_MAX_PATH`); this feature refuses
  what does not fit, it does not widen the plug-in's path buffers (deep FTP paths are a recorded
  limit of 233).
- Assumption (autonomous run): a code-page path whose conversion fails for low memory is refused
  (conservative; the old code kept the unconverted bytes).
- Assumption (autonomous run): the panel route at login is already limited by the core (~260
  bytes); the visible harm is in the operation workers, which is what the probe drives.
- Assumption (autonomous run): the original item's "fs4.cpp download target name cut at a byte"
  is checked by reading and dropped if the target name is whole (feature 178 / 215).
- Out of scope (other backlog items): the escaped-path decision, long local paths, `?` mask
  letters by server encoding, a reply cut at 700 bytes.
