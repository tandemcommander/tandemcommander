# Feature Specification: FTP panel Create Directory and Quick Rename update the upload listing cache

**Feature Branch**: `323-ftp-upload-cache-args`
**Created**: 2026-10-23
**Status**: Draft
**Input**: User description: "Backlog item ftp-panel-mkdir-rename-skip-upload-listing-cache - FTP: Create Directory and Quick Rename in a panel never update the upload listing cache."

## Background

While an upload to an FTP server is in progress (its operation exists), the FTP plug-in keeps a
cache of the server's folder listings that the upload consults to decide whether a target file or
folder already exists (and so whether to ask about overwriting, or to join an existing folder).
Changes the user makes from the FTP panel - creating a folder (F7), Quick Rename (F2) - are
reported to that cache so that it stays true. These two reports name the server with the host and
the user name in each other's places, so the cache never recognises the server and the report is
dropped: the cached listing stays as it was before the change.

A first run of this item (feature 302, branch `302-ftp-upload-cache-args`, stopped) measured the
effect: a file renamed to `b.txt` in the panel was replaced by an uploaded `b.txt` without the
overwrite question (data loss), and a folder created by typing an absolute path into F7 was
unknown to the upload (it sent `MKD` for the existing folder). It fixed the argument order and,
after its first review, made a Quick Rename and a typed FTP command invalidate every cached
listing of the server. Its second review found a regression of the argument fix: Create Directory
with a path (`.cfg/new`, `docs/new`) treats every path component the cached listing does not show
as just created, and caches it as a new, empty folder - but a component the listing does not show
can exist on the server (a hidden dot folder that a plain `LIST` omits; `Docs` on a
case-insensitive server addressed as `docs`). An upload into that folder then trusts "empty" and
overwrites its files without the question. This feature carries the stopped run's work over and
closes that gap.

Measured at 4c33e2fc (by reading): the four reports in the panel's Create Directory and Quick
Rename still pass the host where the user name is expected; the code is unchanged since the
stopped run measured the data loss.

## Clarifications

### Session 2026-10-23

- Q: Should the fix also guard the server identification against another swap (a server-key type
  instead of three loose arguments)? → A: No - only the four calls get the arguments in the
  declared order; the signatures of the 30+ other callers stay as they are (autonomous run:
  conservative; carried over from feature 302).
- Q (302 review 1): with Create Directory's report reaching the cache, a new folder is cached as an
  empty listing; a later Quick Rename into it (`x.txt` -> `new/x.txt`) or giving another folder its
  name left that listing trusted - how far must a rename (and a typed FTP command, which reports
  an "unknown change") invalidate? → A: every cached listing of that server; an unneeded
  invalidation only costs a `LIST` while an upload to that server exists (autonomous run:
  conservative - loses no data; carried over from feature 302).
- Q (302 review 2): Create Directory with a path - which path components may the cache record as
  new and empty? → A: only the last component of a successful Create Directory is known to be new
  and empty; an earlier component that the cached parent listing does not show is not assumed
  created - that parent listing is invalidated and no empty listing is recorded for the component
  (autonomous run: item *Log* of 2026-10-23 and the stopped run's fix-log *Stopped*).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A file renamed in the panel is not overwritten without the question (Priority: P1)

A user has an upload to a folder open, renames `a.txt` to `b.txt` in the FTP panel showing that
folder, then uploads a local `b.txt` into it.

**Why this priority**: the item's data-loss path, measured before the fix (the server's `b.txt`
was replaced without the question).

**Independent Test**: probe row REN-UP: the server's `b.txt` keeps its content, the overwrite
question is open, no `STOR b.txt` reaches the server.

**Acceptance Scenarios**:

1. **Given** an upload operation to the folder is open, **When** the user Quick-Renames `a.txt` to
   `b.txt` in the panel and uploads a local `b.txt` into the folder, **Then** the overwrite
   question appears for `b.txt`, and the server's `b.txt` keeps its content unless the user
   chooses to overwrite.

---

### User Story 2 - A folder created from the panel is known to a running upload (Priority: P2)

A user uploads into a server folder `/other` (the operation stays open, for example waiting on an
overwrite question). In an FTP panel showing `/src` they create the folder `/other/new` by typing
the absolute path into Create Directory. Then they upload a local folder `new` into `/other`.

**Why this priority**: the stale cache makes the upload try to create a folder that exists
instead of joining it (the default for "folder already exists").

**Independent Test**: probe row MKD-ABS: after the second upload starts, the server receives no
`MKD new`, and the local folder's file arrives in `/other/new`.

**Acceptance Scenarios**:

1. **Given** an upload operation to the server is open and the cache holds the listing of
   `/other`, **When** the user creates `/other/new` from a panel at `/src` and then uploads a local
   folder `new` into `/other`, **Then** the upload treats `new` as an existing folder (joins it;
   no `MKD new` is sent) and stores its files there.
2. **Given** the same, **When** the folder creation's result is unknown (the connection closed
   during the command), **Then** the cached listings the new folder belongs to are invalidated, so
   the next upload lists the folder on the server again.

---

### User Story 3 - Create Directory with a path never hides an existing folder's files (Priority: P1)

A user has an upload open into a server folder. In the FTP panel they create a folder with a path
whose first part is a folder the panel's listing does not show - a hidden dot folder (`.cfg/new`,
where `.cfg` exists but a plain listing omits it), or an existing `Docs` typed as `docs` on a
server that ignores case. Then they upload a file into that first folder (`.cfg/` or `docs/`)
which already holds a file of the same name on the server.

**Why this priority**: without it the argument fix of User Stories 1-2 opens a new data-loss
path (302 review 2): the existing folder is cached as empty and the upload overwrites its file
without the question.

**Independent Test**: probe rows MKD-HID and MKD-CASE: the upload lists the folder on the server,
the overwrite question appears, no `STOR` of the file reaches the server and its content is kept.

**Acceptance Scenarios**:

1. **Given** an upload operation to the server is open and the cached listing of the panel folder
   does not show `.cfg` (it exists on the server), **When** the user creates `.cfg/new` and then
   uploads a local `f.txt` into `.cfg/` where the server already has `f.txt`, **Then** the
   overwrite question appears and the server's `.cfg/f.txt` keeps its content.
2. **Given** the same with a server folder `Docs` and the typed path `docs/new` on a server that
   ignores case, **When** the user uploads `f.txt` into `docs/`, **Then** the overwrite question
   appears and the server's `Docs/f.txt` keeps its content.
3. **Given** the cached listing of the panel folder shows the first component `a` (an existing
   folder) or Create Directory makes a single folder `new`, **When** the user creates `a/new` or
   `new`, **Then** the last component is recorded as a new, empty folder exactly as before (the
   behaviour of User Story 2 and of the upload's own folder creation is unchanged).

### Edge Cases

- Anonymous login: the cache stores anonymous as "no user"; the fixed report must still find the
  server (the cache's own lookup normalises the anonymous name - unchanged).
- User name equal to the host name: the swapped call happened to work; the fixed call works too.
- No upload operation open: the cache holds no server; the reports change nothing (unchanged).
- Rename with a path in the new name (`x.txt` -> `new/x.txt`), or of a folder (its listing and the
  listings below it move): every cached listing of the server is invalidated.
- A folder made by F7 is cached as empty; a later change to it that the cache cannot place (Quick
  Rename, a typed FTP command) invalidates it with the rest.
- Create Directory with a path whose intermediate component the cached listing does not show:
  the listing that should have shown it is invalidated; no component except the last is recorded
  as new and empty.
- Create Directory whose result is unknown: unchanged - the affected listings are invalidated.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Create Directory from an FTP panel MUST report the change to the upload listing cache
  of the server the panel is connected to (user, host and port each in its own place), both when
  the folder was created and when the result is unknown.
- **FR-002**: Quick Rename from an FTP panel MUST report the change to the upload listing cache of
  that server, both when the rename finished and when the result is unknown.
- **FR-003**: Every other report to the upload listing cache MUST keep its current behaviour
  (they already name the server correctly).
- **FR-004**: A reported Quick Rename and a reported unknown change (a typed FTP command) MUST
  invalidate every cached listing of that server.
- **FR-005**: A reported successful Create Directory MUST record as a new, empty folder only the
  last component of the created path. A preceding component that the cached listing of its parent
  does not contain MUST NOT be recorded as created: the cached listing of that parent MUST be
  invalidated (the next upload into it lists the server again) and no empty listing may be cached
  for that component or any component below it. Components the cached listing does contain are
  handled as before.

### Key Entities

- **Upload listing cache**: per server (user, host, port) the listings of folders an open upload
  works with; consulted by the upload to detect existing targets; lives while an upload operation
  to that server exists.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In probe row MKD-ABS, the second upload sends no `MKD new` to the server (before the
  fix: it does) and the local folder's file arrives in `/other/new`.
- **SC-002**: In probe row REN-UP, the overwrite question for `b.txt` appears, no `STOR b.txt`
  reaches the server and its `b.txt` keeps its original content (before the fix: replaced without
  the question).
- **SC-003**: In probe rows MKD-REN and REN-PATH (F7 `new`, then Quick Rename `new` -> `new_old`
  and `full` -> `new`, or `x.txt` -> `new/x.txt`; then an upload into `new`), the overwrite
  question appears and the server's file keeps its content (with the argument fix alone: replaced
  without the question).
- **SC-004**: In probe rows MKD-HID and MKD-CASE, the overwrite question appears, no `STOR f.txt`
  reaches the server and the server's file keeps its content (with the stopped run's state:
  replaced without the question; on `main`: kept).
- **SC-005**: The existing FTP probe whose rows drive Create Directory, Quick Rename and upload
  against the test server (feature 288, `ftp288_probe.ps1`) gives the same result as recorded by
  288 (20 / 0).

## Assumptions

- Assumption (autonomous run): the test FTP server of features 215 / 224 / 288 (`ftpmini.py`, and
  the stopped run's variant `ftpmini_hide.py` that hides dot names on a plain `LIST` and ignores
  case) and the hidden-desktop driver are used; a real server check is not needed (the change only
  makes the cache trust less).
- Assumption (autonomous run): Send FTP Command into a folder made by F7 while an upload is open
  (FR-004's unknown change) is not reachable by the probe's command ids; checked by reading and
  owed to a person at closing.
- No UI text, configuration, stored data or network behaviour changes beyond the extra `LIST`
  an upload sends when its cached listing was invalidated.
