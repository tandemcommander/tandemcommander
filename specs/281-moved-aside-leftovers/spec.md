# Feature Specification: An entry moved aside for an 8.3 clash is never left under `salNNN` silently

**Feature Branch**: `281-moved-aside-leftovers`
**Created**: 2026-10-21
**Status**: Draft
**Input**: User description: "Backlog item moved-aside-restore-leftovers - implement exactly what it describes." From backlog item moved-aside-restore-leftovers.

## Background

When a new file or folder is created under a name that is only the short (8.3) name of another
entry ("LONGFI~1.TXT" next to "longfilename.txt"), the program moves that other entry aside to a
temporary name `salNNN`, creates the new entry, and moves the other entry back to its own name
(features 199-203). If another process (a virus scanner, an indexer) holds the entry at that
moment, the move back can fail. Feature 221 retries the move back for about a second and tells the
user where the entry stays for Quick Rename and the worker's move. Left open:

1. **The create paths** - a copy of a file or a folder (F5 / F6), Create Directory (F7), Edit New
   File, unpacking from an archive, a plug-in's create through the program's services (FTP, SFTP,
   Renamer): when the move back fails twice, the user's file or folder stays renamed to `salNNN`
   and nothing says so. The user sees only "cannot create <the new name>"; an archive unpack's
   Retry then even succeeds, and the other entry is silently left under `salNNN`.
2. **PictView's and the Renamer's own rename**: they already say where the entry stays, but they
   move it back only once - no retry while the other program lets go.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A copy, a new folder or an unpack tells where the other entry stayed (Priority: P1)

The user copies "LONGFI~1.TXT" into a folder holding "longfilename.txt" (or a folder "LONGDI~1"
next to "longdirname", or creates such a folder with F7, or unpacks such a member from an archive).
At that moment another program holds the moved-aside entry and keeps holding it.

**Why this priority**: it is the item's main gap - the user's own file is renamed and nothing says
so; the user would look for "longfilename.txt" and not find it.

**Independent Test**: with the Debug probe seam making every move back fail, run each create route
on a fixture; the user is shown a message naming the full `salNNN` path and the reason, and the
entry's content is found there unchanged.

**Acceptance Scenarios**:

1. **Given** a file copy whose target name is only another file's short name and the move back of
   that file fails on every attempt, **When** the copy runs, **Then** a message titled as a rename
   error shows the full path of the `salNNN` entry and the reason, the copy reports its own error
   as before, and the other file's content is intact under `salNNN`.
2. **Given** the same for a folder copy, F7 Create Directory, Edit New File, an archive unpack of a
   file member and of a folder member, **When** the operation runs, **Then** the same message is
   shown once per left entry, and the operation's own error report is unchanged.
3. **Given** the move back fails only for a short moment (less than the retry window), **When** the
   create runs, **Then** the entry gets its own name back and no new message is shown (the create
   succeeds as before).

---

### User Story 2 - A plug-in's create through the program's services tells too (Priority: P2)

FTP and SFTP downloads, the Renamer's creation of a folder in a new name, and other plug-ins that
create files or folders through the program's create services meet the same clash.

**Why this priority**: the same loss of orientation, but on plug-in routes that are rarer.

**Independent Test**: with the seam on, the Renamer renames a file into a new folder whose name is
only another folder's short name; the user is told where that folder stays.

**Acceptance Scenarios**:

1. **Given** a plug-in creates a file or folder through the program's create service and the other
   entry cannot be moved back, **When** the call returns, **Then** the user has been shown the
   message naming the `salNNN` path, and the plug-in receives the same failure and error code as
   before.

---

### User Story 3 - PictView and the Renamer retry their move back (Priority: P3)

PictView's Rename of the shown image and the Renamer's rename to another file's short name move the
other file back once only.

**Why this priority**: they already tell the user; the retry only avoids leaving the entry aside
for a momentary hold.

**Independent Test**: with the seam failing the first few attempts only, the rename completes and
the other file has its own name, no message.

**Acceptance Scenarios**:

1. **Given** the other file is held for a moment shorter than the retry window, **When** the rename
   moves it back, **Then** the move back succeeds after the hold ends and the user sees no message.
2. **Given** it stays held, **When** the retries run out, **Then** the existing message naming the
   `salNNN` path is shown, as before.

### Edge Cases

- The path of the `salNNN` entry is longer than `MAX_PATH`: the message shows it whole (never cut).
- The name contains characters outside the code page: shown exactly (UTF-8 / wide).
- The create itself failed as well: the "left aside" message comes first, then the create's own
  error, as Quick Rename does since 221.
- A "Skip all" of the create's errors in the worker: the "left aside" message is still shown -
  it is not an error of the create but a fact about the user's other entry.
- The plug-in calls the create service from a background thread without a window: the message is
  still shown (owned by a window of that thread if it has one, else ownerless).
- The retry window must stay bounded (about one second per move back) so an operation is never
  stalled noticeably longer than today on the failure path.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every move back of an entry moved aside for an 8.3 clash MUST be retried for a
  bounded time (about one second) while the failure is a sharing / lock violation or access denied
  - the core create paths (already, 221) and PictView's and the Renamer's rename (new).
- **FR-002**: When the move back still fails, the create paths MUST tell the user the full path of
  the `salNNN` entry and the reason: the worker's file copy and folder create, F7 Create Directory,
  Edit New File, the unpack's member folders (`MakeUnpackFoldersOwn` from both its callers), the
  safe-file create of archive plug-ins, and the plug-in interface's create services.
- **FR-003**: The message MUST use the existing texts (the "Error Renaming File" title and the
  "Path / Error" format) - no new UI strings.
- **FR-004**: The return values and error codes of every create function MUST stay as they are
  (plug-in interface unchanged; `LAST_VERSION_OF_SALAMANDER` unchanged).
- **FR-005**: The message MUST be shown at most once per left entry and never when the entry got
  its name back.
- **FR-006**: A Debug-only probe seam MUST let a probe make the first n move-back attempts fail
  with a sharing violation; Release builds MUST NOT contain it.
- **FR-007**: The retry rule (which errors are retried, how many attempts, the seam's count) MUST be
  a header-only rule under `src/common/` shared by the core and the two plug-ins, with `saltests`
  checks.
- **FR-008**: Nothing is ever deleted or overwritten by the new code; paths are never cut.

### Key Entities

- **Left-aside record**: the full UTF-8 path of the `salNNN` entry and the Windows error of the
  last failed move back; produced by a create function, consumed (shown) by its caller.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On every driven create route with every move back failing, the user is shown the
  `salNNN` path in 100 % of runs (probe rows before: 0 messages; after: one per route).
- **SC-002**: With the move back failing only for the first few attempts, 0 entries are left
  under `salNNN` and 0 extra messages are shown on every driven route.
- **SC-003**: The regression probes of the moved-aside routes (201, 203) keep their results.
- **SC-004**: The content of every moved-aside entry is intact in all rows (no data lost).

## Assumptions

- Assumption (autonomous run): the plug-in interface functions `SalCreateFileEx` /
  `SalCreateDirectoryEx` keep their signatures; the program's wrapper shows the message itself
  (the item asks that "every route" tells the user; an interface change is the maintainer's).
- Assumption (autonomous run): the message reuses 221's texts and its form ("Error Renaming File",
  "Path: ...\nError: ..."), so no translation refresh is needed.
- Assumption (autonomous run): FTP and SFTP downloads are covered by the wrapper's message but not
  driven by the probe (they need a server); the Renamer drives the wrapper.
- The failure is a race in reality; the probe drives it with the Debug seam (as features 125 and
  246 do with their seams).
