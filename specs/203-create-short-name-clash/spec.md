# Feature Specification: Copying or unpacking to another file's short name never overwrites it

**Feature Branch**: `203-create-short-name-clash`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: an F5 copy of a file (a folder) whose name is only the short (8.3) name of another
  entry in the target lands as its own entry and keeps the other one (it gets a new short name).
- **FR-002**: when the other entry cannot be moved aside for that (held open), the copy reports the
  error; the other file is never offered for overwriting and a copied folder is never merged into
  the other folder.
- **FR-003**: the same for an archive member unpacked by a plug-in (`SafeFileCreate`), at any path
  length.
