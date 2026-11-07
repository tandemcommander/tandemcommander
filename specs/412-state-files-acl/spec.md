# Feature Specification: Backlog app start keeps its state files accessible

**Feature Branch**: `412-state-files-acl`
**Created**: 2026-11-07
**Status**: Draft
**Input**: User description: "Backlog item backlog-app-start-locks-existing-state-files - implement exactly what it describes: Backlog app start leaves its existing state files with no access rights." From backlog item backlog-app-start-locks-existing-state-files.

## Clarifications

### Session 2026-11-07

- Q: When the state folder holds a link (a junction or symbolic link) to a place outside it, may the start's permission step change the access of what the link points to? → A: No - links are never followed; the link entry itself is reset, its target is left untouched (autonomous run: conservative; measured: `icacls <folder>\* /reset /T` follows a junction and removed an explicit ACE of a file outside the folder, also with `/L`).
- Q: Must the start stay fast with the real state folder (691 folders, ~1000 entries)? → A: Yes - one `icacls` call for the whole contents when the folder holds no link and every folder of it could be listed; a folder-by-folder reset (one call per folder, about 9 ms each) only when a link or an unlistable folder is found (autonomous run: conservative; the start took about 1 s, feature 344).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Changes during a run land again (Priority: P1)

The maintainer starts the backlog app (`bin/start-backlog-app.sh`) while the loop runs an item, and
creates or edits an item in the app. Today every such change fails with `EPERM, Permission denied`
on the app's side worktree, because the app's own start removed every access right from the files
already in its state folder. After the fix the change lands through the side worktree as feature
371 designed.

**Why this priority**: every change the app makes during a run fails; that is the defect the item
names.

**Independent Test**: create a file in a state folder, run the start's permission step, then read,
write and delete the file as the same user.

**Acceptance Scenarios**:

1. **Given** a state folder holding files and subfolders from earlier use, **When** the app starts
   (the permission step runs), **Then** every file and folder in it is readable, writable and
   deletable by the user running the app, and is accessible to that user and SYSTEM only.
2. **Given** a side worktree created before the start, **When** a change is made during a run,
   **Then** the side worktree is recognised as existing and the change lands.

---

### User Story 2 - Files locked by an earlier start are repaired (Priority: P1)

The maintainer's tree already has 375 locked files (empty, protected access list) from earlier
starts. The next start of the fixed app repairs them without a manual `icacls` command.

**Why this priority**: without it the fix would not help the existing installation.

**Independent Test**: give a file of the state folder an empty protected access list, run the
permission step, read the file.

**Acceptance Scenarios**:

1. **Given** a file of the state folder with an empty protected access list, **When** the app
   starts, **Then** the file inherits the folder's owner + SYSTEM access and can be read and
   deleted by the user.

---

### User Story 3 - An unreadable side worktree is reported, not deleted (Priority: P2)

When the side worktree's `.git` file exists but cannot be read (a permission problem), the app
reports that as an error naming the cause instead of taking the worktree for missing and trying
to delete the whole folder.

**Why this priority**: the misleading EPERM-on-delete hid the real cause; a recursive delete of a
folder the app cannot read is the wrong reaction.

**Independent Test**: a unit test with a side worktree whose `.git` cannot be read: `ensure()`
fails with a message about the permissions and the folder is still there.

**Acceptance Scenarios**:

1. **Given** a side worktree folder whose `.git` file exists but cannot be read, **When** a change
   needs the side worktree, **Then** the change is refused with an error that names the
   unreadable `.git` and the folder is not deleted.
2. **Given** a side worktree folder without a `.git` file (a crash between the two steps of its
   creation), **When** a change needs it, **Then** the folder is removed and recreated as before.

### Edge Cases

- An empty state folder (first start): the permission step succeeds.
- Hidden files (`main-worktree/.git`) and nested folders (`main-worktree/backlog/items/...`) are
  repaired like any other entry.
- A drive without access lists or a missing system tool: the start keeps today's behaviour (the
  launcher secret is turned off and a note is printed).
- The folder itself is made private but some entries of its contents cannot be reset: the start
  goes on (the folder is private, new files inherit) and prints a note naming the failure.
- Non-Windows systems: unchanged (`chmod 700` on the folder).
- A junction inside the state folder pointing outside it: its target keeps its access (FR-007).
- A folder inside the state folder that cannot be listed: the folder-by-folder reset makes it
  listable before it is read.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The start's permission step MUST give the state folder itself a protected access
  list granting full control to the user running the app and to SYSTEM only, inheritable by files
  and folders.
- **FR-002**: The step MUST make every entry already inside the folder (files, folders, hidden
  ones, at any depth) take its access from the folder by inheritance alone, removing any explicit
  or empty access list an earlier start left.
- **FR-003**: No user other than the one running the app and SYSTEM MUST gain access to any entry
  of the state folder.
- **FR-004**: The launcher secret MUST stay enabled exactly when the folder itself was made
  private (as today); a failure to reset the contents MUST be reported on the console without
  turning the secret off.
- **FR-005**: The side worktree MUST tell an unreadable `.git` or worktree folder (an error
  reported to the caller, folder kept) from a missing one (folder recreated, as today).
- **FR-006**: The behaviour on non-Windows systems MUST stay unchanged.
- **FR-007**: The permission step MUST NOT follow a link (junction, symbolic link) inside the state
  folder: the access of a link's target outside the folder stays unchanged.
- **FR-008**: When the folder holds no link and every folder in it can be listed, the contents
  MUST be reset in one call; otherwise folder by folder, top-down, skipping the links' targets.

### Key Entities

- **State folder**: `<git-common-dir>/tandem-backlog-app/`, holds settings, the launcher secret
  (`instance.json`), undo files, the event log, chats, jobs, caches and the side worktree.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After a start, 0 entries of the state folder have an empty access list (measured on
  a test folder with files, a hidden file and nested folders; before the fix: every file).
- **SC-002**: A file locked by an earlier start is readable after the next start (test).
- **SC-003**: Every entry's access list names only the user and SYSTEM after a start (test).
- **SC-004**: The app's whole test suite (`npm run check`) passes.

## Assumptions

- Assumption (autonomous run): the contents are reset with `icacls <folder>\* /reset /T /Q`
  after the folder's own access list is set without `/T` (the item's *Approach*, first option;
  measured to work at 23a9f24a, also on an empty folder and on hidden files).
- Assumption (autonomous run): the maintainer's real state folder is not repaired by the run; the
  next start of the fixed app repairs it (FR-002).
- Assumption (autonomous run): "unreadable" means the `.git` file exists but reading it fails with
  a permission error (EACCES / EPERM); any other read failure keeps today's path.
