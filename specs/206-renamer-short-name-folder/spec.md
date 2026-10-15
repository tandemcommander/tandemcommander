# Feature Specification: The Renamer's new folders: no stack overrun, never into another folder by its short name

**Feature Branch**: `206-renamer-short-name-folder`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: a new name whose folder part names an existing folder by its short (8.3) name never
  overruns a buffer, whatever the folder's long name.
- **FR-002**: in the relative-path mode, such a folder that is only ANOTHER folder's short name
  ("LONGDI~1" of "longdirname") is created as a folder of its own; the other folder and its files
  are never renamed, written to or offered for overwriting; when it cannot be made - an error.
- **FR-003**: the "adjust the case" step keeps working for the folder's own name ("Sub" -> "SUB").
