# Feature Specification: PictView's Rename to another file's short name never replaces it

**Feature Branch**: `202-pictview-short-name`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: renaming the shown image to a name that is only another file's short (8.3) name
  ("LONGFI~1.PNG" for "longfilename.png") renames it and keeps the other file (with a new short
  name); the other file is never offered for overwriting.
- **FR-002**: when the other file cannot be moved aside (held open), or whose name it is cannot be
  told, the rename fails with the error; no question, both files unchanged.
