# Feature Specification: ZIP leaves the archive and no stray file after a failed replace

**Feature Branch**: `320-zip-failed-replace`  
**Created**: 2026-10-23  
**Status**: Draft  
**Input**: User description: "Backlog item zip-says-the-archive-was-not-changed-after-a-failed-replace - implement exactly what it describes." From backlog item zip-says-the-archive-was-not-changed-after-a-failed-replace.

## Background (measured at 4252bcb6)

The ZIP plug-in changes an existing archive (adding or moving files into it, deleting members from
it) by default through a temporary working file `Sal*.tmp` made next to the archive. At the end it
deleted the archive and renamed the temporary file to the archive's name; when either step failed it
said "Cannot replace original archive with temporary working file. Archive was not changed."

- When the archive is open in another program that does not allow it to be deleted (an indexer, a
  viewer, another archiver), the delete fails: the archive is unchanged and the message is true, but
  the temporary file is never removed - measured with a hidden-desktop probe on both routes (Pack
  into an existing archive, Delete inside an archive): a new `Sal*.tmp` each time.
- When the delete succeeds and the rename fails (measured in 319 for an archive kept inside an NTFS
  data stream), the original archive is gone, the only copy of the new content is the stray
  temporary file, and the message still says "Archive was not changed". That route is closed today
  (Pack refuses such a name since 319; Change Directory refuses the path with error 123), but the
  two-step replace can still lose the archive whenever the second step fails.

## Clarifications

### Session 2026-10-23

- Q: Should the "Cannot replace original archive ..." message also show the system's reason (e.g. "used by another process")? → A: No - the message stays exactly as before; only its truth and the removal of the temporary file change (autonomous run: conservative)
- Q: Should the archive keep its own attributes, ACL and named streams (e.g. the downloaded-file mark) after a successful replace, or take the temporary file's as before? → A: Keep the archive's own - the one-step replace of the project rule does so, as for every other replaced file since 105 (autonomous run: rule)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Adding to an archive another program holds open (Priority: P1)

A user packs files into an existing ZIP archive while another program has it open without allowing
deletion. The plug-in cannot put the updated archive in place.

**Why this priority**: the measured, reachable defect - a stray file left in the user's folder
after every such attempt.

**Independent Test**: probe row add-locked: the archive held open (sharing read + write, not
delete), Pack a folder into it, Add, OK.

**Acceptance Scenarios**:

1. **Given** an existing archive held open by another process without delete sharing, **When** the
   user adds files to it with the ZIP plug-in, **Then** the message "Cannot replace original archive
   with temporary working file. Archive was not changed." is shown, the archive is byte-for-byte as
   before, and no new file is left in its folder.
2. **Given** the same archive not held open (or held with delete sharing), **When** the user adds
   files, **Then** the archive holds the old and the new entries and no new file is left (as before).

---

### User Story 2 - Deleting from an archive another program holds open (Priority: P1)

A user deletes a member inside a ZIP archive while another program has it open without allowing
deletion.

**Why this priority**: the same defect on the second route (the same replace code).

**Independent Test**: probe row del-locked: the panel inside the archive, Select seed.txt, Delete,
Yes.

**Acceptance Scenarios**:

1. **Given** an archive held open without delete sharing, **When** the user deletes a member,
   **Then** the replace message is shown, the archive is byte-for-byte as before, and no new file is
   left.
2. **Given** the archive not held (or held with delete sharing), **When** the user deletes a member,
   **Then** the archive no longer holds it and no new file is left (as before).

---

### User Story 3 - The original archive is never deleted before its replacement is in place (Priority: P2)

Whatever makes the final step fail, the archive is not removed first: either the updated archive
takes its place in one step, or the old archive stays as it was.

**Why this priority**: closes the data-loss shape measured in 319 (archive gone, message "not
changed") for every route, not only the ones known today.

**Independent Test**: unit checks of the shared replace rule on a target that cannot be replaced
(a stream name, a target held open without delete sharing): the target unchanged.

**Acceptance Scenarios**:

1. **Given** a target that cannot be replaced by renaming (an NTFS data stream), **When** the
   replace is attempted, **Then** the target keeps its content and the result says "nothing
   changed".
2. **Given** the old archive vanished during the operation (a third party) and the updated archive
   cannot take its name, **When** the replace ends, **Then** the temporary file is kept (it is the
   only copy) and the message names it - it never says "Archive was not changed".

### Edge Cases

- The archive is read-only: refused before any work, as today (`The archive file is read-only...`).
- The archive is held open with delete sharing: the replace succeeds, as before.
- In-place mode ("create temporary backup of zip" off): no temporary file and no replace - unchanged.
- Self-extracting and multi-volume archives use other code paths (a new file is created) - unchanged.
- "Move to archive": the source files are deleted only when the archive was updated; on the replace
  failure they stay (as before - the error stops the clean-up).
- An archive reached through a file symbolic link: the one-step replace refuses (1464) - the
  archive and the link stay as they were, the replace message is shown (before: the link was
  replaced by a plain file and the real archive left stale). Updating through a link is Inbox
  item `zip-cannot-update-an-archive-reached-through-a-symbolic-link` (review of 320).
- The temporary file held by another program without delete sharing (an antivirus scanning the new
  `Sal*.tmp`): before 320 the archive was deleted and the rename failed - the archive gone; now the
  archive stays as it was, and the temporary file, which cannot be deleted while held, may remain.
- Long or non-ASCII archive paths: the replace works on the full wide path (UTF-8 / WTF-8 converted
  without loss, `\\?\` allowed).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When the ZIP plug-in finishes changing an existing archive through its temporary
  working file (adding / moving files into it, deleting members from it), the updated file MUST take
  the archive's place in one step, without deleting the archive first.
- **FR-002**: When that step fails and the archive is still there, the archive MUST be byte-for-byte
  what it was, the temporary file MUST be removed, and the existing message ("Cannot replace original
  archive with temporary working file. Archive was not changed.") MUST be shown.
- **FR-003**: When the archive is gone and the updated content cannot take its name, the temporary
  file MUST be kept and the user MUST be told its name; the "Archive was not changed" message MUST NOT
  be shown.
- **FR-004**: A successful replace MUST behave as before: the updated archive under the archive's
  name with the archive attribute set, the "newest file time" option applied, NTFS compression
  carried over, no temporary file left.
- **FR-005**: No new UI string.
- **FR-006**: Both replace sites (add and delete) MUST use the same project rule for replacing a
  user's file (`CLAUDE.md`, feature 105).

### Key Entities

- **Archive**: the user's existing ZIP file being changed.
- **Temporary working file**: `Sal*.tmp` next to the archive, holding the complete updated archive.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe rows add-locked and del-locked go from FAIL (stray `Sal*.tmp`) to PASS (nothing
  new, nothing changed, the replace message).
- **SC-002**: Control rows add-ctl, del-ctl, add-sharedel, del-sharedel PASS before and after.
- **SC-003**: Unit checks of the replace rule on a data-stream target and on a held target pass:
  the target unchanged, the result "kept".

## Assumptions

- Assumption (autonomous run): the existing header-only rule `SalReplaceWithTempW`
  (`src/common/salsafereplace.h`, feature 105, already used by the PictView and SFTP plug-ins) is the
  replace step; it keeps the archive's attributes, ACL, creation time and named streams (ReplaceFileW),
  where the old delete + rename gave the archive the temporary file's ones.
- Assumption (autonomous run): the rare "archive gone, temporary file kept" case is reported with the
  plug-in's existing text "Cannot open or create file." for the archive, the system error and the
  temporary file's full name (no new string, FR-005).
- Assumption (autonomous run): the read-only attribute is cleared for the replace only as before
  (read-only archives are refused earlier; the rule restores the attribute on failure).
- The 319 stream route is not reachable at HEAD; it is covered by unit checks only.
