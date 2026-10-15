# Feature Specification: F5 Copy within a case-sensitive folder

**Feature Branch**: `195-case-sensitive-copy`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: in a folder that tells names apart by case, a file or folder copied under its name
  in another case is copied (an existing other file of that name is offered for overwriting).
- **FR-002**: a copy onto the same file or folder - a hard link, a link to it, an ordinary
  folder, anything that cannot be told apart - stays refused "to itself".
