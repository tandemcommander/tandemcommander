# Feature Specification: ZIP updates an archive reached through a symbolic link

**Feature Branch**: `399-zip-symlink-archive`  
**Created**: 2026-11-02  
**Status**: Draft  
**Input**: User description: "Backlog item zip-cannot-update-an-archive-reached-through-a-symbolic-link - implement exactly what it describes." From backlog item zip-cannot-update-an-archive-reached-through-a-symbolic-link.

## Background (measured at 2a5b7d40)

The ZIP plug-in changes an existing archive (adding or moving files into it, deleting members from
it) by default ("create temporary backup of zip") through a temporary working file `Sal*.tmp` made in
the folder of the archive's name; since feature 320 the finished temporary file takes the archive's
place in one replace step, and a replace that cannot be done leaves the archive as it was with the
message "Cannot replace original archive with temporary working file. Archive was not changed."

When the archive's name is a **file symbolic link** (`src\a.zip` -> `real\a.zip`), the panel, Pack
and the in-archive Delete all name the archive by the link's path. The temporary file is made next to
the link, and the one-step replace onto a link is refused by the system (error 1464). Measured with a
hidden-desktop probe on the build of 2a5b7d40 (14 PASS / 4 FAIL):

- add and delete through an absolute or a relative file link: the replace message, the real archive
  unchanged, the link still the link, no stray file (4 FAIL rows - the update cannot be done at all);
- a plain archive, and an archive whose *folder* is reached through a directory junction: updated
  (only the last component being a file link fails);
- the real archive held open without delete sharing, reached through a link: the message, nothing
  changed.

Before 320 the same operation deleted the link and renamed the temporary file to its name: the link
became a plain file and the real archive stayed old.

## Clarifications

### Session 2026-11-02

- Q: Update the real archive through the link, or refuse up front with a new message? → A: Update the real archive (the item's *Expected* names it first, its *Approach* first option; refusing would need a new string and leaves the operation impossible) (autonomous run: item)
- Q: Which names count as "a link" to be followed? → A: A name that is itself a reparse point of the name-surrogate kind (a file symbolic link; the same class as a mount point) - every other name (a plain file, a hard link, a file whose folder is reached through a junction or a directory link, a cloud placeholder) keeps exactly the behaviour of today (autonomous run: conservative)
- Q: What if the link cannot be resolved (its final path cannot be read)? → A: Behave as today: the replace is attempted on the link's name, fails safe and shows the existing true message - nothing changed, no stray file (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Adding files to an archive reached through a symbolic link (Priority: P1)

A user keeps a link `a.zip` in a working folder that points to the real archive elsewhere, and packs
files into `a.zip` with the ZIP plug-in (Pack, or copy / move into the archive).

**Why this priority**: the measured defect - the update cannot be done at all through the link.

**Independent Test**: probe rows add-symlink, add-relsymlink: Pack 'plain' into the link's name.

**Acceptance Scenarios**:

1. **Given** `src\a.zip` a file symbolic link (absolute or relative target) to `real\a.zip`, **When**
   the user adds files to `a.zip`, **Then** `real\a.zip` holds the old and the new entries, `src\a.zip`
   is still the same link to `real\a.zip`, no replace message is shown, and no new file is left in
   either folder.
2. **Given** a plain archive or an archive in a folder reached through a junction, **When** the user
   adds files, **Then** the result is as before (updated, nothing new).

---

### User Story 2 - Deleting members from an archive reached through a symbolic link (Priority: P1)

The user opens `a.zip` (the link) in the panel and deletes a member.

**Why this priority**: the same defect on the second route (the same replace code).

**Independent Test**: probe rows del-symlink, del-relsymlink.

**Acceptance Scenarios**:

1. **Given** the panel inside the link `src\a.zip`, **When** the user deletes `seed.txt`, **Then**
   `real\a.zip` no longer holds it, the link is still the link, no message, nothing new.

---

### User Story 3 - A failed replace through a link still changes nothing (Priority: P2)

**Why this priority**: the guarantees of 320 must hold on the new route.

**Independent Test**: probe row add-symlink-locked: the real archive held open without delete sharing.

**Acceptance Scenarios**:

1. **Given** the real archive held open by another program without delete sharing, **When** the user
   adds files through the link, **Then** the existing replace message is shown, the real archive and
   the link are byte-for-byte as before, and no new file is left.

### Edge Cases

- The real archive's folder cannot be written (no right to create the temporary file there): the
  existing "cannot create temporary file" error names the real folder; nothing changes.
- The link leads to another volume or a network share: the temporary file is made next to the real
  archive (its own volume), so the one-step replace stays a same-folder replace.
- A chain of links: the final path of the opened file is used (all links resolved).
- The link cannot be resolved: as today (fails safe with the true message).
- A hard link: as before (only the replaced name gets the new content; other names keep the old one).
- In-place mode (backup option off): the archive is written through the link as before - not changed
  by this feature.
- The real archive's attributes (hidden, system, compressed) are the ones kept and restored after the
  replace - not the link's own attributes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When the archive's name is a file symbolic link, an add, move-into or delete operation
  with the temporary working file MUST make that file in the real archive's folder and put it in the
  real archive's place in one step.
- **FR-002**: The link MUST stay the same link (never replaced by a plain file, never re-pointed).
- **FR-003**: Every failure MUST keep the guarantees of feature 320: the real archive unchanged, the
  temporary file removed (unless it is the only copy, then kept and named), the existing true message.
- **FR-004**: Names that are not file links (plain files, hard links, junctions or directory links in
  the folder part, other reparse kinds) MUST behave exactly as before.
- **FR-005**: The real archive's own attributes MUST be the ones the updated archive keeps.
- **FR-006**: No new user-visible text; messages keep naming the archive by the name the user used.
- **FR-007**: The rule deciding "follow this name" and the cleaning of the resolved path MUST be pure
  and checked by `saltests`, in a header the ZIP plug-in can include (header-only rule).

### Key Entities

- **Archive name**: the path the user sees (the link's path) - used in every message.
- **Replace target**: the file the archive really is - the link's final path when the name is a file
  link, otherwise the archive name itself.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe's 4 failing rows (add/del through an absolute and a relative file link) pass:
  the real archive updated, the link kept, nothing new, no message.
- **SC-002**: Every control row (plain, junction, held real archive) passes as before: 18 / 18 rows.
- **SC-003**: `saltests` passes with new checks for the pure rule and a real link replace; the
  encoding guard reports 0 findings.

## Assumptions

- Assumption (autonomous run): creating file symbolic links on the test machine works without
  elevation (Developer Mode) - measured; where it does not, the saltests I/O check prints that it is
  skipped instead of failing.
- Assumption (autonomous run): other users of the shared replace helper (PictView Save As, SFTP
  download, the core's configuration export, saving a viewed file) are out of scope - the item names
  the ZIP plug-in; any defect found there goes to the Inbox.
