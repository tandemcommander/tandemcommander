# Feature Specification: The Renamer's Undo and "Remove source path" never overrun a buffer

**Feature Branch**: `207-renamer-long-source-path`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: an item whose path has 260+ bytes of UTF-8 is renamed, undone and has its empty source
  folders removed without any buffer overrun.
- **FR-002**: Batch Rename in a panel folder whose path does not fit the Renamer is refused before
  its dialog opens; it never acts on names resolved elsewhere (the root of the current drive).
