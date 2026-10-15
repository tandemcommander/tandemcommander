# Feature Specification: deleting a junction in a very deep folder deletes only the link

**Feature Branch**: `197-deep-junction-delete`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: deleting a junction, symbolic link or volume mount point - itself or inside a
  deleted folder - removes only the link, whatever the length of its path; the files it points
  at are never deleted.
- **FR-002**: a reparse folder that cannot be proven a plain folder is never emptied through.
- **FR-003**: *Go to Shortcut Target* follows a link in a folder of any length.
