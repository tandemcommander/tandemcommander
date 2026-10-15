# Feature Specification: deep directory symbolic links and Recycle Bin masks, driven

**Feature Branch**: `219-deep-link-delete-rows`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: deleting a directory symbolic link at any depth, or a folder holding one, removes only
  the link; with the Recycle Bin by masks the same holds for a junction.
- **FR-002**: Go to Shortcut Target goes to a link's target also when the target is stored in the
  Win32 long form (`\\?\C:\...`, `\\?\UNC\...`).
