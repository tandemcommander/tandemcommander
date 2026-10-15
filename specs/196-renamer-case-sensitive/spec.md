# Feature Specification: the Renamer in a case-sensitive folder

**Feature Branch**: `196-renamer-case-sensitive`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: in a case-sensitive folder, renaming "a.txt" to "A.txt" while "A.txt" is another
  file asks to overwrite it, as for any other existing name.
- **FR-002**: the source's data is never deleted: a target that is the source, or cannot be
  told apart from it, is not overwritten.
