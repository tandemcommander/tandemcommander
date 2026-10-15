# Feature Specification: an entry moved aside is moved back or reported

**Feature Branch**: `221-moved-aside-restore`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: an entry moved aside for an 8.3 name clash is moved back also when another program
  holds it for a moment.
- **FR-002**: when it cannot be moved back, the user is told where it is (Quick Rename, Copy /
  Move); no new string.
