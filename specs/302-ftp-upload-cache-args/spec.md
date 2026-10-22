# Feature Specification: FTP panel Create Directory and Quick Rename update the upload listing cache

**Feature Branch**: `302-ftp-upload-cache-args`
**Created**: 2026-10-22
**Status**: Draft
**Input**: User description: "Backlog item ftp-panel-mkdir-rename-skip-upload-listing-cache - FTP: Create Directory and Quick Rename in a panel never update the upload listing cache." From backlog item ftp-panel-mkdir-rename-skip-upload-listing-cache.

## Background

While an upload to an FTP server is in progress (its operation exists), the FTP plug-in keeps a
cache of the server's folder listings that the upload consults to decide whether a target file or
folder already exists (and so whether to ask about overwriting, or to join an existing folder).
Changes the user makes from the FTP panel - creating a folder (F7), Quick Rename (F2) - are
reported to that cache so that it stays true. These two reports name the server with the host and
the user name in each other's places, so the cache never recognises the server and the report is
dropped: the cached listing stays as it was before the change.

Measured at 02eba55f (by reading, see `fix-log.md`): the four reports (Create Directory: done and
"result unknown"; Quick Rename: done and "result unknown") pass the host where the user name is
expected; every other report passes them in the declared order. For the panel's own folder the
effect is masked: the panel lists its folder again after the command, and that fresh listing
replaces the cached one; a new upload into the panel's folder also takes the panel's listing. It is
not masked when Create Directory names a folder outside the panel's folder (for example an absolute
path typed into F7): only the cache knows of that folder's listing, and an upload into it keeps
believing the new folder does not exist.

## Clarifications

### Session 2026-10-22

- Q: Should the fix also change how the cache reacts to a rename whose new name holds a path
  (today only the panel folder's listing is invalidated), or guard the server identification
  against another swap (a server-key type instead of three loose arguments)? → A: No - only the
  four calls get the arguments in the declared order; the cache's reactions and the signatures of
  the 30+ other callers stay as they are (autonomous run: conservative).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A folder created from the panel is known to a running upload (Priority: P1)

A user uploads into a server folder `/other` (the operation stays open, for example waiting on an
overwrite question). In an FTP panel showing `/src` they create the folder `/other/new` by typing
the absolute path into Create Directory. Then they upload a local folder `new` into `/other`.

**Why this priority**: it is the case where the stale cache is visible: the upload tries to create
a folder that exists instead of joining it (the default for "folder already exists").

**Independent Test**: hidden-desktop probe with a local test FTP server that logs every command:
after the second upload starts, the server receives no `MKD new`, and the local folder's file
arrives in `/other/new`.

**Acceptance Scenarios**:

1. **Given** an upload operation to the server is open and the cache holds the listing of
   `/other`, **When** the user creates `/other/new` from a panel at `/src` and then uploads a local
   folder `new` into `/other`, **Then** the upload treats `new` as an existing folder (joins it;
   no `MKD new` is sent) and stores its files there.
2. **Given** the same, **When** the folder creation's result is unknown (the connection closed
   during the command), **Then** the cached listings the new folder belongs to are invalidated, so
   the next upload lists the folder on the server again.

---

### User Story 2 - A file renamed in the panel is not overwritten without the question (Priority: P2)

A user has an upload to a folder open, renames `a.txt` to `b.txt` in the FTP panel showing that
folder, then uploads a local `b.txt` into it.

**Why this priority**: the item's suspected data-loss path. Measured by reading as masked by the
panel's refresh; the row stays as a regression check of the rename report.

**Independent Test**: probe row: the server's `b.txt` keeps its content (the overwrite question
appears and is answered "Skip", or no `STOR b.txt` reaches the server).

**Acceptance Scenarios**:

1. **Given** an upload operation to the folder is open, **When** the user Quick-Renames `a.txt` to
   `b.txt` in the panel and uploads a local `b.txt` into the folder, **Then** the overwrite
   question appears for `b.txt`, and the server's `b.txt` keeps its content unless the user
   chooses to overwrite.

### Edge Cases

- Anonymous login: the cache stores anonymous as "no user"; the fixed report must still find the
  server (the cache's own lookup normalises the anonymous name - unchanged).
- User name equal to the host name: the swapped call happened to work; the fixed call works too.
- No upload operation open: the cache holds no server; the reports change nothing (unchanged).
- Rename with a path in the new name: the cache only invalidates the panel folder's listing (an
  upstream simplification, unchanged; out of scope).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Create Directory from an FTP panel MUST report the change to the upload listing cache
  of the server the panel is connected to (user, host and port each in its own place), both when
  the folder was created and when the result is unknown.
- **FR-002**: Quick Rename from an FTP panel MUST report the change to the upload listing cache of
  that server, both when the rename finished and when the result is unknown.
- **FR-003**: Every other report to the upload listing cache MUST keep its current behaviour
  (they already name the server correctly).
- **FR-004**: The reaction of the cache to a report (which listings are updated or invalidated)
  MUST stay as it is; only the server identification is corrected.

### Key Entities

- **Upload listing cache**: per server (user, host, port) the listings of folders an open upload
  works with; consulted by the upload to detect existing targets; lives while an upload operation
  to that server exists.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the probe row of User Story 1, the second upload sends no `MKD new` to the server
  (before the fix: it does) and the local folder's file arrives in `/other/new`.
- **SC-002**: In the probe row of User Story 2, the server's `b.txt` keeps its original content.
- **SC-003**: The existing FTP probes that touch Create Directory, Quick Rename and upload
  (features 224, 277, 288) give the same results as before the change.

## Assumptions

- Assumption (autonomous run): the item's rename row passes before the fix as well (masked by the
  panel's refresh); this is recorded as the measured negative control, and the absolute-path
  Create Directory row is the one that shows the defect.
- Assumption (autonomous run): the test FTP server of features 215 / 224 / 288 (`ftpmini.py`) and
  the hidden-desktop driver are used; a real server check is not needed for an argument-order fix
  (no server-dependent behaviour changes).
- No UI text, configuration, stored data or network behaviour changes.
