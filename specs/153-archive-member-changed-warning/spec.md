# Feature Specification: the Archive Update dialog warns about a member changed in the archive

**Feature Branch**: `153-archive-member-changed-warning`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: `specs/NEXT-WORK.md` A.8 (queue 108 entry 2a, 112's trade-off SF1): "A per-member warning
when an archive member changed in the archive since its F4 (needs a new string)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The user sees that updating would overwrite another program's change (Priority: P1)

A user edits a file from an archive (F4). Meanwhile another program changes that member in the
archive. When the edited file is offered for packing back (Archive Update dialog - at a refresh
of the changed archive, when leaving it, before an archive operation), its line says that the
member was changed in the archive since it was opened and that updating overwrites that change.
The user can still update, ignore the file, or copy it elsewhere - as before.

**Independent Test**: `probe/member_changed_probe.ps1` - the dialog's list read item by item.

**Acceptance Scenarios**:

1. **Given** the member changed (or was removed) in the archive since the F4, **Then** its line is
   marked.
2. **Given** only other members changed, or the archive was written again with the same members,
   or not changed at all, **Then** the line is plain.
3. **Given** the archive cannot be listed any more (damaged), **Then** the line is marked (it
   cannot be told) and the program goes on (no crash).

### Edge Cases

- A member written again with the same size and time but another content is not told apart (the
  listing has no checksum) - a documented limit.
- The archive file cannot be opened at the update: no marks (the packing reports the failure).
- Daylight-saving or time-zone change between F4 and update with a changed archive: archivers that
  store local times may report other member times - a needless mark (fails safe).

## Requirements *(mandatory)*

- **FR-001**: At the F4 the member's listed size and time and the archive file's time and size
  MUST be kept with the edited copy.
- **FR-002**: Before the Archive Update dialog the archive file MUST be compared; only a changed
  file is listed again, and then each member is compared (exact name, else one match by the file
  system's rule; anything else counts as changed).
- **FR-003**: A marked line MUST name the file and the consequence (new string, eight languages).
- **FR-004**: No interface or registry change; the dialog layout unchanged (its horizontal scroll
  bar now scrolls).

## Success Criteria *(mandatory)*

- **SC-001**: The marked rows pass on the fix and fail on the build before; the plain rows pass on
  both.
- **SC-002**: The probes of 112 and 096 (pending edits, packing back) unchanged.
