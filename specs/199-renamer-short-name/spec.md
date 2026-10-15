# Feature Specification: the Renamer keeps a file whose short name is the new name

**Feature Branch**: `199-renamer-short-name`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: renaming a file to a name that is only another file's short (8.3) name renames it
  and keeps the other file (with a new short name) - no overwrite question, nothing deleted.
